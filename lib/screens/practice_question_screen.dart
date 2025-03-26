import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/practice_provider.dart';
import '../providers/progress_provider.dart';
import '../models/quiz_question.dart';
import 'practice_result_screen.dart';

class PracticeQuestionScreen extends StatefulWidget {
  @override
  _PracticeQuestionScreenState createState() => _PracticeQuestionScreenState();
}

class _PracticeQuestionScreenState extends State<PracticeQuestionScreen> {
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

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context);
    final practice = practiceProvider.currentPractice;
    
    if (practice == null) {
      return Scaffold(
        body: Center(
          child: Text("Тренування не активне"),
        ),
      );
    }
    
    final currentQuestion = practiceProvider.getCurrentQuestion();
    if (currentQuestion == null) {
      return Scaffold(
        body: Center(
          child: Text("Питання не знайдено"),
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
          title: Text("Тренування по білетах"),
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
            // Question number indicator
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
                child: Image.asset(
                  currentQuestion.imagePath!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => 
                    Center(child: Icon(Icons.broken_image, size: 50)),
                ),
              ),
            
            // Question text
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                currentQuestion.questionText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                  bool isCorrectOption = option == currentQuestion.correctAnswer;
                  
                  Color backgroundColor = Colors.white;
                  if (showResult) {
                    if (isSelected && isCorrectOption) {
                      backgroundColor = Colors.green;
                    } else if (isSelected && !isCorrectOption) {
                      backgroundColor = Colors.red;
                    } else if (isCorrectOption) {
                      backgroundColor = Colors.green;
                    }
                  } else if (isSelected) {
                    backgroundColor = Colors.blue.shade100;
                  }
                  
                  // Use circular indicators for both single and multiple choice questions
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
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          selectionIndicator,
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: showResult && (isSelected || isCorrectOption)
                                    ? Colors.white
                                    : Colors.black,
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
                              practiceProvider.skipQuestion();
                              
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
                                      isCorrect = selectedAnswer == currentQuestion.correctAnswer;
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

  Future<bool> _onWillPop() async {
    final shouldPop = await _showExitConfirmation(context);
    return shouldPop ?? false;
  }

  Future<bool?> _showExitConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Вийти з тренування?"),
        content: Text(
          "Якщо ви вийдете з тренування, результат вашого проходження не збережеться",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true); // Yes, exit
              // Cancel the practice
              Provider.of<PracticeProvider>(context, listen: false).cancelPractice();
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
