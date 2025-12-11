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
import 'quiz_result_screen.dart';

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

class _QuizQuestionScreenState extends State<QuizQuestionScreen> with TickerProviderStateMixin {
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
  late AnimationController _titleAnimationController;
  late Animation<double> _titlePulseAnimation;
  late String _sessionId;
  DateTime? _startTime;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize session ID and start time
    _sessionId = widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString();
    _startTime = widget.startTime ?? DateTime.now();
    
    // Initialize title animation
    _titleAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _titlePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the subtle pulse animation
    _titleAnimationController.repeat(reverse: true);
    
    loadQuestions();
  }
  
  @override
  void dispose() {
    _titleAnimationController.dispose();
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

  // Enhanced topic title widget
  Widget _buildEnhancedTopicTitle(String topicTitle) {
    // Choose gradient color based on topic for variety
    Color endColor;
    IconData topicIcon;
    
    // Dynamic theming based on topic content
    if (topicTitle.toLowerCase().contains('загальн')) {
      endColor = Colors.purple.shade50.withOpacity(0.6);
      topicIcon = Icons.info_outline;
    } else if (topicTitle.toLowerCase().contains('правила')) {
      endColor = Colors.blue.shade50.withOpacity(0.6);
      topicIcon = Icons.rule;
    } else if (topicTitle.toLowerCase().contains('безпек')) {
      endColor = Colors.green.shade50.withOpacity(0.6);
      topicIcon = Icons.security;
    } else if (topicTitle.toLowerCase().contains('велосипед')) {
      endColor = Colors.orange.shade50.withOpacity(0.6);
      topicIcon = Icons.directions_bike;
    } else {
      endColor = Colors.indigo.shade50.withOpacity(0.6);
      topicIcon = Icons.school;
    }
    
    return AnimatedBuilder(
      animation: _titlePulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _titlePulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, endColor],
                stops: [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  topicIcon,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    topicTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for question card gradient
  LinearGradient _getQuestionCardGradient(int currentQuestionNumber) {
    Color startColor = Colors.white;
    Color endColor;
    
    // Cycle through pastel colors based on question number
    switch (currentQuestionNumber % 4) {
      case 0:
        endColor = Colors.blue.shade50.withOpacity(0.3);
        break;
      case 1:
        endColor = Colors.green.shade50.withOpacity(0.3);
        break;
      case 2:
        endColor = Colors.orange.shade50.withOpacity(0.3);
        break;
      case 3:
        endColor = Colors.purple.shade50.withOpacity(0.3);
        break;
      default:
        endColor = Colors.blue.shade50.withOpacity(0.3);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Enhanced question card widget with reactive translation
  Widget _buildEnhancedQuestionCard(QuizQuestion currentQuestion, int currentQuestionNumber, int totalQuestions) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getQuestionCardGradient(currentQuestionNumber),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number indicator
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('question_x_of_y')
                    .replaceAll('{0}', currentQuestionNumber.toString())
                    .replaceAll('{1}', totalQuestions.toString()),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ),
              if (currentQuestion.type == QuestionType.multipleChoice) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('multiple_answers'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 12),
          // Question text
          Text(
            currentQuestion.questionText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.4,
            ),
          ),
          if (currentQuestion.type == QuestionType.multipleChoice)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) {
                          return Text(
                            _translate('select_all_correct', languageProvider),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method for button gradients
  LinearGradient _getGradientForButton(int buttonType) {
    Color startColor = Colors.white;
    Color endColor;
    
    switch(buttonType) {
      case 0: // Skip/Next button
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 1: // Check button
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 2: // End Topic button
        endColor = Colors.purple.shade50.withOpacity(0.4);
        break;
      default:
        endColor = Colors.grey.shade50.withOpacity(0.4);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Helper method for answer card gradients
  LinearGradient _getGradientForAnswerCard(bool isSelected, bool showResult, bool isCorrectOption, [int index = 0]) {
    Color startColor = Colors.white;
    Color endColor;
    
    if (showResult) {
      if (isSelected && isCorrectOption) {
        endColor = Colors.green.shade50.withOpacity(0.6);
      } else if (isSelected && !isCorrectOption) {
        endColor = Colors.red.shade50.withOpacity(0.6);
      } else if (isCorrectOption) {
        endColor = Colors.green.shade50.withOpacity(0.6);
      } else {
        endColor = Colors.grey.shade50.withOpacity(0.2);
      }
    } else if (isSelected) {
      endColor = Colors.blue.shade50.withOpacity(0.4);
    } else {
      // Cycle through pastel colors
      switch (index % 4) {
        case 0:
          endColor = Colors.blue.shade50.withOpacity(0.4);
          break;
        case 1:
          endColor = Colors.green.shade50.withOpacity(0.4);
          break;
        case 2:
          endColor = Colors.orange.shade50.withOpacity(0.4);
          break;
        case 3:
          endColor = Colors.purple.shade50.withOpacity(0.4);
          break;
        default:
          endColor = Colors.grey.shade50.withOpacity(0.2);
      }
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Enhanced explanation panel
  Widget _buildEnhancedExplanationPanel(QuizQuestion question) {
    if (!isAnswerChecked || question.explanation == null) {
      return SizedBox.shrink();
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.3)],
          stops: [0.0, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 20,
                color: Colors.indigo.shade700,
              ),
              SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context).translate('explanation'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                  fontSize: 16,
                                ),
                              ),
            ],
          ),
          if (question.ruleReference != null) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                question.ruleReference!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          SizedBox(height: 12),
          Text(
            question.explanation!,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
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
  
  void _scrollToCurrentPill() {
    if (_pillsScrollController.hasClients) {
      final pillWidth = 48.0; // Width of pill including margins
      final screenWidth = MediaQuery.of(context).size.width;
      final targetPosition = pillWidth * currentQuestionIndex;
      final screenCenter = screenWidth / 2;
      
      final scrollOffset = targetPosition - screenCenter + (pillWidth / 2);
      
      _pillsScrollController.animateTo(
        scrollOffset.clamp(0.0, _pillsScrollController.position.maxScrollExtent),
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
  
  void _resetMainScrollPosition() {
    if (_mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
  
  @override
  Widget build(BuildContext context) {
    // Common AppBar for all states
    final appBar = AppBar(
      title: _buildEnhancedTopicTitle(widget.topic.title),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    );
    
    // Show loading state
    if (isLoading) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show error state with reactive translation
    if (errorMessage != null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) {
                  return ElevatedButton(
                    onPressed: loadQuestions,
                    child: Text(_translate('try_again', languageProvider)),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state with reactive translation
    if (questions.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Consumer<LanguageProvider>(
            builder: (context, languageProvider, _) {
              return Text(_translate('no_questions', languageProvider));
            },
          ),
        ),
      );
    }
    
    final question = questions[currentQuestionIndex];
    
    // Create AppBar with actions for the question view
    final questionAppBar = AppBar(
      title: _buildEnhancedTopicTitle(widget.topic.title),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () async {
          await _trackTopicTerminated('back_arrow');
          Navigator.pop(context);
        },
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.warning_amber_rounded),
          onPressed: () => _showReportSheet(context),
        ),
        Consumer<ProgressProvider>(
          builder: (context, progressProvider, child) {
            final questionId = questions[currentQuestionIndex].id;
            final isSaved = progressProvider.isQuestionSaved(questionId);
            
            return IconButton(
              icon: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? Colors.red : null,
              ),
              onPressed: () {
                // Get auth provider to check if user is logged in
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final userId = authProvider.user?.id ?? '';
                progressProvider.toggleSavedQuestionWithUserId(questionId, userId);
              },
            );
          },
        ),
      ],
    );
    
    return Scaffold(
      appBar: questionAppBar,
      body: Column(
        children: [
          // Enhanced question number pills
          Container(
            height: 50,
            child: ListView.builder(
              controller: _pillsScrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                bool isActive = index == currentQuestionIndex;
                bool isAnswered = answers.containsKey(questions[index].id);
                bool isAnsweredCorrectly = isAnswered ? answers[questions[index].id]! : false;
                
                // Determine gradient for pill
                LinearGradient pillGradient;
                if (isActive) {
                  pillGradient = LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.blue.shade100],
                  );
                } else if (isAnswered) {
                  if (isAnsweredCorrectly) {
                    pillGradient = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.green.shade100],
                    );
                  } else {
                    pillGradient = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.red.shade100],
                    );
                  }
                } else {
                  pillGradient = LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade100],
                  );
                }
                
                return Container(
                  width: 40,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: pillGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Enhanced answer options, question content, and explanation in single scrollable area
          Expanded(
            child: SingleChildScrollView(
              controller: _mainScrollController,
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 24),
              child: Column(
                children: [
                  // Enhanced question image (if available) - moved inside scroll view
                  if (question.imagePath != null)
                    AdaptiveQuestionImage(
                      imagePath: question.imagePath!,
                      assetFallback: 'assets/images/quiz/default.png',
                    ),
                  
                  // Enhanced question card - moved inside scroll view
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: _getQuestionCardGradient(currentQuestionIndex + 1),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question number indicator
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                AppLocalizations.of(context).translate('question_x_of_y')
                                  .replaceAll('{0}', (currentQuestionIndex + 1).toString())
                                  .replaceAll('{1}', questions.length.toString()),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black.withOpacity(0.7),
                                ),
                              ),
                            ),
                            if (question.type == QuestionType.multipleChoice) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).translate('multiple_answers'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 12),
                        // Question text
                        Text(
                          question.questionText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.4,
                          ),
                        ),
                        if (question.type == QuestionType.multipleChoice)
                          Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue.shade700,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Consumer<LanguageProvider>(
                                      builder: (context, languageProvider, _) {
                                        return Text(
                                          _translate('select_all_correct', languageProvider),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Answer options
                  ...question.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    bool isSelected = selectedAnswers.contains(option);
                    bool showResult = isAnswerChecked;
                    bool isCorrectOption = false;
                    
                    // Check if this option is a correct answer
                    if (question.correctAnswer is List<String>) {
                      isCorrectOption = (question.correctAnswer as List<String>).contains(option);
                    } else {
                      isCorrectOption = option == question.correctAnswer.toString();
                    }
                    
                    // Get gradient for answer card
                    LinearGradient cardGradient = _getGradientForAnswerCard(isSelected, showResult, isCorrectOption, index);
                    
                    // Use circular indicators
                    Widget selectionIndicator = Container(
                      width: 24,
                      height: 24,
                      margin: EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey),
                      ),
                      child: isSelected
                          ? Container(
                              margin: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            )
                          : null,
                    );
                    
                    return GestureDetector(
                      onTap: isAnswerChecked 
                          ? null 
                          : () {
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
                            },
                      child: Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: cardGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 0,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            selectionIndicator,
                            Expanded(
                              child: Text(
                                option,
                                style: TextStyle(
                                  color: showResult && (isSelected || isCorrectOption)
                                      ? (isSelected && !isCorrectOption) ? Colors.red.shade900 : Colors.green.shade900
                                      : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  
                  // Enhanced explanation panel with improved spacing
                  if (isAnswerChecked && question.explanation != null) ...[
                    SizedBox(height: 20), // Space between answers and explanation
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.3)],
                          stops: [0.0, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 0,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 20,
                                color: Colors.indigo.shade700,
                              ),
                              SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context).translate('explanation'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          if (question.ruleReference != null) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                question.ruleReference!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 12),
                          Text(
                            question.explanation!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20), // Extra space at the bottom for better scrolling
                  ],
                ],
              ),
            ),
          ),
          
          // Enhanced action buttons positioned like "Back to Theory" button
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: selectedAnswers.isEmpty || isAnswerChecked
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.grey.shade300, Colors.grey.shade200],
                            )
                          : _getGradientForButton(1), // Check button
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: selectedAnswers.isEmpty || isAnswerChecked 
                            ? null 
                            : checkAnswer,
                        borderRadius: BorderRadius.circular(30),
                        child: Center(
                          child: Consumer<LanguageProvider>(
                            builder: (context, languageProvider, _) {
                              return Text(
                                _translate('check', languageProvider),
                                style: TextStyle(
                                  color: selectedAnswers.isEmpty || isAnswerChecked ? Colors.grey.shade600 : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _getGradientForButton(0), // Skip/Next button
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isAnswerChecked ? goToNextQuestion : skipQuestion,
                        borderRadius: BorderRadius.circular(30),
                        child: Center(
                          child: Consumer<LanguageProvider>(
                            builder: (context, languageProvider, _) {
                              return Text(
                                isAnswerChecked 
                                  ? _translate('next', languageProvider)
                                  : _translate('skip', languageProvider),
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
