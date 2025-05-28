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

class _ExamQuestionScreenState extends State<ExamQuestionScreen> {
  dynamic selectedAnswer;
  bool isAnswerChecked = false;
  bool? isCorrect;
  ScrollController _pillsScrollController = ScrollController();
  
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
          title: Text("Іспит $timeText"),
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
                  
                  Color pillColor = isActive
                      ? Colors.blue
                      : isAnswered
                          ? isAnsweredCorrectly ? Colors.green : Colors.red
                          : Colors.grey[200]!;
                  
                  return Container(
                    width: 40,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive || isAnswered ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Question image (if available)
            if (currentQuestion.imagePath != null)
              Container(
                width: double.infinity,
                height: 200,
                child: serviceLocator.storage.getImage(
                  storagePath: 'quiz_images/${currentQuestion.imagePath}',
                  assetFallback: currentQuestion.imagePath,
                  fit: BoxFit.contain,
                  placeholderIcon: Icons.broken_image,
                  placeholderColor: Colors.grey[200],
                ),
              ),
            
            // Question text
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuestion.questionText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (currentQuestion.type == QuestionType.multipleChoice)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        "Оберіть всі правильні відповіді",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
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
                  ? ElevatedButton(
                      onPressed: () {
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        minimumSize: Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text("Наступне"),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // Skip question
                              examProvider.skipQuestion();
                              
                              // Scroll to the current pill after navigation
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToCurrentPill();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text("Пропустити"),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: selectedAnswer == null
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text("Обрати"),
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

  // Helper method to determine gradient colors based on answer card state
  LinearGradient _getGradientForAnswerCard(bool isSelected, bool showResult, bool isCorrectOption, [int index = 0]) {
    // Start with white as base color
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
        title: Text("Вийти з іспиту?"),
        content: Text(
          "Якщо ви вийдете з іспиту, результат вашого проходження не збережеться",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true); // Yes, exit
              // Cancel the exam
              Provider.of<ExamProvider>(context, listen: false).cancelExam();
              Navigator.of(context).pop(); // Return to previous screen
            },
            child: Text("Вийти"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(false); // No, stay
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text("Залишитися"),
          ),
        ],
      ),
    );
  }
}
