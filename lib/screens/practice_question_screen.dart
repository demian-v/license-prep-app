import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/practice_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../models/quiz_question.dart';
import '../services/service_locator.dart';
import '../services/analytics_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/report_sheet.dart';
import '../widgets/adaptive_question_image.dart';
import '../widgets/bento_question_parts.dart';
import 'practice_result_screen.dart';
import '../theme/app_theme.dart';

class PracticeQuestionScreen extends StatefulWidget {
  @override
  _PracticeQuestionScreenState createState() => _PracticeQuestionScreenState();
}

class _PracticeQuestionScreenState extends State<PracticeQuestionScreen> {
  dynamic selectedAnswer;
  bool isAnswerChecked = false;
  bool? isCorrect;
  ScrollController _pillsScrollController = ScrollController();
  ScrollController _mainScrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    
    // Scroll to current pill when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPill();
    });
  }
  
  @override
  void dispose() {
    _pillsScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }
  
  void _scrollToCurrentPill() {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final practice = practiceProvider.currentPractice;
    if (practice == null) return;

    BentoPillTray.scrollToPill(
        context, _pillsScrollController, practice.currentQuestionIndex);
  }

  void _resetMainScrollPosition() =>
      BentoPillTray.scrollToTop(context, _mainScrollController);

  /// Show report sheet for current question
  void _showReportSheet() {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final currentQuestion = practiceProvider.getCurrentQuestion();
    if (currentQuestion == null) return;
    
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'quiz_question',
        contextData: {
          'questionId': currentQuestion.id,
          'language': languageProvider.language,
          'state': authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL',
          'topicId': currentQuestion.topicId,
          'ruleReference': currentQuestion.ruleReference,
        },
      ),
    );
  }

  /// Analytics method for practice terminated event
  Future<void> _logPracticeTerminatedAnalytics() async {
    try {
      final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
      final practice = practiceProvider.currentPractice;
      
      if (practice != null) {
        // Get providers for analytics
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        final stateProvider = Provider.of<StateProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
        
        // Calculate analytics parameters
        final practiceId = 'practice_${practice.startTime.millisecondsSinceEpoch}';
        final questionsCompleted = practice.answeredQuestionsCount;
        final correctAnswers = practice.correctAnswersCount;
        final timeSpentSeconds = practice.elapsedTime.inSeconds;
        final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
        final language = languageProvider.language;
        final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
        
        // Log practice terminated analytics event
        await analyticsService.logPracticeTerminated(
          practiceId: practiceId,
          questionsCompleted: questionsCompleted,
          correctAnswers: correctAnswers,
          timeSpentSeconds: timeSpentSeconds,
          terminationReason: 'user_exit',
          state: state,
          language: language,
          licenseType: licenseType,
        );
        
        print('📊 Analytics: practice_terminated logged (practice_id: $practiceId, completed: $questionsCompleted/${practice.questionIds.length}, time: ${timeSpentSeconds}s)');
      }
    } catch (e) {
      print('❌ Analytics error: $e');
    }
  }

  // Handlers moved unchanged from the inline closures in `build`, so the
  // presentation can change without touching selection, checking, saving,
  // skipping or exit.

  void _selectOption(dynamic option) {
    setState(() {
      selectedAnswer = option;
    });
  }

  void _checkAnswer(QuizQuestion currentQuestion) {
    // Check answer
    setState(() {
      isAnswerChecked = true;
      
      if (currentQuestion.correctAnswer is List<String>) {
        isCorrect = (currentQuestion.correctAnswer as List<String>)
            .contains(selectedAnswer);
      } else {
        isCorrect = selectedAnswer == currentQuestion.correctAnswer;
      }
    });
  }

  void _goToNext(PracticeProvider practiceProvider, QuizQuestion currentQuestion) {
    // Save answer and move to next question
    practiceProvider.answerQuestion(
      currentQuestion.id,
      isCorrect ?? false,
    );
    
    setState(() {
      selectedAnswer = null;
      isAnswerChecked = false;
      isCorrect = null;
    });
    
    practiceProvider.goToNextQuestion();
    
    // Reset main scroll position and scroll to current pill after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMainScrollPosition();
      _scrollToCurrentPill();
    });
  }

  void _skip(PracticeProvider practiceProvider) {
    // Skip question
    practiceProvider.skipQuestion();
    
    // Reset main scroll position and scroll to current pill after navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMainScrollPosition();
      _scrollToCurrentPill();
    });
  }

  void _toggleSaved(ProgressProvider progressProvider, String questionId) {
    // Get auth provider to check if user is logged in
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? '';
    progressProvider.toggleSavedQuestionWithUserId(questionId, userId);
  }

  Future<void> _exitPractice(BuildContext context) async {
    // Log analytics before canceling
    await _logPracticeTerminatedAnalytics();
    
    Navigator.of(context).pop(true); // Yes, exit
    // Cancel the practice
    Provider.of<PracticeProvider>(context, listen: false).cancelPractice();
    Navigator.of(context).pop(); // Return to previous screen
  }

  /// Whether an option is a correct answer, as the old option builder
  /// computed it.
  bool _isCorrectOption(QuizQuestion currentQuestion, dynamic option) {
    bool isCorrectOption = false;
    
    // Check if this option is a correct answer
    if (currentQuestion.correctAnswer is List<String>) {
      isCorrectOption = (currentQuestion.correctAnswer as List<String>).contains(option);
    } else {
      isCorrectOption = option == currentQuestion.correctAnswer.toString();
    }
    return isCorrectOption;
  }

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context);
    final practice = practiceProvider.currentPractice;
    
    if (practice == null) {
      return Scaffold(
        backgroundColor: AppColors.field,
        body: Center(
          child: Text(AppLocalizations.of(context).translate('practice_not_active')),
        ),
      );
    }
    
    final currentQuestion = practiceProvider.getCurrentQuestion();
    if (currentQuestion == null) {
      return Scaffold(
        backgroundColor: AppColors.field,
        body: Center(
          child: Text(AppLocalizations.of(context).translate('question_not_found')),
        ),
      );
    }
    
    // Check if we need to show result screen
    if (practice.isCompleted) {
      // Navigate to results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PracticeResultScreen(),
          ),
        );
      });
      
      return Scaffold(
        backgroundColor: AppColors.field,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.field,
        // No title: «Практическая тренировка» did not fit between the
        // buttons, and the user has just chosen practice.
        appBar: bentoQuestionAppBar(
          onBack: () {
            _showExitConfirmation(context);
          },
          actions: bentoQuestionActions(
            context,
            reportTooltip: AppLocalizations.of(context).translate('report_issue'),
            onReport: _showReportSheet,
            isSaved: Provider.of<ProgressProvider>(context)
                .isQuestionSaved(currentQuestion.id),
            onToggleSaved: () => _toggleSaved(
              Provider.of<ProgressProvider>(context, listen: false),
              currentQuestion.id,
            ),
          ),
        ),
        body: Column(
          children: [
            // The pills show progress only, as before.
            BentoPillTray(
              controller: _pillsScrollController,
              count: practice.questionIds.length,
              stateOf: (index) {
                if (index == practice.currentQuestionIndex) {
                  return BentoPillState.current;
                }
                final answer = practice.answers[practice.questionIds[index]];
                if (answer == null) return BentoPillState.unseen;
                return answer ? BentoPillState.correct : BentoPillState.wrong;
              },
            ),
            
            // Question and answer options in one scrollable area
            Expanded(
              child: SingleChildScrollView(
                controller: _mainScrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question image (if available)
                    if (currentQuestion.imagePath != null)
                      AdaptiveQuestionImage(
                        imagePath: currentQuestion.imagePath!,
                        assetFallback: currentQuestion.imagePath,
                      ),
                    BentoQuestionCard(
                      counter: AppLocalizations.of(context).translate('question_x_of_y')
                          .replaceAll('{0}', (practice.currentQuestionIndex + 1).toString())
                          .replaceAll('{1}', practice.questionIds.length.toString()),
                      question: currentQuestion.questionText,
                      multipleLabel: currentQuestion.type == QuestionType.multipleChoice
                          ? AppLocalizations.of(context).translate('multiple_answers')
                          : null,
                      selectAllHint: currentQuestion.type == QuestionType.multipleChoice
                          ? AppLocalizations.of(context).translate('select_all_correct_answers')
                          : null,
                    ),
                    for (final entry in currentQuestion.options.asMap().entries)
                      BentoOptionTile(
                        index: entry.key,
                        text: '${entry.value}',
                        isSelected: selectedAnswer == entry.value,
                        showResult: isAnswerChecked,
                        isCorrectOption: _isCorrectOption(currentQuestion, entry.value),
                        onTap: isAnswerChecked
                            ? null
                            : () => _selectOption(entry.value),
                      ),
                  ],
                ),
              ),
            ),
            
            BentoCheckActions(
              isChecked: isAnswerChecked,
              skipLabel: AppLocalizations.of(context).translate('skip'),
              onSkip: () => _skip(practiceProvider),
              checkLabel: AppLocalizations.of(context).translate('choose'),
              onCheck: selectedAnswer == null
                  ? null
                  : () => _checkAnswer(currentQuestion),
              nextLabel: AppLocalizations.of(context).translate('next'),
              onNext: () => _goToNext(practiceProvider, currentQuestion),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await _showExitConfirmation(context);
    return shouldPop ?? false;
  }

  /// Staying is the safe, primary choice; leaving discards the attempt, so
  /// it takes the destructive colour — as on Экзамен.
  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        const double height = 44;
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        );
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          title: Text(
            localizations.translate('exit_practice_title'),
            style: AppTypography.heading,
          ),
          content: Text(
            localizations.translate('exit_practice_message'),
            style: AppTypography.body.copyWith(
              color: AppColors.inkSecondary,
              fontSize: 16,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          actions: [
            TextButton(
              onPressed: () => _exitPractice(context),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.stop,
                minimumSize: const Size(0, height),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                shape: shape,
                textStyle: AppTypography.label.copyWith(
                  fontSize: 16,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
              child: Text(localizations.translate('exit')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(false); // No, stay
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, height),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                shape: shape,
              ),
              child: Text(localizations.translate('stay')),
            ),
          ],
        );
      },
    );
  }
}
