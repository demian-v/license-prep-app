import 'package:flutter/material.dart';
import '../models/quiz_topic.dart';

class QuizResultScreen extends StatelessWidget {
  final QuizTopic topic;
  final Map<String, bool> answers;
  
  const QuizResultScreen({
    Key? key,
    required this.topic,
    required this.answers,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    int totalAnswered = answers.length;
    int correctAnswers = answers.values.where((v) => v).length;
    int incorrectAnswers = totalAnswered - correctAnswers;
    
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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              topic.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Trophy image and stats
          Container(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.yellow,
                    size: 80,
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildResultStat(
                      correctAnswers.toString(),
                      'Вірних відповідей',
                      Colors.green,
                    ),
                    _buildResultStat(
                      incorrectAnswers.toString(),
                      'Невірних відповідей',
                      Colors.red,
                    ),
                    _buildResultStat(
                      totalAnswered.toString(),
                      'Запитань пройдено',
                      Colors.black,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Navigate to mistakes review
                },
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Мої помилки',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  // Navigate to next topic
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Наступна тема',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}