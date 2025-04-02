import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../models/quiz_question.dart';
import '../providers/auth_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../services/service_locator.dart';
import '../localization/app_localizations.dart';
import 'quiz_result_screen.dart';

class QuizQuestionScreen extends StatefulWidget {
  final QuizTopic topic;
  
  const QuizQuestionScreen({
    Key? key,
    required this.topic,
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
  
  @override
  void initState() {
    super.initState();
    loadQuestions();
  }
  
  @override
  void dispose() {
    _pillsScrollController.dispose();
    super.dispose();
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
      
      // Scroll to the current question pill
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
          ),
        ),
      );
    }
  }
  
  void _scrollToCurrentPill() {
    if (_pillsScrollController.hasClients) {
      final pillWidth = 48.0; // Width of pill including margins
      final screenWidth = MediaQuery.of(context).size.width;
      final visiblePills = screenWidth / pillWidth;
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
  
  @override
  Widget build(BuildContext context) {
    // Common AppBar for all states
    final appBar = AppBar(
      title: Text(widget.topic.title),
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
    
    // Show error state
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
              ElevatedButton(
                onPressed: loadQuestions,
                child: Text(AppLocalizations.of(context).translate('try_again')),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state
    if (questions.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text(AppLocalizations.of(context).translate('no_questions')),
        ),
      );
    }
    
    final question = questions[currentQuestionIndex];
    
    // Create AppBar with actions for the question view
    final questionAppBar = AppBar(
      title: Text(widget.topic.title),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.warning_amber_rounded),
          onPressed: () {
            // Show report button functionality
          },
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
          // Question number pills
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
          if (question.imagePath != null)
            Container(
              width: double.infinity,
              height: 200,
              child: serviceLocator.storage.getImage(
                storagePath: 'quiz_images/${question.imagePath}',
                assetFallback: 'assets/images/quiz/default.png',
                fit: BoxFit.contain,
                placeholderIcon: Icons.broken_image,
                placeholderColor: Colors.grey[200],
              ),
            ),
          
          // Question text and selection type indicator
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (question.type == QuestionType.multipleChoice)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      AppLocalizations.of(context).translate('select_all_correct'),
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
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final option = question.options[index];
                bool isSelected = selectedAnswers.contains(option);
                bool showResult = isAnswerChecked;
                bool isCorrectOption = false;
                
                // Check if this option is a correct answer
                if (question.correctAnswer is List<String>) {
                  isCorrectOption = (question.correctAnswer as List<String>).contains(option);
                } else {
                  isCorrectOption = option == question.correctAnswer.toString();
                }
                
                // Define colors based on selection state
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
          
          // Explanation panel (if answer is checked)
          if (isAnswerChecked && question.explanation != null)
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (question.ruleReference != null)
                    Text(
                      question.ruleReference!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  SizedBox(height: 8),
                  Text(question.explanation!),
                ],
              ),
            ),
          
          // Action buttons
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isAnswerChecked ? goToNextQuestion : skipQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(isAnswerChecked 
                      ? AppLocalizations.of(context).translate('next') 
                      : AppLocalizations.of(context).translate('skip')),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedAnswers.isEmpty || isAnswerChecked 
                        ? null 
                        : checkAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(AppLocalizations.of(context).translate('check')),
                  ),
                ),
              ],
            ),
          ),
          
          // End topic button
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              AppLocalizations.of(context).translate('finish_topic'),
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
