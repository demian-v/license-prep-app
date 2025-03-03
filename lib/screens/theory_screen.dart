import 'package:flutter/material.dart';
import '../data/license_data.dart';
import 'traffic_rules_topics_screen.dart';

class TheoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Правила Дорожнього Руху',
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
              Text(
                'Теоретичний курс майбутнього водія',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              _buildTheoryItem(
                context,
                'assets/images/rules.png',
                'Правила дорожнього руху',
                '',
                () {
                  // Navigate to traffic rules
                  Navigator.push(
                    context,
                   MaterialPageRoute(
                     builder: (context) => TrafficRulesTopicsScreen(),
                   ),
                 );
                },
              ),
              _buildTheoryItem(
                context,
                'assets/images/signs.png',
                'Знаки',
                '',
                () {
                  // Navigate to road signs
                },
              ),
              _buildTheoryItem(
                context,
                'assets/images/markings.png',
                'Дорожня розмітка',
                '',
                () {
                  // Navigate to road markings
                },
              ),
              _buildTheoryItem(
                context,
                'assets/images/controller.png',
                'Регулювальник',
                '',
                () {
                  // Navigate to traffic controller
                },
              ),
              _buildTheoryItem(
                context,
                'assets/images/lights.png',
                'Світлофор',
                '',
                () {
                  // Navigate to traffic lights
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTheoryItem(
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
                child: Icon(
                  title == 'Лекції з ПДР' ? Icons.play_circle : 
                  title == 'Знаки' ? Icons.warning : 
                  title == 'Дорожня розмітка' ? Icons.edit_road : 
                  title == 'Регулювальник' ? Icons.person : 
                  title == 'Світлофор' ? Icons.traffic : 
                  Icons.menu_book,
                  color: Colors.blue,
                ),
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
                    if (subtitle.isNotEmpty) SizedBox(height: 4),
                    if (subtitle.isNotEmpty)
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