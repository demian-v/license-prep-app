import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exam_provider.dart';
import '../providers/language_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/enhanced_test_card.dart';
import 'exam_question_screen.dart';
import '../localization/app_localizations.dart';
import '../theme/solar_icons.dart';

class ExamScreen extends StatelessWidget {
  // Method to start exam flow
  void _startExamFlow(
    BuildContext context, 
    LanguageProvider languageProvider,
  ) {
    // Get providers for exam start
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final examProvider = Provider.of<ExamProvider>(context, listen: false);
    
    // Get exam parameters
    final language = languageProvider.language;
    final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
    final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
    
    // Start new exam with required parameters
    examProvider.startNewExam(
      language: language,
      state: state,
      licenseType: licenseType,
    );
    
    // Navigate to the exam question screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamQuestionScreen(),
      ),
    );
  }

  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language based on the language provider
      switch (languageProvider.language) {
        case 'es':
          return {
            'take_exam': 'Realizar examen',
            'dmv_exam_desc': 'como en el DMV: 40 preguntas, 60 minutos',
            'exam_header': 'Examen',
          }[key] ?? key;
        case 'uk':
          return {
            'take_exam': 'Складай іспит',
            'dmv_exam_desc': 'як в СЦ МВС: 40 запитань, 60 хвилин',
            'exam_header': 'Іспит',
          }[key] ?? key;
        case 'ru':
          return {
            'take_exam': 'Сдать экзамен',
            'dmv_exam_desc': 'как в ГАИ: 40 вопросов, 60 минут',
            'exam_header': 'Экзамен',
          }[key] ?? key;
        case 'pl':
          return {
            'take_exam': 'Zdaj egzamin',
            'dmv_exam_desc': 'jak w urzędzie komunikacji: 40 pytań, 60 minut',
            'exam_header': 'Egzamin',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'take_exam': 'Take Exam',
            'dmv_exam_desc': 'like in DMV: 40 questions, 60 minutes',
            'exam_header': 'Exam',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [EXAM SCREEN] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('📝 [EXAM SCREEN] Building with language: ${languageProvider.language}');
        
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _translate('exam_header', languageProvider),
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
                  // Take Exam card with left and right info
                  _buildExamCard(
                    context,
                    _translate('take_exam', languageProvider),
                    _translate('dmv_exam_desc', languageProvider),
                    () {
                      // Start exam flow
                      _startExamFlow(context, languageProvider);
                    },
                    leftInfoText: "60 minutes",
                    rightInfoText: "40 questions",
                    cardType: 0,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExamCard(
    BuildContext context,
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
      icon: SolarIcons.documentTextBold, // Using the same icon for consistency
      leftInfoText: leftInfoText,
      rightInfoText: rightInfoText,
      cardType: cardType,
      onTap: onTap,
    );
  }
}
