import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/license_data.dart';
import '../widgets/test_card.dart';
import '../providers/exam_provider.dart';
import '../providers/language_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/practice_provider.dart';
import 'topic_quiz_screen.dart';
import 'saved_items_screen.dart';
import 'exam_question_screen.dart';
import 'practice_question_screen.dart';

class TestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Тести',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Тестування'),
              _buildTestItem(
                context,
                'assets/images/exam.png',
                'Складай іспит',
                'як в СЦ МВС: 40 запитань, 60 хвилин',
                () {
                  // Start a new exam
                  final examProvider = Provider.of<ExamProvider>(context, listen: false);
                  
                  // Get language from provider
                  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
                  final language = languageProvider.language;
                  
                  // Get license type from provider, default to 'driver'
                  final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                  final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
                  
                  // Start new exam with required parameters
                  examProvider.startNewExam(
                    language: language,
                    state: 'IL', // Use 'IL' to match Firebase data structure
                    licenseType: licenseType,
                  );
                  
                  // Navigate to the exam question screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamQuestionScreen(),
                    ),
                  );
                },
              ),
              _buildTestItem(
                context,
                'assets/images/themes.png',
                'Вчи по темах',
                'Запитання згруповані по темах',
                () {
                  // Navigate to themed questions
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TopicQuizScreen(),
                    ),
                  );
                },
              ),
              _buildTestItem(
                context,
                'assets/images/random.png',
                'Тренуйся по білетах',
                '40 випадкових запитань, без обмежень часу',
                () {
                  // Start a new practice test
                  final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
                  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
                  final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                  
                  final language = languageProvider.language;
                  final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
                  
                  // Start new practice with required parameters
                  practiceProvider.startNewPractice(
                    language: language,
                    state: 'IL', // Use 'IL' to match Firebase data structure
                    licenseType: licenseType,
                  ).then((_) {
                    // Navigate to the practice question screen after loading
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PracticeQuestionScreen(),
                      ),
                    );
                  });
                },
              ),
              SizedBox(height: 16),
              _buildSectionHeader('Робота над помилками'),
              _buildTestItem(
                context,
                'assets/images/saved.png',
                'Збережені',
                'Збережені питання з різних розділів',
                () {
                  // Navigate to saved questions
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedItemsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItem(
    BuildContext context,
    String imagePath,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(Icons.description, color: Colors.blue),
                // In a real app, you'd load the actual image:
                // child: Image.asset(imagePath),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
