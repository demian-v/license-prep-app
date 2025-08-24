import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';

import 'services/service_locator.dart';
import 'services/service_locator_extensions.dart';
import 'services/api/api_implementation.dart';
import 'services/content_loading_manager.dart';
import 'services/email_sync_service.dart';
import 'services/analytics_service.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/theory_module_screen.dart';
import 'screens/practice_test_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/home_screen.dart';
import 'screens/state_selection_screen.dart';
import 'screens/traffic_rules_topics_screen.dart';
import 'screens/test_screen.dart';
import 'screens/reset_app_settings_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_email_sent_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/password_reset_success_screen.dart';
import 'screens/email_verification_screen.dart';
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
import 'services/email_verification_handler.dart';
import 'services/action_code_router.dart';

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
    // When app resumes from background, sync emails
    if (state == AppLifecycleState.resumed) {
      // Only sync if app was backgrounded for more than 30 seconds
      if (_lastResumeSync == null || 
          DateTime.now().difference(_lastResumeSync!) > Duration(seconds: 30)) {
        debugPrint('🔄 App resumed from background - running sync check');
        _lastResumeSync = DateTime.now();
        
        // Simple email sync on app resume
        emailSyncService.smartSync();
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
  
  // Initialize Firebase Analytics
  await analyticsService.initialize();
  debugPrint('📊 Firebase Analytics initialized');
  
  // Set up auth listener to detect email changes
  setupAuthListener();
  
  // Handle email sync on startup
  final currentAuthUser = firebase_auth.FirebaseAuth.instance.currentUser;
  if (currentAuthUser != null) {
    try {
      // Reload user data to get latest email from Firebase Auth
      await currentAuthUser.reload();
      debugPrint('✅ User data reloaded on app start');
      
      // Use smart sync with force flag for startup
      await emailSyncService.smartSync(force: true);
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
  
  // Connect AuthProvider with SubscriptionProvider for analytics
  authProvider.setSubscriptionProvider(subscriptionProvider);
  
  final stateProvider = StateProvider();
  
  // Connect AuthProvider with StateProvider for synchronization
  authProvider.setStateProvider(stateProvider);
  
  // Initialize state provider
  await stateProvider.initialize();

  // For logged-in users, apply their saved state preference
  if (user != null && user.state != null && user.state!.isNotEmpty) {
    await stateProvider.setSelectedState(user.state!);
    print('Applied user state preference: ${user.state}');
  } else if (user == null) {
    print('No user logged in, state remains null');
  } else {
    print('User logged in but no state preference set, state remains null');
  }

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
  
  // Removed global language listener that was causing interference during sign-up
  // Language synchronization is now handled in HomeScreen and ProfileScreen
  
  // Check if we need to migrate saved questions
  if (user != null) {
    final userId = user.id; // User.id is non-nullable based on the model
    Future.microtask(() async {
      await progressProvider.migrateSavedQuestionsIfNeeded(userId);
    });
  }
  
  // Set up initial user properties for analytics
  if (user != null) {
    await analyticsService.setUserProperties(
      userId: user.id,
      state: user.state,
      language: user.language ?? languageProvider.language,
      subscriptionStatus: subscription.planType,
    );
    
    // Log user configured event
    await analyticsService.logEvent('user_configured', {
      'subscription_type': subscription.planType,
      'is_trial': subscription.planType == 'trial',
    });
  } else {
    // For anonymous users, set basic properties
    await analyticsService.setUserProperties(
      language: languageProvider.language,
      subscriptionStatus: subscription.planType,
    );
    
    // Log anonymous user configured event
    await analyticsService.logEvent('anonymous_user_configured', {
      'subscription_type': subscription.planType,
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
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;

  const MyApp({
    Key? key,
    required this.authProvider,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentLang = languageProvider.language;
        
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
          // Set locale and use stable key based only on language
          locale: Locale(currentLang),
          key: ValueKey('app_$currentLang'),
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
              
              // Normal flow - check if user is logged in and has completed signup
              final user = authProvider.user;
              if (user != null && user.state != null) {
                return HomeScreen(); // User is fully set up
              } else if (user != null && user.state == null) {
                return StateSelectionScreen(); // User needs to complete signup
              } else {
                return LoginScreen(); // User not logged in
              }
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
            
            // Handle all action code deep links (email verification and password reset) with smart routing
            if (settings.name != null && ActionCodeRouter.containsActionCode(settings.name!)) {
              debugPrint('🔗 Action code deep link detected: ${settings.name}');
              
              // Extract oobCode using the ActionCodeRouter
              final oobCode = ActionCodeRouter.extractOobCode(settings.name!);
              
              if (oobCode != null) {
                debugPrint('✅ Extracted oobCode: ${oobCode.substring(0, 8)}...');
                
                // Use FutureBuilder to determine route based on action type
                return MaterialPageRoute(
                  builder: (context) => FutureBuilder<ActionCodeRouteInfo>(
                    future: ActionCodeRouter.determineRoute(oobCode),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Scaffold(
                          body: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Processing verification link...'),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (snapshot.hasError) {
                        debugPrint('❌ ActionCodeRouter error: ${snapshot.error}');
                        return ProfileScreen(); // Fallback to profile
                      }
                      
                      if (snapshot.hasData) {
                        final routeInfo = snapshot.data!;
                        debugPrint('🎯 ActionCodeRouter determined route: ${routeInfo.type} -> ${routeInfo.route}');
                        
                        switch (routeInfo.type) {
                          case ActionCodeType.emailVerification:
                            return EmailVerificationScreen(oobCode: oobCode);
                          case ActionCodeType.passwordReset:
                            return ResetPasswordScreen(code: oobCode);
                          case ActionCodeType.unknown:
                          default:
                            debugPrint('⚠️ Unknown action code type, defaulting to profile');
                            return ProfileScreen();
                        }
                      }
                      
                      // Fallback
                      return ProfileScreen();
                    },
                  ),
                );
              } else {
                debugPrint('❌ Could not extract oobCode from URL, routing to profile');
                return MaterialPageRoute(
                  builder: (context) => ProfileScreen(),
                );
              }
            }
            
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
            // Handle email verification deep links - simplified to just redirect to profile
            else if (settings.name!.startsWith('/email-verified') || 
                    settings.name! == 'emailVerified' ||
                    settings.name! == '/emailVerified' ||
                    settings.name!.contains('email-verified')) {
              
              debugPrint('📧 Email verification deep link detected: ${settings.name}');
              
              // Simply navigate to profile screen - the applyVerifiedEmail method
              // will be called manually by the user if needed
              return MaterialPageRoute(
                builder: (context) => ProfileScreen(),
              );
            }
            // Handle email verification error deep links
            else if (settings.name!.startsWith('/email-verification-error') ||
                    settings.name!.contains('email-verification-error')) {
              
              debugPrint('❌ Email verification error deep link detected: ${settings.name}');
              
              // Navigate to profile screen
              return MaterialPageRoute(
                builder: (context) => ProfileScreen(),
              );
            }
            return null;
          },
        );
      },
    );
  }
}
