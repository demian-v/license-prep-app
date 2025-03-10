import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quiz_data.dart';
import '../models/quiz_topic.dart';
import '../models/quiz_question.dart';
import '../providers/progress_provider.dart';
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
  dynamic selectedAnswer;
  bool isAnswerChecked = false;
  bool? isCorrect;
  Map<String, bool> answers = {}; // questionId -> isCorrect
  
  @override
  void initState() {
    super.initState();
    loadQuestions();
  }
  
  void loadQuestions() {
    questions = widget.topic.questionIds
        .map((id) => quizQuestions[id])
        .whereType<QuizQuestion>()
        .toList();
  }
  
  void checkAnswer() {
    if (selectedAnswer == null || isAnswerChecked) return;
    
    setState(() {
      isAnswerChecked = true;
      isCorrect = selectedAnswer == questions[currentQuestionIndex].correctAnswer;
      answers[questions[currentQuestionIndex].id] = isCorrect!;
    });
  }
  
  void skipQuestion() {
    goToNextQuestion();
  }
  
  void goToNextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        selectedAnswer = null;
        isAnswerChecked = false;
        isCorrect = null;
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
  
  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Вчити по темах'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Text('Немає запитань для цієї теми'),
        ),
      );
    }
    
    final question = questions[currentQuestionIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Вчити по темах'),
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
                  progressProvider.toggleSavedQuestion(questionId);
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Question number pills
          Container(
            height: 50,
            child: ListView.builder(
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
              child: Image.asset(
                question.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => 
                  Center(child: Icon(Icons.broken_image, size: 50)),
              ),
            ),
          
          // Question text
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              question.questionText,
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
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final option = question.options[index];
                bool isSelected = selectedAnswer == option;
                bool showResult = isAnswerChecked;
                bool isCorrectOption = option == question.correctAnswer;
                
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
                    child: Text(
                      option,
                      style: TextStyle(
                        color: showResult && (isSelected || isCorrectOption) 
                            ? Colors.white 
                            : Colors.black,
                      ),
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
                    child: Text(isAnswerChecked ? 'Наступне' : 'Пропустити'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedAnswer == null || isAnswerChecked 
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
                    child: Text('Обрати'),
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
              'Завершити тему',
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
