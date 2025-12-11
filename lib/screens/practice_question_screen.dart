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
import 'practice_result_screen.dart';

class PracticeQuestionScreen extends StatefulWidget {
  @override
  _PracticeQuestionScreenState createState() => _PracticeQuestionScreenState();
}

class _PracticeQuestionScreenState extends State<PracticeQuestionScreen> with TickerProviderStateMixin {
  dynamic selectedAnswer;
  bool isAnswerChecked = false;
  bool? isCorrect;
  ScrollController _pillsScrollController = ScrollController();
  ScrollController _mainScrollController = ScrollController();
  late AnimationController _titleAnimationController;
  late Animation<double> _titlePulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize title animation
    _titleAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _titlePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the subtle pulse animation
    _titleAnimationController.repeat(reverse: true);
    
    // Scroll to current pill when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPill();
    });
  }
  
  @override
  void dispose() {
    _titleAnimationController.dispose();
    _pillsScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }
  
  void _scrollToCurrentPill() {
    if (!_pillsScrollController.hasClients) return;
    
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final practice = practiceProvider.currentPractice;
    if (practice == null) return;
    
    final pillWidth = 48.0; // Width of pill including margins
    final screenWidth = MediaQuery.of(context).size.width;
    final targetPosition = pillWidth * practice.currentQuestionIndex;
    final screenCenter = screenWidth / 2;
    
    final scrollOffset = targetPosition - screenCenter + (pillWidth / 2);
    
    _pillsScrollController.animateTo(
      scrollOffset.clamp(0.0, _pillsScrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
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

  // Enhanced practice title widget
  Widget _buildEnhancedPracticeTitle() {
    return AnimatedBuilder(
      animation: _titlePulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _titlePulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.orange.shade50.withOpacity(0.6)], // Practice theme color
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
                  Icons.fitness_center,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).translate('practice_training'),
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
        endColor = Colors.blue.shade50.withOpacity(0.3); // Like "Take Exam" card
        break;
      case 1:
        endColor = Colors.green.shade50.withOpacity(0.3); // Like "Learn by Topics" card
        break;
      case 2:
        endColor = Colors.orange.shade50.withOpacity(0.3); // Like "Practice Tickets" card
        break;
      case 3:
        endColor = Colors.purple.shade50.withOpacity(0.3); // Like "Saved" card
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

  // Enhanced question card widget
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
                      child: Text(
                        AppLocalizations.of(context).translate('select_all_correct_answers'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
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
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    // Determine end color based on button type
    switch(buttonType) {
      case 0: // Skip button
        endColor = Colors.blue.shade50.withOpacity(0.4); // Like "Take Exam" card
        break;
      case 1: // Choose button
        endColor = Colors.green.shade50.withOpacity(0.4); // Like "Learn by Topics" card
        break;
      case 2: // Next button
        endColor = Colors.orange.shade50.withOpacity(0.4); // Like "Practice Tickets" card
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

  // Helper method to determine gradient colors based on answer card state
  LinearGradient _getGradientForAnswerCard(bool isSelected, bool showResult, bool isCorrectOption, [int index = 0]) {
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    if (showResult) {
      if (isSelected && isCorrectOption) {
        endColor = Colors.green.shade50.withOpacity(0.6); // Using green for correct answers
      } else if (isSelected && !isCorrectOption) {
        endColor = Colors.red.shade50.withOpacity(0.6); // Using red for incorrect answers
      } else if (isCorrectOption) {
        endColor = Colors.green.shade50.withOpacity(0.6); // Using green for correct answers
      } else {
        endColor = Colors.grey.shade50.withOpacity(0.2);
      }
    } else if (isSelected) {
      endColor = Colors.blue.shade50.withOpacity(0.4); // Similar to "Take Exam" card
    } else {
      // Cycle through pastel colors for unselected cards
      switch (index % 4) {
        case 0:
          endColor = Colors.blue.shade50.withOpacity(0.4); // Take Exam color
          break;
        case 1:
          endColor = Colors.green.shade50.withOpacity(0.4); // Learn by Topics color
          break;
        case 2:
          endColor = Colors.orange.shade50.withOpacity(0.4); // Practice Tickets color
          break;
        case 3:
          endColor = Colors.purple.shade50.withOpacity(0.4); // Saved color
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

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context);
    final practice = practiceProvider.currentPractice;
    
    if (practice == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context).translate('practice_not_active')),
        ),
      );
    }
    
    final currentQuestion = practiceProvider.getCurrentQuestion();
    if (currentQuestion == null) {
      return Scaffold(
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
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: _buildEnhancedPracticeTitle(),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              _showExitConfirmation(context);
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.warning_amber_rounded),
              onPressed: _showReportSheet,
            ),
            Consumer<ProgressProvider>(
              builder: (context, progressProvider, child) {
                final currentQuestion = practiceProvider.getCurrentQuestion();
                if (currentQuestion == null) return SizedBox.shrink();
                
                final questionId = currentQuestion.id;
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
        ),
        body: Column(
          children: [
            // Question number indicator with gradients
            Container(
              height: 50,
              child: ListView.builder(
                controller: _pillsScrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: practice.questionIds.length,
                itemBuilder: (context, index) {
                  bool isActive = index == practice.currentQuestionIndex;
                  String questionId = practice.questionIds[index];
                  bool isAnswered = practice.answers.containsKey(questionId);
                  bool isAnsweredCorrectly = isAnswered ? practice.answers[questionId]! : false;
                  
                  // Determine gradient for pill
                  LinearGradient pillGradient;
                  if (isActive) {
                    // Current question - blue pastel gradient (like "Take Exam" card)
                    pillGradient = LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.blue.shade100],
                    );
                  } else if (isAnswered) {
                    if (isAnsweredCorrectly) {
                      // Correctly answered - use green pastel gradient
                      pillGradient = LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.green.shade100],
                      );
                    } else {
                      // Incorrectly answered - use red pastel gradient
                      pillGradient = LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.red.shade100],
                      );
                    }
                  } else {
                    // Unanswered - light gray pastel gradient
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
            
            // Answer options, question content in single scrollable area
            Expanded(
              child: SingleChildScrollView(
                controller: _mainScrollController,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Question image (if available) - moved inside scroll view
                    if (currentQuestion.imagePath != null)
                      AdaptiveQuestionImage(
                        imagePath: currentQuestion.imagePath!,
                        assetFallback: currentQuestion.imagePath,
                      ),
                    
                    // Enhanced question card - moved inside scroll view
                    Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: _getQuestionCardGradient(practice.currentQuestionIndex + 1),
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
                                      .replaceAll('{0}', (practice.currentQuestionIndex + 1).toString())
                                      .replaceAll('{1}', practice.questionIds.length.toString()),
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
                                      child: Text(
                                        AppLocalizations.of(context).translate('select_all_correct_answers'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Answer options - converted from ListView.builder to Column
                    ...currentQuestion.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      bool isSelected = selectedAnswer == option;
                      bool showResult = isAnswerChecked;
                      bool isCorrectOption = false;
                      
                      // Check if this option is a correct answer
                      if (currentQuestion.correctAnswer is List<String>) {
                        isCorrectOption = (currentQuestion.correctAnswer as List<String>).contains(option);
                      } else {
                        isCorrectOption = option == currentQuestion.correctAnswer.toString();
                      }
                      
                      // Get gradient based on card state instead of solid color
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
                                  selectedAnswer = option;
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
                  ],
                ),
              ),
            ),
            
            // Enhanced action buttons positioned like "Back to Theory" button
            Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 4),
              child: isAnswerChecked
                  ? Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _getGradientForButton(2), // Next button
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
                          onTap: () {
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
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context).translate('next'),
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Skip button with gradient
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: _getGradientForButton(0), // Skip button
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
                                onTap: () {
                                  // Skip question
                                  practiceProvider.skipQuestion();
                                  
                                  // Reset main scroll position and scroll to current pill after navigation
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _resetMainScrollPosition();
                                    _scrollToCurrentPill();
                                  });
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Center(
                                  child: Text(
                                    AppLocalizations.of(context).translate('skip'),
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        // Choose button with gradient
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: selectedAnswer == null
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Colors.grey.shade300, Colors.grey.shade200],
                                    )
                                  : _getGradientForButton(1), // Choose button
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
                                onTap: selectedAnswer == null
                                    ? null
                                    : () {
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
                                      },
                                borderRadius: BorderRadius.circular(30),
                                child: Center(
                                  child: Text(
                                    AppLocalizations.of(context).translate('choose'),
                                    style: TextStyle(
                                      color: selectedAnswer == null ? Colors.grey.shade600 : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
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
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await _showExitConfirmation(context);
    return shouldPop ?? false;
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('exit_practice_title')),
        content: Text(
          AppLocalizations.of(context).translate('exit_practice_message'),
        ),
        actions: [
          // Exit button with gradient
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)], // Like "Take Exam" card
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // Log analytics before canceling
                  await _logPracticeTerminatedAnalytics();
                  
                  Navigator.of(context).pop(true); // Yes, exit
                  // Cancel the practice
                  Provider.of<PracticeProvider>(context, listen: false).cancelPractice();
                  Navigator.of(context).pop(); // Return to previous screen
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).translate('exit'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Stay button with gradient
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50.withOpacity(0.4)], // Like "Learn by Topics" card
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(false); // No, stay
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).translate('stay'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
