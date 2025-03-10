import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/practice_provider.dart';
import 'practice_question_screen.dart';

class PracticeResultScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context);
    final practice = practiceProvider.currentPractice;
    
    if (practice == null) {
      // If no practice data, navigate back to test screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
      
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final correctAnswers = practice.correctAnswersCount;
    final totalAnswered = practice.answeredQuestionsCount;
    final incorrectAnswers = practice.incorrectAnswersCount;
    final isPassed = practice.isPassed;
    
    // Format elapsed time
    final elapsedTime = practice.elapsedTime;
    final minutes = elapsedTime.inMinutes;
    final seconds = elapsedTime.inSeconds % 60;
    final timeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Результат'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Return to test screen
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            // Reset practice
            practiceProvider.cancelPractice();
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result display with icon
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trophy or fail symbol
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isPassed ? Colors.green : Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassed ? Icons.emoji_events : Icons.block,
                    color: isPassed ? Colors.yellow : Colors.red,
                    size: 80,
                  ),
                ),
                SizedBox(height: 32),
                
                // Stats display
                Card(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
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
                              timeText,
                              'Час проходження',
                              Colors.black,
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text(
                          isPassed ? 'Тест складено' : 'Тест не складено',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isPassed ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // Show mistakes (could navigate to a dedicated screen)
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.red[50],
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
                
                SizedBox(height: 8),
                
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // Reset and start a new practice
                      practiceProvider.cancelPractice();
                      practiceProvider.startNewPractice();
                      
                      // Navigate to practice screen
                      Navigator.of(context).popUntil((route) => route.isFirst);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PracticeQuestionScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.assignment,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            'Наступний білет',
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
              ],
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
