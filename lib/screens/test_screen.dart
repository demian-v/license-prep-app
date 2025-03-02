import 'package:flutter/material.dart';
import '../data/license_data.dart';
import '../widgets/test_card.dart';

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
                'як в СЦ МВС: 20 запитань, 20 хвилин',
                () {
                  // Navigate to the exam simulation
                },
              ),
              _buildTestItem(
                context,
                'assets/images/themes.png',
                'Вчи по темах',
                'Запитання згруповані по темах',
                () {
                  // Navigate to themed questions
                },
              ),
              _buildTestItem(
                context,
                'assets/images/random.png',
                'Тренуйся по білетах',
                '20 випадкових запитань, без обмежень',
                () {
                  // Navigate to random questions
                },
              ),
              SizedBox(height: 16),
              _buildSectionHeader('Робота над помилками'),
              _buildTestItem(
                context,
                'assets/images/mistakes.png',
                'Мої помилки',
                'Запитання, де були допущені помилки',
                () {
                  // Navigate to mistakes section
                },
              ),
              _buildTestItem(
                context,
                'assets/images/frequent.png',
                'Часті помилки',
                '100 найбільш складних запитань в іспиті',
                () {
                  // Navigate to frequent mistakes
                },
              ),
              _buildTestItem(
                context,
                'assets/images/saved.png',
                'Збережені',
                'Збережені питання з різних розділів',
                () {
                  // Navigate to saved questions
                },
              ),
              SizedBox(height: 16),
              _buildSectionHeader('Відео'),
              _buildTestItem(
                context,
                'assets/images/video.png',
                '👉 Лекції з ПДР 👈',
                'Відеолекції з різних розділів ПДР',
                () {
                  // Navigate to video lectures
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