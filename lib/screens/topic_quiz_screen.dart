import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quiz_data.dart';
import '../models/quiz_progress.dart';
import '../providers/progress_provider.dart';
import '../screens/quiz_question_screen.dart';

class TopicQuizScreen extends StatefulWidget {
  @override
  _TopicQuizScreenState createState() => _TopicQuizScreenState();
}

class _TopicQuizScreenState extends State<TopicQuizScreen> {

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final topicProgress = progressProvider.progress.topicProgress;
    final overallProgress = progressProvider.progress.overallTopicProgress;
    
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
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Запитання згруповані по темах',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Progress card
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Загальний прогрес по темах:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: overallProgress,
                          backgroundColor: Colors.red[50],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        '${(overallProgress * 100).round()}%',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Topic list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: quizTopics.length,
              itemBuilder: (context, index) {
                final topic = quizTopics[index];
                final progress = topicProgress[topic.id] ?? 0.0;
                
                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizQuestionScreen(topic: topic),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[300],
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${topic.questionCount} Запитань',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Container(
                            width: 50,
                            child: Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
