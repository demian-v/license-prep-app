import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'firebase_options.dart';

import 'services/service_locator.dart';
import 'services/api/api_implementation.dart';

import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/license_selection_screen.dart';
import 'screens/theory_module_screen.dart';
import 'screens/practice_test_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/home_screen.dart';
import 'screens/traffic_rules_topics_screen.dart';
import 'screens/test_screen.dart';
import 'models/user.dart';
import 'models/subscription.dart';
import 'models/progress.dart';
import 'providers/auth_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/language_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/content_provider.dart';
import 'localization/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
  final languageProvider = LanguageProvider();

  // Create exam and practice providers
  final examProvider = ExamProvider();
  final practiceProvider = PracticeProvider();
  
  // Create content provider
  final contentProvider = ContentProvider();
  // Load content with fixed 'uk' language and 'IL' state
  // This initialization will always use Ukrainian for content, regardless of UI language
  await contentProvider.fetchContentForLanguageAndState('uk', 'IL', forceRefresh: true);
  
  // Observe language changes for UI only
  languageProvider.addListener(() {
    // We don't update content language when UI language changes
    print('UI language changed to: ${languageProvider.language}, content remains in Ukrainian');
    // No need to call contentProvider.setPreferences since we're keeping content in 'uk'
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
      locale: Locale(languageProvider.language),
      key: ValueKey(languageProvider.language), // Force rebuild on language change
      supportedLocales: [
        Locale('en'), // English
        Locale('es'), // Spanish
        Locale('uk'), // Ukrainian
        Locale('ru'), // Russian
        Locale('pl'), // Polish
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: authProvider.user != null ? HomeScreen() : LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => HomeScreen(),
        '/theory': (context) => TrafficRulesTopicsScreen(),
        '/tests': (context) => TestScreen(),
        '/profile': (context) => ProfileScreen(),
        '/subscription': (context) => SubscriptionScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name!.startsWith('/theory/')) {
          final licenseId = settings.name!.split('/')[2];
          return MaterialPageRoute(
            builder: (context) => TheoryModuleScreen(licenseId: licenseId),
          );
        } else if (settings.name!.startsWith('/practice/')) {
          final licenseId = settings.name!.split('/')[2];
          return MaterialPageRoute(
            builder: (context) => PracticeTestScreen(licenseId: licenseId),
          );
        }
        return null;
      },
    );
  }
}
