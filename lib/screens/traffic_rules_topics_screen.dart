import 'package:flutter/material.dart';
import '../models/traffic_rule_topic.dart';
import 'traffic_rule_content_screen.dart';

class TrafficRulesTopicsScreen extends StatelessWidget {
  final List<TrafficRuleTopic> topics = [
    TrafficRuleTopic(
      id: '1',
      title: 'Загальні положення',
      content: '''
1.1 Ці Правила відповідно до Закону України «Про дорожній рух» встановлюють єдиний порядок дорожнього руху на всій території України.

Інші нормативні акти, що стосуються особливостей дорожнього руху (перевезення спеціальних вантажів, експлуатація транспортних засобів окремих видів, рух на закритій території тощо), повинні ґрунтуватися на вимогах цих Правил.

1.2 В Україні встановлено правосторонній рух транспортних засобів.
      ''',
    ),
    TrafficRuleTopic(
      id: '2',
      title: 'Обов\'язки і права водіїв механічних транспортних засобів',
      content: '''
2.1 Водій механічного транспортного засобу повинен мати при собі:

а) посвідчення водія на право керування транспортним засобом відповідної категорії;

б) реєстраційний документ на транспортний засіб (для транспортних засобів Збройних Сил, Національної Гвардії, Держприкордонслужби, Держспецтрансслужби, Держспецзв'язку, Оперативно-рятувальної служби цивільного захисту — технічний талон);

в) у разі встановлення на транспортних засобах проблискових маячків та (або) спеціальних звукових сигнальних пристроїв — дозвіл, виданий уповноваженим органом МВС, а у разі встановлення проблискового маячка оранжевого кольору на великогабаритних та великовагових транспортних засобах — дозвіл, виданий уповноваженим підрозділом Національної поліції, крім випадків встановлення проблискових маячків оранжевого кольору на транспортних засобах дорожньо-експлуатаційної служби.
      ''',
    ),
    TrafficRuleTopic(
      id: '3',
      title: 'Рух транспортних засобів із спеціальними сигналами',
      content: 'Зміст розділу про рух транспортних засобів із спеціальними сигналами...',
    ),
    TrafficRuleTopic(
      id: '4',
      title: 'Обов\'язки і права пішоходів',
      content: 'Зміст розділу про обов\'язки і права пішоходів...',
    ),
    TrafficRuleTopic(
      id: '5',
      title: 'Обов\'язки і права пасажирів',
      content: 'Зміст розділу про обов\'язки і права пасажирів...',
    ),
    TrafficRuleTopic(
      id: '6',
      title: 'Вимоги до велосипедистів',
      content: 'Зміст розділу про вимоги до велосипедистів...',
    ),
    TrafficRuleTopic(
      id: '7',
      title: 'Вимоги до осіб, які керують гужовим транспортом, і погоничам тварин',
      content: 'Зміст розділу про вимоги до осіб, які керують гужовим транспортом, і погоничам тварин...',
    ),
    TrafficRuleTopic(
      id: '8',
      title: 'Регулювання дорожнього руху',
      content: 'Зміст розділу про регулювання дорожнього руху...',
    ),
  ];

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
          onPressed: () => Navigator.pop(context),
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
      body: ListView.builder(
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
                    builder: (context) => TrafficRuleContentScreen(topic: topic),
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
                        '${index + 1}',
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
      ),
    );
  }
}