import 'package:flutter/material.dart';
import '../services/crash_reporter.dart';
import 'package:provider/provider.dart';
import '../data/license_data.dart';
import '../widgets/enhanced_test_card.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';
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
import '../theme/solar_icons.dart';

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
            'questions_100': '100+ preguntas',
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
            'questions_100': '100+ запитань',
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
            'questions_100': '100+ вопросов',
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
            'questions_100': '100+ pytań',
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
            'questions_100': '100+ questions',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [TEST SCREEN] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  // Entry handlers. Moved here unchanged from the inline closures that used to
  // sit inside `build`, so all three design variants run exactly the same
  // session check, subscription gate, analytics and navigation.

  void _onTakeExam(BuildContext context, LanguageProvider languageProvider) {
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
    // Shared-axis forward transition: entering a timed,
    // 40-question test should not feel like swapping between
    // peer screens.
    Navigator.push(
      context,
      ForwardPageRoute(child: ExamQuestionScreen()),
    );
  }

  void _onLearnByTopics(BuildContext context, LanguageProvider languageProvider) {
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
  }

  void _onPracticeTickets(BuildContext context, LanguageProvider languageProvider) {
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
  }

  void _onSaved(BuildContext context, LanguageProvider languageProvider) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('🧪 [TEST SCREEN] Building with language: ${languageProvider.language}');

        return ValueListenableBuilder<DesignVariant>(
          valueListenable: designVariant,
          builder: (context, variant, _) {
            final List<Widget> blocks;
            switch (variant) {
              case DesignVariant.refined:
                blocks = _refinedBlocks(context, languageProvider);
                break;
              case DesignVariant.boldA:
                blocks = _signalBlocks(context, languageProvider);
                break;
              case DesignVariant.boldB:
                blocks = _ledgerBlocks(context, languageProvider);
                break;
              case DesignVariant.bento:
                // Same structure as Refined; the cards themselves change.
                blocks = _refinedBlocks(context, languageProvider);
                break;
            }

            // One-shot entrance, keyed by variant so switching replays it.
            // Refined: 240ms cascade. Signal: a longer, springier rise.
            // Ledger: a single 180ms fade, no cascade.
            final Duration total = variant == DesignVariant.boldA
                ? AppMotion.slow
                : variant == DesignVariant.boldB
                    ? AppMotion.fast
                    : AppMotion.base;
            final Duration step = variant == DesignVariant.boldB
                ? Duration.zero
                : variant == DesignVariant.boldA
                    ? AppMotion.stagger * 1.5
                    : AppMotion.stagger;

            return DesignVariantSwitcher(
              child: Scaffold(
                // No AppBar: the title is content, set large and left. A
                // centred system title bar would put the chrome back.
                backgroundColor: variant == DesignVariant.boldB
                    ? AppColors.paper
                    : AppColors.field,
                body: SafeArea(
                  bottom: false,
                  child: SingleChildScrollView(
                    key: ValueKey(variant),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: variant == DesignVariant.boldB
                            ? AppSpacing.gutter
                            : AppSpacing.x4 + AppSpacing.x1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < blocks.length; i++)
                            StaggerIn(
                              index: i,
                              count: blocks.length,
                              total: total,
                              step: step,
                              rise: variant == DesignVariant.boldA
                                  ? 16
                                  : variant == DesignVariant.boldB
                                      ? 0
                                      : 8,
                              curve: VariantTokens.of(variant).curve,
                              child: blocks[i],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _examItem(BuildContext context, LanguageProvider languageProvider) =>
      _buildTestItem(
        context,
        'assets/images/exam.png',
        _translate('take_exam', languageProvider),
        _translate('dmv_exam_desc', languageProvider),
        () => _onTakeExam(context, languageProvider),
        leftInfoText: _translate('time_60_minutes', languageProvider),
        rightInfoText: _translate('questions_40', languageProvider),
        cardType: 0,
      );

  Widget _topicsItem(BuildContext context, LanguageProvider languageProvider) =>
      _buildTestItem(
        context,
        'assets/images/themes.png',
        _translate('learn_by_topics', languageProvider),
        _translate('questions_by_topics', languageProvider),
        () => _onLearnByTopics(context, languageProvider),
        leftInfoText: _translate('time_unlimited', languageProvider),
        // Short form: the tile's title already says "by topics".
        rightInfoText: _translate('questions_100', languageProvider),
        cardType: 1,
      );

  Widget _practiceItem(BuildContext context, LanguageProvider languageProvider) =>
      _buildTestItem(
        context,
        'assets/images/random.png',
        _translate('practice_tickets', languageProvider),
        _translate('random_questions_no_limit', languageProvider),
        () => _onPracticeTickets(context, languageProvider),
        leftInfoText: _translate('time_unlimited', languageProvider),
        rightInfoText: _translate('questions_40', languageProvider),
        cardType: 2,
      );

  Widget _savedItem(BuildContext context, LanguageProvider languageProvider) =>
      _buildTestItem(
        context,
        'assets/images/saved.png',
        _translate('saved', languageProvider),
        _translate('saved_questions_desc', languageProvider),
        () => _onSaved(context, languageProvider),
        cardType: 3,
      );

  /// The two practice modes side by side: they are peers, and pairing them
  /// keeps the exam above visually dominant.
  Widget _practicePair(BuildContext context, LanguageProvider languageProvider,
      {required double gap}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _topicsItem(context, languageProvider)),
          SizedBox(width: gap),
          Expanded(child: _practiceItem(context, languageProvider)),
        ],
      ),
    );
  }

  /// Refined: direction A with a strict 4/8 rhythm.
  List<Widget> _refinedBlocks(BuildContext context, LanguageProvider lp) => [
        // No screen title: the tab bar already names the tab.
        const SizedBox(height: AppSpacing.x2),
        // Status sits above the modes: it tells the user whether any of them
        // are even available to them.
        TrialStatusWidget(),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x8),
          child: _buildSectionHeader(_translate('testing', lp)),
        ),
        _examItem(context, lp),
        // Bento stacks the two practice modes full width: side by side they
        // left a large empty band above the tab bar whenever the trial card
        // is hidden (a paid subscriber sees none).
        if (designVariant.value == DesignVariant.bento) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            child: _topicsItem(context, lp),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            child: _practiceItem(context, lp),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            child: _practicePair(context, lp, gap: AppSpacing.x3),
          ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x8),
          child: _buildSectionHeader(_translate('working_on_mistakes', lp)),
        ),
        _savedItem(context, lp),
        const SizedBox(height: AppSpacing.x8),
      ];

  /// Signal: the exam is the hero; everything else steps back to support it.
  List<Widget> _signalBlocks(BuildContext context, LanguageProvider lp) => [
        // No screen title: the tab bar already names the tab.
        const SizedBox(height: AppSpacing.x2),
        TrialStatusWidget(),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x8),
          child: _buildSectionHeader(_translate('testing', lp)),
        ),
        _examItem(context, lp),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x4),
          child: _practicePair(context, lp, gap: AppSpacing.x4),
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x8),
          child: _buildSectionHeader(_translate('working_on_mistakes', lp)),
        ),
        _savedItem(context, lp),
        const SizedBox(height: AppSpacing.x8),
      ];

  /// Ledger: list-first. The exam leads; the rest are rows in one block.
  List<Widget> _ledgerBlocks(BuildContext context, LanguageProvider lp) {
    final tokens = VariantTokens.of(DesignVariant.boldB);
    Widget block(List<Widget> rows) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.card),
            border: Border.all(color: AppColors.borderStrong),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: AppSpacing.x4 + 20 + AppSpacing.x3,
                  ),
                rows[i],
              ],
            ],
          ),
        );

    return [
      // No screen title: the tab bar already names the tab.
      const SizedBox(height: AppSpacing.x2),
      TrialStatusWidget(),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x6),
        child: _buildSectionHeader(_translate('testing', lp)),
      ),
      _examItem(context, lp),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: block([_topicsItem(context, lp), _practiceItem(context, lp)]),
      ),
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x6),
        child: _buildSectionHeader(_translate('working_on_mistakes', lp)),
      ),
      block([_savedItem(context, lp)]),
      const SizedBox(height: AppSpacing.x8),
    ];
  }

  /// A section label.
  ///
  /// Was a centred label flanked by two hairline rules — a dated device that
  /// spent a full row of vertical space to say one word. Now a plain
  /// left-aligned label, in sentence case: all-caps is harder to read in
  /// Cyrillic, and an eyebrow label above every heading is decoration, not
  /// information.
  ///
  /// Secondary ink, not tertiary: tertiary is 3.1:1 on the field grey and
  /// fails body-text contrast.
  Widget _buildSectionHeader(String title) {
    final variant = designVariant.value;
    if (variant == DesignVariant.bento) {
      // Bento: section titles are small bold labels, like a dashboard's
      // panel headings.
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Text(
          title,
          style: AppTypography.label.copyWith(
            fontSize: 15,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      );
    }
    if (variant == DesignVariant.boldA) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Text(
          title,
          style: AppTypography.heading.copyWith(
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: variant == DesignVariant.boldB ? AppSpacing.x2 : AppSpacing.x3,
      ),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          fontSize: 13,
          color: AppColors.inkSecondary,
          fontVariations: const [FontVariation('wght', 600)],
        ),
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
      icon: SolarIcons.documentTextBold, // Using the same icon for all cards for consistency
      leftInfoText: leftInfoText,
      rightInfoText: rightInfoText,
      cardType: cardType,
      onTap: onTap,
    );
  }
}
