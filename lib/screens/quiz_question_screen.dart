import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../models/quiz_question.dart';
import '../providers/auth_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../services/service_locator.dart';
import '../services/analytics_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/report_sheet.dart';
import '../widgets/adaptive_question_image.dart';
import '../widgets/bento_question_parts.dart';
import 'quiz_result_screen.dart';
import '../theme/app_theme.dart';

class QuizQuestionScreen extends StatefulWidget {
  final QuizTopic topic;
  final String? sessionId;
  final bool isTopicMode;
  final DateTime? startTime;
  
  const QuizQuestionScreen({
    Key? key,
    required this.topic,
    this.sessionId,
    this.isTopicMode = false,
    this.startTime,
  }) : super(key: key);
  
  @override
  _QuizQuestionScreenState createState() => _QuizQuestionScreenState();
}

class _QuizQuestionScreenState extends State<QuizQuestionScreen> {
  int currentQuestionIndex = 0;
  List<QuizQuestion> questions = [];
  Set<String> selectedAnswers = {};
  bool isAnswerChecked = false;
  bool? isCorrect;
  Map<String, bool> answers = {}; // questionId -> isCorrect
  bool isLoading = true;
  String? errorMessage;
  ScrollController _pillsScrollController = ScrollController();
  ScrollController _mainScrollController = ScrollController();
  late String _sessionId;
  DateTime? _startTime;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize session ID and start time
    _sessionId = widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _startTime = widget.startTime ?? DateTime.now();
    
    loadQuestions();
  }
  
  @override
  void dispose() {
    _pillsScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  // Helper method to get correct translations (same as bottom navigation)
  String _translate(String key, LanguageProvider languageProvider) {
    try {
      switch (languageProvider.language) {
        case 'es':
          return {
            'skip': 'Omitir',
            'check': 'Comprobar',
            'next': 'Siguiente',
            'finish_topic': 'Finalizar tema',
            'select_all_correct': 'Seleccionar todas las correctas',
            'try_again': 'Intentar de nuevo',
            'no_questions': 'No hay preguntas disponibles',
          }[key] ?? key;
        case 'uk':
          return {
            'skip': 'Пропустити',
            'check': 'Перевірити',
            'next': 'Далі',
            'finish_topic': 'Завершити тему',
            'select_all_correct': 'Виберіть всі правильні',
            'try_again': 'Спробувати знову',
            'no_questions': 'Немає доступних питань',
          }[key] ?? key;
        case 'ru':
          return {
            'skip': 'Пропустить',
            'check': 'Проверить',
            'next': 'Далее',
            'finish_topic': 'Завершить тему',
            'select_all_correct': 'Выберите все правильные',
            'try_again': 'Попробовать снова',
            'no_questions': 'Нет доступных вопросов',
          }[key] ?? key;
        case 'pl':
          return {
            'skip': 'Pomiń',
            'check': 'Sprawdź',
            'next': 'Dalej',
            'finish_topic': 'Zakończ temat',
            'select_all_correct': 'Wybierz wszystkie poprawne',
            'try_again': 'Spróbuj ponownie',
            'no_questions': 'Brak dostępnych pytań',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'skip': 'Skip',
            'check': 'Check',
            'next': 'Next',
            'finish_topic': 'End Topic',
            'select_all_correct': 'Select all correct answers',
            'try_again': 'Try again',
            'no_questions': 'No questions available',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [QUIZ] Error getting translation: $e');
      return key;
    }
  }

  Future<void> _trackTopicTerminated(String exitMethod) async {
    if (widget.isTopicMode && widget.sessionId != null) {
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      await serviceLocator.analytics.trackQTopicTerminated(
        sessionId: _sessionId,
        stateId: stateProvider.selectedState?.id ?? 'unknown',
        licenseType: 'cdl',
        topicId: widget.topic.id,
        topicName: widget.topic.title,
        questionNumber: currentQuestionIndex + 1,
        totalQuestions: questions.length,
        exitMethod: exitMethod,
      );
    }
  }
  
  Future<void> loadQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final language = languageProvider.language;
      // Get the current state from provider
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final state = stateProvider.selectedStateId ?? 'ALL'; // Default to ALL if null
      
      print('QuizQuestionScreen: Loading questions with topicId=${widget.topic.id}, language=$language, state=$state');
      
      // Fetch questions from Firebase
      final fetchedQuestions = await serviceLocator.content.getQuizQuestions(
        widget.topic.id, 
        language, 
        state
      );
      
      if (mounted) {
        setState(() {
          questions = fetchedQuestions;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading questions: $e');
      // Fallback to empty list
      if (mounted) {
        setState(() {
          questions = [];
          errorMessage = 'Failed to load questions. Please try again.'; // Error in English as specified
          isLoading = false;
        });
      }
    }
  }
  
  void checkAnswer() {
    if (selectedAnswers.isEmpty || isAnswerChecked) return;
    
    setState(() {
      isAnswerChecked = true;
      
      final currentQuestion = questions[currentQuestionIndex];
      final correctAnswer = currentQuestion.correctAnswer;
      
      // For debugging
      print('Selected answers: $selectedAnswers');
      print('Correct answer: $correctAnswer');
      print('Question type: ${currentQuestion.type}');
      
      // Different checking logic based on question type
      if (currentQuestion.type == QuestionType.multipleChoice) {
        // For multiple choice questions
        if (correctAnswer is List<String>) {
          // Check if selected answers match all correct answers
          isCorrect = selectedAnswers.length == correctAnswer.length &&
                      correctAnswer.every((answer) => selectedAnswers.contains(answer));
        } else {
          // Fallback if stored incorrectly
          isCorrect = selectedAnswers.contains(correctAnswer.toString());
        }
      } else {
        // For single choice questions
        if (correctAnswer is List<String> && correctAnswer.isNotEmpty) {
          isCorrect = selectedAnswers.contains(correctAnswer[0]);
        } else {
          isCorrect = selectedAnswers.contains(correctAnswer.toString());
        }
      }
      
      answers[currentQuestion.id] = isCorrect!;
    });
  }
  
  void skipQuestion() {
    goToNextQuestion();
  }
  
  void goToNextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswers = {};
        isAnswerChecked = false;
        isCorrect = null;
      });
      
      // Reset main scroll position and scroll to current pill
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resetMainScrollPosition();
        _scrollToCurrentPill();
      });
    } else {
      // Navigate to results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizResultScreen(
            topic: widget.topic,
            answers: answers,
            isTopicMode: widget.isTopicMode,
            sessionId: _sessionId,
            startTime: _startTime,
          ),
        ),
      );
    }
  }
  
  void _scrollToCurrentPill() =>
      BentoPillTray.scrollToPill(context, _pillsScrollController, currentQuestionIndex);

  void _resetMainScrollPosition() =>
      BentoPillTray.scrollToTop(context, _mainScrollController);

  // Handlers moved unchanged from the inline closures in `build`, so the
  // presentation can change without touching selection, saving or exit.

  void _selectOption(QuizQuestion question, String option, bool isSelected) {
    setState(() {
      if (question.type == QuestionType.multipleChoice) {
        // Toggle selection for multiple choice
        if (isSelected) {
          selectedAnswers.remove(option);
        } else {
          selectedAnswers.add(option);
        }
      } else {
        // Single selection for other types
        selectedAnswers = {option};
      }
    });
  }

  Future<void> _onBack() async {
    await _trackTopicTerminated('back_arrow');
    Navigator.pop(context);
  }

  void _toggleSaved(ProgressProvider progressProvider, String questionId) {
    // Get auth provider to check if user is logged in
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? '';
    progressProvider.toggleSavedQuestionWithUserId(questionId, userId);
  }

  /// Move to the question tapped in the strip (added 2026-09-26, as on
  /// Экзамен). A selection that was never checked is not an answer, so it is
  /// cleared rather than carried onto another question. A question already
  /// checked can be answered again; the new result replaces the old one.
  void _jumpToQuestion(int index) {
    if (index == currentQuestionIndex) return;

    setState(() {
      currentQuestionIndex = index;
      selectedAnswers = {};
      isAnswerChecked = false;
      isCorrect = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetMainScrollPosition();
      _scrollToCurrentPill();
    });
  }

  void _showReportSheet(BuildContext context) {
    if (questions.isEmpty) return;
    
    final currentQuestion = questions[currentQuestionIndex];
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'quiz_question',
        contextData: {
          'questionId': currentQuestion.id,
          'language': languageProvider.language,
          'state': stateProvider.selectedStateId ?? 'ALL',
          'topicId': currentQuestion.topicId,
          'ruleReference': currentQuestion.ruleReference,
        },
      ),
    );
  }
  
  /// Whether an option is a correct answer — moved unchanged from the old
  /// inline option builder.
  bool _isCorrectOption(QuizQuestion question, String option) {
    bool isCorrectOption = false;

    // Check if this option is a correct answer
    if (question.correctAnswer is List<String>) {
      isCorrectOption = (question.correctAnswer as List<String>).contains(option);
    } else {
      isCorrectOption = option == question.correctAnswer.toString();
    }
    return isCorrectOption;
  }

  @override
  Widget build(BuildContext context) {
    // Common AppBar for all states
    final appBar = bentoQuestionAppBar(onBack: () => Navigator.pop(context));

    // Show loading state
    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.field,
        appBar: appBar,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error state with reactive translation
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.field,
        appBar: appBar,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  errorMessage!,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.x4),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) {
                    return FilledButton(
                      onPressed: loadQuestions,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x6),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(_translate('try_again', languageProvider)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show empty state with reactive translation
    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.field,
        appBar: appBar,
        body: Center(
          child: Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return Text(
                _translate('no_questions', languageProvider),
                style:
                    AppTypography.body.copyWith(color: AppColors.inkSecondary),
              );
            },
          ),
        ),
      );
    }

    final question = questions[currentQuestionIndex];

    // The question view adds report and save, both one tap away.
    final questionAppBar = bentoQuestionAppBar(
      onBack: _onBack,
      actions: bentoQuestionActions(
        context,
        reportTooltip: AppLocalizations.of(context).translate('report_issue'),
        onReport: () => _showReportSheet(context),
        isSaved: Provider.of<ProgressProvider>(context)
            .isQuestionSaved(questions[currentQuestionIndex].id),
        onToggleSaved: () => _toggleSaved(
          Provider.of<ProgressProvider>(context, listen: false),
          questions[currentQuestionIndex].id,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: questionAppBar,
      body: Column(
        children: [
          BentoPillTray(
            controller: _pillsScrollController,
            count: questions.length,
            stateOf: (index) {
              if (index == currentQuestionIndex) return BentoPillState.current;
              final answer = answers[questions[index].id];
              if (answer == null) return BentoPillState.unseen;
              return answer ? BentoPillState.correct : BentoPillState.wrong;
            },
            onTap: _jumpToQuestion,
          ),

          // Question, options and explanation in one scrollable area
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
                  if (question.imagePath != null)
                    AdaptiveQuestionImage(
                      imagePath: question.imagePath!,
                      assetFallback: 'assets/images/quiz/default.png',
                    ),
                  BentoQuestionCard(
                    counter: AppLocalizations.of(context)
                        .translate('question_x_of_y')
                        .replaceAll('{0}', (currentQuestionIndex + 1).toString())
                        .replaceAll('{1}', questions.length.toString()),
                    question: question.questionText,
                    multipleLabel: question.type == QuestionType.multipleChoice
                        ? AppLocalizations.of(context).translate('multiple_answers')
                        : null,
                    selectAllHint: question.type == QuestionType.multipleChoice
                        ? _translate('select_all_correct',
                            Provider.of<LanguageProvider>(context))
                        : null,
                  ),
                  for (final entry in question.options.asMap().entries)
                    BentoOptionTile(
                      index: entry.key,
                      text: entry.value,
                      isSelected: selectedAnswers.contains(entry.value),
                      showResult: isAnswerChecked,
                      isCorrectOption: _isCorrectOption(question, entry.value),
                      onTap: isAnswerChecked
                          ? null
                          : () => _selectOption(question, entry.value,
                              selectedAnswers.contains(entry.value)),
                    ),
                  if (isAnswerChecked && question.explanation != null)
                    BentoExplanation(
                      title: AppLocalizations.of(context).translate('explanation'),
                      ruleReference: question.ruleReference,
                      text: question.explanation!,
                    ),
                ],
              ),
            ),
          ),

          Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) => BentoCheckActions(
              isChecked: isAnswerChecked,
              skipLabel: _translate('skip', languageProvider),
              onSkip: skipQuestion,
              checkLabel: _translate('check', languageProvider),
              onCheck: selectedAnswers.isEmpty || isAnswerChecked
                  ? null
                  : checkAnswer,
              nextLabel: _translate('next', languageProvider),
              onNext: goToNextQuestion,
            ),
          ),
        ],
      ),
    );
  }
}
