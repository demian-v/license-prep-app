import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase_options.dart';

import 'services/service_locator.dart';
import 'services/service_locator_extensions.dart';
import 'services/api/api_implementation.dart';
import 'services/content_loading_manager.dart';
import 'services/email_sync_service.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/theory_module_screen.dart';
import 'screens/practice_test_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/home_screen.dart';
import 'screens/traffic_rules_topics_screen.dart';
import 'screens/test_screen.dart';
import 'screens/reset_app_settings_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_email_sent_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/password_reset_success_screen.dart';
import 'models/user.dart';
import 'models/subscription.dart';
import 'models/progress.dart';
import 'models/theory_module.dart';
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/language_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/content_provider.dart';
import 'providers/state_provider.dart';
import 'localization/app_localizations.dart';

// Setup auth listener to detect changes to the user's email
void setupAuthListener() {
  // Store last known email to detect changes
  String? lastKnownEmail;
  
  debugPrint('🔧 EmailSyncService: Setting up optimized auth listeners');
  
  // Auth state changes listener
  firebase_auth.FirebaseAuth.instance.authStateChanges().listen((firebase_auth.User? user) {
    if (user?.email != null) {
      final currentEmail = user!.email!;
      debugPrint('👉 Auth state changed: user email = $currentEmail');
      if (lastKnownEmail != currentEmail) {
        debugPrint('📧 Email changed: $lastKnownEmail → $currentEmail');
        lastKnownEmail = currentEmail;
        emailSyncService.smartSync(force: true);
      } else {
        emailSyncService.smartSync();
      }
    }
  });

  // User changes listener (for email updates)
  firebase_auth.FirebaseAuth.instance.userChanges().listen((firebase_auth.User? user) {
    if (user?.email != null) {
      final currentEmail = user!.email!;
      debugPrint('👤 User details changed: user email = $currentEmail');
      if (lastKnownEmail != currentEmail) {
        debugPrint('📧 Email changed: $lastKnownEmail → $currentEmail');
        lastKnownEmail = currentEmail;
        emailSyncService.smartSync(force: true);
      } else {
        emailSyncService.smartSync();
      }
    }
  });
  
  // Start managed periodic sync (replaces the recursive timer)
  emailSyncService.startPeriodicSync();
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  DateTime? _lastResumeSync;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes from background (like when coming back from browser verification)
    if (state == AppLifecycleState.resumed) {
      // Only sync if app was backgrounded for more than 30 seconds
      if (_lastResumeSync == null || 
          DateTime.now().difference(_lastResumeSync!) > Duration(seconds: 30)) {
        debugPrint('🔄 App resumed from background - running smart sync check');
        _lastResumeSync = DateTime.now();
        emailSyncService.smartSync();
        emailSyncService.handlePostEmailVerification(null);
      } else {
        debugPrint('⏭️ App resume sync skipped - too recent');
      }
    }
  }
}

class _AppCleanupObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      debugPrint('🧹 App terminating - cleaning up EmailSyncService');
      emailSyncService.dispose();
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Register app lifecycle observer to detect when app comes back from background
  final lifecycleObserver = AppLifecycleObserver();
  WidgetsBinding.instance.addObserver(lifecycleObserver);
  
  // Ensure cleanup when app terminates
  WidgetsBinding.instance.addObserver(_AppCleanupObserver());
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up auth listener to detect email changes
  setupAuthListener();
  
  // Handle email verification immediately on startup
  final currentAuthUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (currentAuthUser != null) {
    try {
      // Reload user data to get latest email from Firebase Auth
      await currentAuthUser.reload();
      debugPrint('✅ User data reloaded on app start');
      
      // Use smart sync with force flag for startup
      await emailSyncService.smartSync(force: true);
      
      // Handle post-verification flow
      await emailSyncService.handlePostEmailVerification(null);
    } catch (e) {
      debugPrint('⚠️ Startup sync error: $e');
    }
  }
  
  // Sign in anonymously to Firebase - this will help with storage permissions
  try {
    final auth = firebase_auth.FirebaseAuth.instance;
    if (auth.currentUser == null) {
      print('No user logged in, signing in anonymously...');
      await auth.signInAnonymously();
      print('Anonymous sign-in successful');
    } else {
      print('User already signed in: ${auth.currentUser?.uid}');
    }
  } catch (e) {
    print('Error signing in anonymously: $e');
  }
  
  // Initialize service locator with Firebase implementation
  serviceLocator.initializeWithApiImplementation(ApiImplementation.firebase);
  
  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Load user data if exists
  User? user;
  final userString = prefs.getString('user');
  if (userString != null) {
    user = User.fromJson(jsonDecode(userString));
  }
  
  // Load subscription data
  SubscriptionStatus subscription;
  final subscriptionString = prefs.getString('subscription');
  if (subscriptionString != null) {
    subscription = SubscriptionStatus.fromJson(jsonDecode(subscriptionString));
  } else {
    // Default subscription with 3-day trial
    final trialEndDate = DateTime.now().add(Duration(days: 3));
    final now = DateTime.now();
    subscription = SubscriptionStatus(
      isActive: true,
      trialEndsAt: trialEndDate,
      nextBillingDate: null,
      planType: 'trial',
      createdAt: now,
      updatedAt: now,
    );
    prefs.setString('subscription', jsonEncode(subscription.toJson()));
  }
  
  // Load progress data
  UserProgress progress;
  final progressString = prefs.getString('progress');
  if (progressString != null) {
    progress = UserProgress.fromJson(jsonDecode(progressString));
  } else {
    progress = UserProgress(
      completedModules: [],
      testScores: {},
      selectedLicense: null,
      topicProgress: {}, // Initialize empty topic progress
      savedQuestions: [], // Initialize empty saved questions
    );
  }
  
  // Create providers
  final authProvider = AuthProvider(user);
  final subscriptionProvider = SubscriptionProvider(subscription);
  final progressProvider = ProgressProvider(progress);
  
  // Create language provider - only force English for non-registered users
  // For registered users, load their saved language preference
  final languageProvider = LanguageProvider(forceEnglish: user == null);
  // Wait for language to load properly from SharedPreferences
  await languageProvider.waitForLoad();
  print('Language provider loaded with language: ${languageProvider.language}');
  
  // For logged-in users, apply their saved language preference
  if (user != null && user.language != null && user.language!.isNotEmpty) {
    await languageProvider.setLanguage(user.language!);
    print('Applied user language preference: ${user.language}');
  } else if (user == null) {
    print('No user logged in, using English default');
  } else {
    print('User logged in but no language preference set, using English default');
  }
  
  // Connect AuthProvider and LanguageProvider for synchronization
  authProvider.setLanguageProvider(languageProvider);
  
  final stateProvider = StateProvider();
  
  // Initialize state provider
  await stateProvider.initialize();

  // Create exam and practice providers
  final examProvider = ExamProvider();
  final practiceProvider = PracticeProvider();
  
  // Create content provider
  final contentProvider = ContentProvider();
  
  // Update content provider to use the correct language (not hardcoded to Ukrainian)
  contentProvider.setPreferences(language: languageProvider.language);
  
  // Register providers with service locator for our extensions
  serviceLocator.registerLanguageProvider(languageProvider);
  serviceLocator.registerContentProvider(contentProvider);
  
  // Initialize service locator extensions
  ServiceLocatorExtensions.initialize();
  
  // Listen for language changes and update content language
  languageProvider.addListener(() {
    contentProvider.setPreferences(language: languageProvider.language);
    print('Language updated in ContentProvider to: ${languageProvider.language}');
  });
  
  // Check if we need to migrate saved questions
  if (user != null) {
    final userId = user.id; // User.id is non-nullable based on the model
    Future.microtask(() async {
      await progressProvider.migrateSavedQuestionsIfNeeded(userId);
    });
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: subscriptionProvider),
        ChangeNotifierProvider.value(value: progressProvider),
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: examProvider),
        ChangeNotifierProvider.value(value: practiceProvider),
        ChangeNotifierProvider.value(value: contentProvider),
        ChangeNotifierProvider.value(value: stateProvider),
      ],
      child: MyApp(
        authProvider: authProvider,
        languageProvider: languageProvider,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final LanguageProvider languageProvider;

  const MyApp({
    Key? key,
    required this.authProvider,
    required this.languageProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentLang = languageProvider.language;
    print('MyApp.build: Setting app locale to language: $currentLang');
    
    // Important: Force app rebuild with unique key when language changes
    return MaterialApp(
      title: 'USA License Prep',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.light(secondary: Colors.green),
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      // Set locale and force rebuilding when language changes
      locale: Locale(currentLang),
      key: ValueKey('app_${currentLang}_${DateTime.now().millisecondsSinceEpoch}'), // Force rebuild on language change
      supportedLocales: AppLocalizations.supportedLocales(),
      localizationsDelegates: [
        // Set app localizations first to take priority
        AppLocalizations.delegate,
        // These framework delegates need to come after our custom delegate
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Crucial: Set this to ensure correct localization context
      localeResolutionCallback: (locale, supportedLocales) {
        print('🔍 localeResolutionCallback called with locale: ${locale?.languageCode}');
        print('🔍 Supported locales: ${supportedLocales.map((l) => l.languageCode).join(', ')}');
        
        // Use the passed locale if it's supported
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            print('✅ Using matched locale: ${supportedLocale.languageCode}');
            return supportedLocale;
          }
        }
        
        // Fall back to the first locale if not supported
        print('⚠️ Language not supported, falling back to: ${supportedLocales.first.languageCode}');
        return supportedLocales.first;
      },
      
      // Initialize a route observer to track navigation
      navigatorObservers: [RouteObserver<PageRoute>()],
      initialRoute: '/',
      home: Builder(
        builder: (context) {
          // Check for password reset deep links before deciding home screen
          final deepLinkData = ModalRoute.of(context)?.settings.arguments;
          if (deepLinkData != null && deepLinkData is Map<String, dynamic> && deepLinkData.containsKey('oobCode')) {
            debugPrint('🔑 Found password reset code in deep link: ${deepLinkData['oobCode']}');
            String code = deepLinkData['oobCode'];
            return ResetPasswordScreen(code: code);
          }
          
          // Normal flow - check if user is logged in
          return authProvider.user != null ? HomeScreen() : LoginScreen();
        }
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => HomeScreen(),
        '/theory': (context) => TrafficRulesTopicsScreen(),
        '/tests': (context) => TestScreen(),
        '/profile': (context) => ProfileScreen(),
        '/subscription': (context) => SubscriptionScreen(),
        '/settings/reset': (context) => ResetAppSettingsScreen(),
        // Password reset routes
        '/forgot-password': (context) => ForgotPasswordScreen(),
        '/reset-email-sent': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final email = args?['email'] as String? ?? '';
          return ResetEmailSentScreen();
        },
        '/reset-success': (context) => PasswordResetSuccessScreen(),
      },
      onGenerateRoute: (settings) {
        debugPrint('🔗 Route requested: ${settings.name}');
        
        if (settings.name!.startsWith('/theory/')) {
          final moduleId = settings.name!.split('/')[2];
          // Fetch the module using ContentProvider
          final contentProvider = Provider.of<ContentProvider>(context, listen: false);
          final modules = contentProvider.modules;
          TheoryModule? module;
          try {
            module = modules.firstWhere(
              (m) => m.id == moduleId,
            );
          } catch (e) {
            module = null;
          }
          
          // If module found, navigate to the module screen
          if (module != null) {
            // Use non-null assertion since we've already checked module is not null
            final nonNullModule = module;
            return MaterialPageRoute(
              builder: (context) => TheoryModuleScreen(module: nonNullModule),
            );
          } else {
            // If module not found, redirect to theory screen
            return MaterialPageRoute(
              builder: (context) => TrafficRulesTopicsScreen(),
            );
          }
        } else if (settings.name!.startsWith('/practice/')) {
          final licenseId = settings.name!.split('/')[2];
          return MaterialPageRoute(
            builder: (context) => PracticeTestScreen(licenseId: licenseId),
          );
        } 
        // Handle password reset deep links with improved detection
        else if (settings.name!.startsWith('/reset-password') || 
                settings.name! == 'resetPassword' ||
                settings.name! == '/resetPassword' ||
                (settings.name!.contains('resetPassword') && settings.name!.contains('oobCode')) ||
                settings.name! == 'mode=resetPassword') {
          
          debugPrint('📲 Password reset deep link detected: ${settings.name}');
          
          // Extract the oobCode using multiple methods to ensure we get it
          String? code;
          
          // Method 1: Extract from query parameters if this is a proper URI
          try {
            // First try to parse as a complete URI
            final uri = Uri.parse(settings.name!);
            code = uri.queryParameters['oobCode'];
            debugPrint('🔍 Extracted code from URI: $code');
          } catch (e) {
            debugPrint('⚠️ Could not parse as URI: $e');
            
            // Method 2: Manual string parsing for query parameters
            final routePath = settings.name!;
            if (routePath.contains('?')) {
              final queryString = routePath.split('?')[1];
              final params = queryString.split('&');
              
              for (final param in params) {
                if (param.startsWith('oobCode=')) {
                  code = param.substring('oobCode='.length);
                  debugPrint('🔍 Extracted code from query string: $code');
                  break;
                }
              }
            }
          }
          
          // Method 3: Check if code is in the arguments
          if (code == null && settings.arguments != null) {
            if (settings.arguments is Map<String, dynamic>) {
              code = (settings.arguments as Map<String, dynamic>)['oobCode'];
              debugPrint('🔍 Extracted code from arguments: $code');
            }
          }
          
          debugPrint('🔑 Final password reset code: $code');
          
          if (code != null) {
            // Use non-null assertion since we've already checked code is not null
            final String nonNullableCode = code; // Explicitly create non-nullable string
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(code: nonNullableCode),
            );
          } else {
            debugPrint('❌ No reset code found in deep link');
          }
        }
        return null;
      },
    );
  }
}
