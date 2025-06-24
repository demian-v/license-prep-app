import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/license_data.dart';
import '../widgets/enhanced_test_card.dart';
import '../providers/exam_provider.dart';
import '../providers/language_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/practice_provider.dart';
import 'topic_quiz_screen.dart';
import 'saved_items_screen.dart';
import 'exam_question_screen.dart';
import 'practice_question_screen.dart';
import '../localization/app_localizations.dart';

class TestScreen extends StatelessWidget {
  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language based on the language provider
      switch (languageProvider.language) {
        case 'es':
          return {
            'tests': 'Pruebas',
            'testing': 'Pruebas',
            'take_exam': 'Realizar examen',
            'dmv_exam_desc': 'como en el DMV: 40 preguntas, 60 minutos',
            'working_on_mistakes': 'Trabajando en errores',
            'saved': 'Guardado',
            'saved_questions_desc': 'Preguntas guardadas de diferentes secciones',
            'learn_by_topics': 'Aprender por Temas',
            'questions_by_topics': 'Preguntas por Temas',
            'practice_tickets': 'Boletos de Práctica',
            'random_questions_no_limit': 'Preguntas aleatorias, sin límite',
            'time_60_minutes': '60 minutos',
            'questions_40': '40 preguntas',
            'time_unlimited': 'Tiempo ilimitado',
            'questions_100_sorted': '100+ preguntas por temas',
          }[key] ?? key;
        case 'uk':
          return {
            'tests': 'Тести',
            'testing': 'Тестування',
            'take_exam': 'Складай іспит',
            'dmv_exam_desc': 'як в СЦ МВС: 40 запитань, 60 хвилин',
            'working_on_mistakes': 'Робота над помилками',
            'saved': 'Збережені',
            'saved_questions_desc': 'Збережені питання з різних розділів',
            'learn_by_topics': 'Навчання за темами',
            'questions_by_topics': 'Питання за темами',
            'practice_tickets': 'Практичні білети',
            'random_questions_no_limit': 'Випадкові питання, без обмежень',
            'time_60_minutes': '60 хвилин',
            'questions_40': '40 запитань',
            'time_unlimited': 'Необмежений час',
            'questions_100_sorted': '100+ запитань за темами',
          }[key] ?? key;
        case 'ru':
          return {
            'tests': 'Тесты',
            'testing': 'Тестирование',
            'take_exam': 'Сдать экзамен',
            'dmv_exam_desc': 'как в ГАИ: 40 вопросов, 60 минут',
            'working_on_mistakes': 'Работа над ошибками',
            'saved': 'Сохраненные',
            'saved_questions_desc': 'Сохраненные вопросы из разных разделов',
            'learn_by_topics': 'Обучение по темам',
            'questions_by_topics': 'Вопросы по темам',
            'practice_tickets': 'Практические билеты',
            'random_questions_no_limit': 'Случайные вопросы, без ограничений',
            'time_60_minutes': '60 минут',
            'questions_40': '40 вопросов',
            'time_unlimited': 'Неограниченное время',
            'questions_100_sorted': '100+ вопросов по темам',
          }[key] ?? key;
        case 'pl':
          return {
            'tests': 'Testy',
            'testing': 'Testowanie',
            'take_exam': 'Zdaj egzamin',
            'dmv_exam_desc': 'jak w urzędzie komunikacji: 40 pytań, 60 minut',
            'working_on_mistakes': 'Praca nad błędami',
            'saved': 'Zapisane',
            'saved_questions_desc': 'Zapisane pytania z różnych sekcji',
            'learn_by_topics': 'Nauka według tematów',
            'questions_by_topics': 'Pytania według tematów',
            'practice_tickets': 'Bilety praktyczne',
            'random_questions_no_limit': 'Losowe pytania, bez limitu',
            'time_60_minutes': '60 minut',
            'questions_40': '40 pytań',
            'time_unlimited': 'Nieograniczony czas',
            'questions_100_sorted': '100+ pytań według tematów',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'tests': 'Tests',
            'testing': 'Testing',
            'take_exam': 'Take Exam',
            'dmv_exam_desc': 'like in DMV: 40 questions, 60 minutes',
            'working_on_mistakes': 'Working on Mistakes',
            'saved': 'Saved',
            'saved_questions_desc': 'Saved questions from different sections',
            'learn_by_topics': 'Learn by Topics',
            'questions_by_topics': 'Questions by Topics',
            'practice_tickets': 'Practice Tickets',
            'random_questions_no_limit': 'Random questions, no limit',
            'time_60_minutes': '60 minutes',
            'questions_40': '40 questions',
            'time_unlimited': 'Unlimited time',
            'questions_100_sorted': '100+ questions sorted by topics',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [TEST SCREEN] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('🧪 [TEST SCREEN] Building with language: ${languageProvider.language}');
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _translate('tests', languageProvider),
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
                  _buildSectionHeader(_translate('testing', languageProvider)),
                  // Take Exam card with left and right info
                  _buildTestItem(
                    context,
                    'assets/images/exam.png',
                    _translate('take_exam', languageProvider),
                    _translate('dmv_exam_desc', languageProvider),
                    () {
                      // Start a new exam
                      final examProvider = Provider.of<ExamProvider>(context, listen: false);
                      
                      // Get language from provider
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
                    leftInfoText: _translate('time_60_minutes', languageProvider),
                    rightInfoText: _translate('questions_40', languageProvider),
                    cardType: 0,
                  ),
                  // Learn by Topics card with left and right info
                  _buildTestItem(
                    context,
                    'assets/images/themes.png',
                    _translate('learn_by_topics', languageProvider),
                    _translate('questions_by_topics', languageProvider),
                    () {
                      // Navigate to themed questions
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TopicQuizScreen(),
                        ),
                      );
                    },
                    leftInfoText: _translate('time_unlimited', languageProvider),
                    rightInfoText: _translate('questions_100_sorted', languageProvider),
                    cardType: 1,
                  ),
                  // Practice Tickets card with left and right info
                  _buildTestItem(
                    context,
                    'assets/images/random.png',
                    _translate('practice_tickets', languageProvider),
                    _translate('random_questions_no_limit', languageProvider),
                    () {
                      // Start a new practice test
                      final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
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
                    leftInfoText: _translate('time_unlimited', languageProvider),
                    rightInfoText: _translate('questions_40', languageProvider),
                    cardType: 2,
                  ),
                  SizedBox(height: 16),
                  _buildSectionHeader(_translate('working_on_mistakes', languageProvider)),
                  // Saved card with no info text
                  _buildTestItem(
                    context,
                    'assets/images/saved.png',
                    _translate('saved', languageProvider),
                    _translate('saved_questions_desc', languageProvider),
                    () {
                      // Navigate to saved questions
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SavedItemsScreen(),
                        ),
                      );
                    },
                    cardType: 3,
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    VoidCallback onTap, {
    String? leftInfoText,
    String? rightInfoText,
    int cardType = 0,
  }) {
    return EnhancedTestCard(
      title: title,
      description: subtitle,
      icon: Icons.description, // Using the same icon for all cards for consistency
      leftInfoText: leftInfoText,
      rightInfoText: rightInfoText,
      cardType: cardType,
      onTap: onTap,
    );
  }
}
