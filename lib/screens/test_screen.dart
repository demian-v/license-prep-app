import 'package:flutter/material.dart';
import '../services/crash_reporter.dart';
import 'package:provider/provider.dart';
import '../data/license_data.dart';
import '../widgets/enhanced_test_card.dart';
import '../providers/exam_provider.dart';
import '../providers/language_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/practice_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../services/service_locator.dart';
import '../services/analytics_service.dart';
import '../services/session_validation_service.dart';
import 'topic_quiz_screen.dart';
import 'saved_items_screen.dart';
import 'exam_question_screen.dart';
import 'practice_question_screen.dart';
import '../localization/app_localizations.dart';
import '../widgets/trial_status_widget.dart';
import '../widgets/premium_block_dialog.dart';
import '../utils/subscription_checker.dart';
import '../providers/subscription_provider.dart';

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  
  @override
  void initState() {
    super.initState();
    // Pre-load quiz data after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadQuizData();
    });
  }
  
  /// Pre-fetches all quiz questions for the user's current state and language
  /// This runs silently in the background when the Tests screen loads
  Future<void> _preloadQuizData() async {
    try {
      // Get user's current state
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      
      // Ensure selectedState is cast to String properly
      final userState = stateProvider.selectedState?.toString() ?? 'IL';
      final userLanguage = languageProvider.language;
      
      print('🔍 [TEST SCREEN] Pre-loading quiz data for state: $userState, language: $userLanguage');
      
      // Call the new preload method in Firebase Content API
      await serviceLocator.content.preloadAllQuizQuestions(userState, userLanguage);
      
      print('✅ [TEST SCREEN] Quiz data pre-loading completed');
    } catch (e) {
      print('⚠️ [TEST SCREEN] Error pre-loading quiz data: $e');
      // Silent failure - user can still use the app with regular fetching
    }
  }
  
  /// The state whose questions should be served.
  ///
  /// Risk #39, second half. The `7fa9a6c` fix replaced a hardcoded `'IL'`
  /// inside `ExamProvider` and `PracticeProvider` with their `state`
  /// parameter — but the two call sites in this file kept passing the literal
  /// `'IL'` INTO that parameter, so the defect survived one layer up: a New
  /// York user still got Illinois exam and practice questions. The commit
  /// message's own argument ("topics above already honour the user's selected
  /// state") applies here too.
  ///
  /// Resolution order is copied from `_logExamStartedAnalytics` on purpose. If
  /// the analytics event and the actual request disagreed about the state, the
  /// event would be evidence for the wrong thing — which is how this went
  /// unnoticed: analytics has reported the real state since `7fa9a6c`, while
  /// the request did not.
  String _questionState() {
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
  }

  /// Analytics method for exam started event
  void _logExamStartedAnalytics(LanguageProvider languageProvider) async {
    try {
      // Get providers for analytics
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Get analytics parameters
      final language = languageProvider.language;
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      
      // Generate unique exam ID for analytics
      final examId = 'exam_${DateTime.now().millisecondsSinceEpoch}';
      
      // Log exam started analytics event
      await analyticsService.logExamStarted(
        examId: examId,
        state: state,
        language: language,
        licenseType: licenseType,
        totalQuestions: 40,
        timeLimitMinutes: 60,
      );
      
      print('📊 Analytics: exam_started logged (exam_id: $examId, state: $state, language: $language)');
    } catch (e) {
      print('❌ Analytics error: $e');
      // Don't block user flow if analytics fails
    }
  }
  
  /// Analytics method for practice started event
  void _logPracticeStartedAnalytics(LanguageProvider languageProvider) async {
    try {
      // Get providers for analytics
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Get analytics parameters
      final language = languageProvider.language;
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      
      // Generate unique practice ID for analytics
      final practiceId = 'practice_${DateTime.now().millisecondsSinceEpoch}';
      
      // Log practice started analytics event
      await analyticsService.logPracticeStarted(
        practiceId: practiceId,
        state: state,
        language: language,
        licenseType: licenseType,
        totalQuestions: null, // Unlimited questions
        timeLimitMinutes: null, // Unlimited time
      );
      
      print('📊 Analytics: practice_started logged (practice_id: $practiceId, state: $state, language: $language)');
    } catch (e) {
      print('❌ Analytics error: $e');
      // Don't block user flow if analytics fails
    }
  }
  
  /// Shows premium block dialog when user tries to access premium features without valid subscription
  void _showPremiumBlockDialog(BuildContext context, String featureName) {
    debugPrint('🚫 TestScreen: Showing premium block dialog for feature: $featureName');
    
    PremiumBlockDialog.show(
      context,
      featureName: featureName,
      onUpgradePressed: () {
        debugPrint('🔄 TestScreen: User clicked Upgrade Now from premium block dialog');
        Navigator.of(context).pop(); // Close dialog
        Navigator.pushNamed(context, '/subscription'); // Navigate to subscription screen
      },
      onClosePressed: () {
        debugPrint('❌ TestScreen: User closed premium block dialog');
        Navigator.of(context).pop();
      },
    );
  }
  
  /// Analytics method for Learn by Topics started event
  void _logLearnByTopicsStartedAnalytics(LanguageProvider languageProvider) async {
    try {
      // Get providers for analytics
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Get analytics parameters
      final language = languageProvider.language;
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      
      // Log Learn by Topics started analytics event
      await analyticsService.trackLearnByTopicsStarted(
        stateId: state,
        licenseType: licenseType,
      );
      
      print('📊 Analytics: learn_by_topics_started logged (state: $state, license_type: $licenseType)');
    } catch (e) {
      print('❌ Analytics error: $e');
      // Don't block user flow if analytics fails
    }
  }
  
  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language based on the language provider
      switch (languageProvider.language) {
        case 'es':
          return {
            'tests': 'Pruebas',
            'testing': 'Pruebas',
            'take_exam': 'Realizar examen',
            'dmv_exam_desc': 'Simulación de examen',
            'working_on_mistakes': 'Trabajando en errores',
            'saved': 'Guardado',
            'saved_questions_desc': 'Preguntas guardadas de diferentes secciones',
            'learn_by_topics': 'Aprender por Temas',
            'questions_by_topics': 'Preguntas por Temas',
            'practice_tickets': 'Boletos de Práctica',
            'random_questions_no_limit': 'Preguntas aleatorias, sin límite',
            'time_60_minutes': '60 minutos',
            'questions_40': '40 preguntas',
            'time_unlimited': 'Tiempo ilimitado',
            'questions_100_sorted': '100+ preguntas por tema',
          }[key] ?? key;
        case 'uk':
          return {
            'tests': 'Тести',
            'testing': 'Тестування',
            'take_exam': 'Складай іспит',
            'dmv_exam_desc': 'Симуляція іспиту',
            'working_on_mistakes': 'Робота над помилками',
            'saved': 'Збережені',
            'saved_questions_desc': 'Збережені питання з різних розділів',
            'learn_by_topics': 'Навчання за темами',
            'questions_by_topics': 'Питання за темами',
            'practice_tickets': 'Практичні білети',
            'random_questions_no_limit': 'Випадкові питання, без обмежень',
            'time_60_minutes': '60 хвилин',
            'questions_40': '40 запитань',
            'time_unlimited': 'Необмежений час',
            'questions_100_sorted': '100+ питань по темах',
          }[key] ?? key;
        case 'ru':
          return {
            'tests': 'Тесты',
            'testing': 'Тестирование',
            'take_exam': 'Сдать экзамен',
            'dmv_exam_desc': 'Симуляция экзамена',
            'working_on_mistakes': 'Работа над ошибками',
            'saved': 'Сохраненные',
            'saved_questions_desc': 'Сохраненные вопросы из разных разделов',
            'learn_by_topics': 'Обучение по темам',
            'questions_by_topics': 'Вопросы по темам',
            'practice_tickets': 'Практические билеты',
            'random_questions_no_limit': 'Случайные вопросы, без ограничений',
            'time_60_minutes': '60 минут',
            'questions_40': '40 вопросов',
            'time_unlimited': 'Неограниченное время',
            'questions_100_sorted': '100+ вопросов по темах',
          }[key] ?? key;
        case 'pl':
          return {
            'tests': 'Testy',
            'testing': 'Testowanie',
            'take_exam': 'Zdaj egzamin',
            'dmv_exam_desc': 'Symulacja egzaminu',
            'working_on_mistakes': 'Praca nad błędami',
            'saved': 'Zapisane',
            'saved_questions_desc': 'Zapisane pytania z różnych sekcji',
            'learn_by_topics': 'Nauka według tematów',
            'questions_by_topics': 'Pytania według tematów',
            'practice_tickets': 'Bilety praktyczne',
            'random_questions_no_limit': 'Losowe pytania, bez limitu',
            'time_60_minutes': '60 minut',
            'questions_40': '40 pytań',
            'time_unlimited': 'Nieograniczony czas',
            'questions_100_sorted': '100+ pytań na tematy',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'tests': 'Tests',
            'testing': 'Testing',
            'take_exam': 'Take Exam',
            'dmv_exam_desc': 'Exam Simulation',
            'working_on_mistakes': 'Working on Mistakes',
            'saved': 'Saved',
            'saved_questions_desc': 'Saved questions from different sections',
            'learn_by_topics': 'Learn by Topics',
            'questions_by_topics': 'Questions by Topics',
            'practice_tickets': 'Practice Tickets',
            'random_questions_no_limit': 'Random questions, no limit',
            'time_60_minutes': '60 minutes',
            'questions_40': '40 questions',
            'time_unlimited': 'Unlimited time',
            'questions_100_sorted': '100+ topic questions',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [TEST SCREEN] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('🧪 [TEST SCREEN] Building with language: ${languageProvider.language}');
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _translate('tests', languageProvider),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Colors.black,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Add TrialStatusWidget here - under "Tests" title, above "Testing" section
                TrialStatusWidget(),
                
                Padding(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(_translate('testing', languageProvider)),
                  // Take Exam card with left and right info
                  _buildTestItem(
                    context,
                    'assets/images/exam.png',
                    _translate('take_exam', languageProvider),
                    _translate('dmv_exam_desc', languageProvider),
                    () {
                      // Session validation - validate before starting exam
                      if (!SessionValidationService.validateBeforeActionSafely(context)) {
                        print('🚨 TestScreen: Session invalid, blocking Take Exam action');
                        return; // User will be logged out by the validation service
                      }
                      
                      // NEW: Subscription validation - check if user has valid subscription
                      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                      if (SubscriptionChecker.shouldBlockPremiumFeature(subscriptionProvider)) {
                        print('🚫 TestScreen: Subscription invalid, blocking Take Exam action');
                        print('   - Block reason: ${SubscriptionChecker.getBlockReason(subscriptionProvider)}');
                        _showPremiumBlockDialog(context, _translate('take_exam', languageProvider));
                        return;
                      }
                      
                      // Track exam start FIRST
                      _logExamStartedAnalytics(languageProvider);
                      
                      // Start a new exam
                      final examProvider = Provider.of<ExamProvider>(context, listen: false);
                      
                      // Get language from provider
                      final language = languageProvider.language;
                      
                      // Get license type from provider, default to 'driver'
                      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
                      
                      // Start new exam with required parameters
                      examProvider.startNewExam(
                        language: language,
                        state: _questionState(), // Risk #39 — was hardcoded 'IL'
                        licenseType: licenseType,
                      );
                      
                      // Navigate to the exam question screen
                      crashReporter.log('nav: exam started');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ExamQuestionScreen(),
                        ),
                      );
                    },
                    leftInfoText: _translate('time_60_minutes', languageProvider),
                    rightInfoText: _translate('questions_40', languageProvider),
                    cardType: 0,
                  ),
                  // Learn by Topics card with left and right info
                  _buildTestItem(
                    context,
                    'assets/images/themes.png',
                    _translate('learn_by_topics', languageProvider),
                    _translate('questions_by_topics', languageProvider),
                    () {
                      // Session validation - validate before starting Learn by Topics
                      if (!SessionValidationService.validateBeforeActionSafely(context)) {
                        print('🚨 TestScreen: Session invalid, blocking Learn by Topics action');
                        return; // User will be logged out by the validation service
                      }
                      
                      // NEW: Subscription validation - check if user has valid subscription
                      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                      if (SubscriptionChecker.shouldBlockPremiumFeature(subscriptionProvider)) {
                        print('🚫 TestScreen: Subscription invalid, blocking Learn by Topics action');
                        print('   - Block reason: ${SubscriptionChecker.getBlockReason(subscriptionProvider)}');
                        _showPremiumBlockDialog(context, _translate('learn_by_topics', languageProvider));
                        return;
                      }
                      
                      // Track Learn by Topics start FIRST
                      _logLearnByTopicsStartedAnalytics(languageProvider);
                      
                      // Generate session ID for this Learn by Topics session
                      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
                      
                      // Navigate to themed questions
                      crashReporter.log('nav: topic quiz started');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TopicQuizScreen(sessionId: sessionId),
                        ),
                      );
                    },
                    leftInfoText: _translate('time_unlimited', languageProvider),
                    rightInfoText: _translate('questions_100_sorted', languageProvider),
                    cardType: 1,
                  ),
                  // Practice Tickets card with left and right info
                  _buildTestItem(
                    context,
                    'assets/images/random.png',
                    _translate('practice_tickets', languageProvider),
                    _translate('random_questions_no_limit', languageProvider),
                    () {
                      // Session validation - validate before starting Practice Tickets
                      if (!SessionValidationService.validateBeforeActionSafely(context)) {
                        print('🚨 TestScreen: Session invalid, blocking Practice Tickets action');
                        return; // User will be logged out by the validation service
                      }
                      
                      // NEW: Subscription validation - check if user has valid subscription
                      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                      if (SubscriptionChecker.shouldBlockPremiumFeature(subscriptionProvider)) {
                        print('🚫 TestScreen: Subscription invalid, blocking Practice Tickets action');
                        print('   - Block reason: ${SubscriptionChecker.getBlockReason(subscriptionProvider)}');
                        _showPremiumBlockDialog(context, _translate('practice_tickets', languageProvider));
                        return;
                      }
                      
                      // Track practice start FIRST
                      _logPracticeStartedAnalytics(languageProvider);
                      
                      // Start a new practice test
                      final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
                      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                      
                      final language = languageProvider.language;
                      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
                      
                      // Start new practice with required parameters
                      practiceProvider.startNewPractice(
                        language: language,
                        state: _questionState(), // Risk #39 — was hardcoded 'IL'
                        licenseType: licenseType,
                      ).then((_) {
                        // Navigate to the practice question screen after loading
                        crashReporter.log('nav: practice test started');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PracticeQuestionScreen(),
                          ),
                        );
                      });
                    },
                    leftInfoText: _translate('time_unlimited', languageProvider),
                    rightInfoText: _translate('questions_40', languageProvider),
                    cardType: 2,
                  ),
                  SizedBox(height: 16),
                  _buildSectionHeader(_translate('working_on_mistakes', languageProvider)),
                  // Saved card with no info text
                  _buildTestItem(
                    context,
                    'assets/images/saved.png',
                    _translate('saved', languageProvider),
                    _translate('saved_questions_desc', languageProvider),
                    () {
                      // Session validation - validate before navigating to Saved questions
                      if (!SessionValidationService.validateBeforeActionSafely(context)) {
                        print('🚨 TestScreen: Session invalid, blocking Saved action');
                        return; // User will be logged out by the validation service
                      }
                      
                      // NEW: Subscription validation - check if user has valid subscription
                      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
                      if (SubscriptionChecker.shouldBlockPremiumFeature(subscriptionProvider)) {
                        print('🚫 TestScreen: Subscription invalid, blocking Saved action');
                        print('   - Block reason: ${SubscriptionChecker.getBlockReason(subscriptionProvider)}');
                        _showPremiumBlockDialog(context, _translate('saved', languageProvider));
                        return;
                      }
                      
                      // Navigate to saved questions
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SavedItemsScreen(),
                        ),
                      );
                    },
                    cardType: 3,
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItem(
    BuildContext context,
    String imagePath,
    String title,
    String subtitle,
    VoidCallback onTap, {
    String? leftInfoText,
    String? rightInfoText,
    int cardType = 0,
  }) {
    return EnhancedTestCard(
      title: title,
      description: subtitle,
      icon: Icons.description, // Using the same icon for all cards for consistency
      leftInfoText: leftInfoText,
      rightInfoText: rightInfoText,
      cardType: cardType,
      onTap: onTap,
    );
  }
}
