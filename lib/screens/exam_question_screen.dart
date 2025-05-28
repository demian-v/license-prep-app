import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/progress_provider.dart';
import '../models/quiz_question.dart';
import '../services/service_locator.dart';
import 'exam_result_screen.dart';

class ExamQuestionScreen extends StatefulWidget {
  @override
  _ExamQuestionScreenState createState() => _ExamQuestionScreenState();
}

class _ExamQuestionScreenState extends State<ExamQuestionScreen> with TickerProviderStateMixin {
  dynamic selectedAnswer;
  bool isAnswerChecked = false;
  bool? isCorrect;
  ScrollController _pillsScrollController = ScrollController();
  late AnimationController _timerAnimationController;
  late Animation<double> _timerPulseAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize timer animation
    _timerAnimationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    
    _timerPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _timerAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the pulse animation
    _timerAnimationController.repeat(reverse: true);
    
    // Scroll to current pill when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPill();
    });
  }
  
  @override
  void dispose() {
    _timerAnimationController.dispose();
    _pillsScrollController.dispose();
    super.dispose();
  }
  
  void _scrollToCurrentPill() {
    if (!_pillsScrollController.hasClients) return;
    
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    final exam = examProvider.currentExam;
    if (exam == null) return;
    
    final pillWidth = 48.0; // Width of pill including margins
    final screenWidth = MediaQuery.of(context).size.width;
    final targetPosition = pillWidth * exam.currentQuestionIndex;
    final screenCenter = screenWidth / 2;
    
    final scrollOffset = targetPosition - screenCenter + (pillWidth / 2);
    
    _pillsScrollController.animateTo(
      scrollOffset.clamp(0.0, _pillsScrollController.position.maxScrollExtent),
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Helper method to get timer gradient based on remaining time
  LinearGradient _getTimerGradient(Duration remainingTime) {
    Color startColor = Colors.white;
    Color endColor;
    
    if (remainingTime.inMinutes > 30) {
      // Safe zone - green gradient
      endColor = Colors.green.shade50.withOpacity(0.6);
    } else if (remainingTime.inMinutes > 10) {
      // Caution zone - orange gradient
      endColor = Colors.orange.shade50.withOpacity(0.6);
    } else {
      // Critical zone - red gradient
      endColor = Colors.red.shade50.withOpacity(0.8);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Enhanced timer widget
  Widget _buildEnhancedTimer(Duration remainingTime, String timeText) {
    bool isCritical = remainingTime.inMinutes < 5;
    
    return AnimatedBuilder(
      animation: _timerPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isCritical ? _timerPulseAnimation.value : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: _getTimerGradient(remainingTime),
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
                  Icons.schedule,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 4),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);
    final exam = examProvider.currentExam;
    
    if (exam == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final currentQuestion = examProvider.getCurrentQuestion();
    if (currentQuestion == null) {
      return Scaffold(
        body: Center(
          child: Text("Питання не знайдено"),
        ),
      );
    }
    
    // Format remaining time
    final remainingTime = exam.remainingTime;
    final minutes = remainingTime.inMinutes;
    final seconds = remainingTime.inSeconds % 60;
    final timeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    
    // Update animation speed for critical time
    if (remainingTime.inMinutes < 5) {
      _timerAnimationController.duration = Duration(milliseconds: 800);
    } else {
      _timerAnimationController.duration = Duration(seconds: 2);
    }
    
    // Check if we need to show result screen
    if (exam.isCompleted) {
      // Navigate to results
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ExamResultScreen(),
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
          title: _buildEnhancedTimer(remainingTime, timeText),
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
              onPressed: () {
                // Report issue functionality
              },
            ),
            Consumer<ProgressProvider>(
              builder: (context, progressProvider, child) {
                final currentQuestion = examProvider.getCurrentQuestion();
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
            // Question number indicator
            Container(
              height: 50,
              child: ListView.builder(
                controller: _pillsScrollController,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: exam.questionIds.length,
                itemBuilder: (context, index) {
                  bool isActive = index == exam.currentQuestionIndex;
                  String questionId = exam.questionIds[index];
                  bool isAnswered = exam.answers.containsKey(questionId);
                  bool isAnsweredCorrectly = isAnswered ? exam.answers[questionId]! : false;
                  
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
            
            // Question image (if available) with rounded borders
            if (currentQuestion.imagePath != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    child: serviceLocator.storage.getImage(
                      storagePath: 'quiz_images/${currentQuestion.imagePath}',
                      assetFallback: currentQuestion.imagePath,
                      fit: BoxFit.cover,
                      placeholderIcon: Icons.broken_image,
                      placeholderColor: Colors.grey[200],
                    ),
                  ),
                ),
              ),
            
            // Enhanced question card
            _buildEnhancedQuestionCard(
              currentQuestion, 
              exam.currentQuestionIndex + 1, 
              exam.questionIds.length,
            ),
            
            // Answer options
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: currentQuestion.options.length,
                itemBuilder: (context, index) {
                  final option = currentQuestion.options[index];
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
                },
              ),
            ),
            
            // Action buttons
            Padding(
              padding: EdgeInsets.all(16),
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
                            examProvider.answerQuestion(
                              currentQuestion.id,
                              isCorrect ?? false,
                            );
                            
                            setState(() {
                              selectedAnswer = null;
                              isAnswerChecked = false;
                              isCorrect = null;
                            });
                            
                            examProvider.goToNextQuestion();
                            
                            // Scroll to the current pill after navigation
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollToCurrentPill();
                            });
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Center(
                            child: Text(
                              "Наступне",
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
                                  examProvider.skipQuestion();
                                  
                                  // Scroll to the current pill after navigation
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _scrollToCurrentPill();
                                  });
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Center(
                                  child: Text(
                                    "Пропустити",
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
                                    "Обрати",
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
                  "Питання ${currentQuestionNumber} з ${totalQuestions}",
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
                    "Декілька відповідей",
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
                        "Оберіть всі правильні відповіді",
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

  Future<bool> _onWillPop() async {
    final shouldPop = await _showExitConfirmation(context);
    return shouldPop ?? false;
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Вийти з тесту?"),
        content: Text(
          "Якщо ви вийдете з тесту, результат вашого проходження не збережеться",
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
                onTap: () {
                  Navigator.of(context).pop(true); // Yes, exit
                  // Cancel the exam
                  Provider.of<ExamProvider>(context, listen: false).cancelExam();
                  Navigator.of(context).pop(); // Return to previous screen
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      "Вийти",
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
                      "Залишитися",
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
