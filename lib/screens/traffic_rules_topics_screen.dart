import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/traffic_rule_topic.dart';
import '../providers/content_provider.dart';
import '../providers/language_provider.dart';
import 'traffic_rule_content_screen.dart';

class TrafficRulesTopicsScreen extends StatefulWidget {
  @override
  _TrafficRulesTopicsScreenState createState() => _TrafficRulesTopicsScreenState();
}

class _TrafficRulesTopicsScreenState extends State<TrafficRulesTopicsScreen> {
  // Legacy hardcoded topics - will be used as fallback if Firestore fails
  final List<TrafficRuleTopic> _hardcodedTopics = [
    // All the hardcoded topics can remain here as fallback
    // They'll be used if Firestore fetch fails
    TrafficRuleTopic(
      id: '1',
      title: 'Загальні положення',
      content: '1. ЗАГАЛЬНІ ПОЛОЖЕННЯ\n\n'
          '1.1 Водійське посвідчення в Іллінойсі\n\n'
          'Водійське посвідчення — це ваш дозвіл на керування транспортним засобом. У штаті Іллінойс посвідчення класифікується за типом транспортного засобу на основі повної ваги автомобіля. Базове посвідчення для керування легковим автомобілем у штаті Іллінойс відноситься до класу D.\n\n'
          '1.2 Вікові обмеження\n\n'
          '• Ви повинні бути не молодше 16 років для отримання посвідчення водія в Іллінойсі.\n\n'
          '• Якщо вам 16-17 років, ви можете отримати посвідчення тільки після успішного завершення схваленого штатом курсу навчання водіїв, 50 годин практичного водіння та складання іспитів.\n\n'
          '• Для осіб віком 18-20 років, які раніше не мали посвідчення, необхідно пройти 6-годинний курс навчання дорослих водіїв.\n\n'
          '• Водії молодше 18 років не можуть керувати комерційними транспортними засобами.\n\n'
          '• Водії молодше 21 року не можуть керувати транспортними засобами, що перевозять більше 10 пасажирів, автобусами релігійних організацій, шкільними автобусами чи транспортом для перевезення людей похилого віку.\n\n'
          '1.3 Процес отримання посвідчення\n\n'
          'Для отримання водійського посвідчення необхідно:\n\n'
          '• Пройти перевірку зору\n\n'
          '• Скласти письмовий іспит\n\n'
          '• Скласти практичний іспит з водіння\n\n'
          '• Подати необхідні документи, що засвідчують особу\n\n'
          '• Сплатити відповідні збори\n\n'
          '1.4 Типи документів ідентифікації\n\n'
          'З 2025 року для внутрішніх авіаперельотів потрібне водійське посвідчення або ID-картка, що відповідає вимогам REAL ID. Щоб отримати REAL ID, потрібно надати:\n\n'
          '• Підтвердження особи (наприклад, свідоцтво про народження або дійсний паспорт США)\n\n'
          '• Підтвердження номера соціального страхування\n\n'
          '• Підтвердження поточного місця проживання (два документи)\n\n'
          '• Підтвердження підпису',
    ),
    // ... other hardcoded topics
  ];

  @override
  void initState() {
    super.initState();
    // Fetch data when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      
      // Set current language and fetch content if needed
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: 'IL', // This could come from user preferences
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Правила дорожнього руху',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Instead of popping, navigate to the home screen
            // This ensures we have a proper screen to go back to
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // Search functionality
            },
          ),
        ],
      ),
      body: Consumer<ContentProvider>(
        builder: (context, contentProvider, child) {
          if (contentProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
          
          // Use either topics from Firestore or fallback to hardcoded if empty
          final topics = contentProvider.topics.isNotEmpty 
              ? contentProvider.topics 
              : _hardcodedTopics;
          
          if (topics.isEmpty) {
            return Center(
              child: Text('No topics available'),
            );
          }
          
          return ListView.builder(
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return TrafficRuleContentScreen(topic: topic);
                        },
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            topic.order.toString(),
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            topic.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
