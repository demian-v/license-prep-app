import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../models/quiz_progress.dart';
import '../providers/progress_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../services/service_locator.dart';
import '../screens/quiz_question_screen.dart';

class TopicQuizScreen extends StatefulWidget {
  @override
  _TopicQuizScreenState createState() => _TopicQuizScreenState();
}

class _TopicQuizScreenState extends State<TopicQuizScreen> {
  List<QuizTopic> topics = [];
  bool isLoading = true;
  String? errorMessage;
  
  // Helper method to get subtitle text based on language
  String _getSubtitleText(String language) {
    switch (language) {
      case 'en':
        return 'Questions grouped by topics';
      case 'es':
        return 'Preguntas agrupadas por temas';
      case 'uk':
        return 'Запитання згруповані по темах';
      case 'pl':
        return 'Pytania pogrupowane według tematów';
      case 'ru':
        return 'Вопросы сгруппированы по темам';
      default:
        return 'Questions grouped by topics';
    }
  }
  
  // Helper method to get progress card title based on language
  String _getProgressCardTitle(String language) {
    switch (language) {
      case 'en':
        return 'Overall progress by topics:';
      case 'es':
        return 'Progreso general por temas:';
      case 'uk':
        return 'Загальний прогрес по темах:';
      case 'pl':
        return 'Ogólny postęp według tematów:';
      case 'ru':
        return 'Общий прогресс по темам:';
      default:
        return 'Overall progress by topics:';
    }
  }
  
  // Helper method to get questions count text based on language
  String _getQuestionsCountText(String language, int count) {
    switch (language) {
      case 'en':
        return '$count Questions';
      case 'es':
        return '$count Preguntas';
      case 'uk':
        return '$count Запитань';
      case 'pl':
        return '$count Pytań';
      case 'ru':
        return '$count Вопросов';
      default:
        return '$count Questions';
    }
  }
  
  // Helper method to get empty state title
  String _getEmptyStateTitle(String language) {
    switch (language) {
      case 'en':
        return 'No topics available';
      case 'es':
        return 'No hay temas disponibles';
      case 'uk':
        return 'Немає доступних тем';
      case 'pl':
        return 'Brak dostępnych tematów';
      case 'ru':
        return 'Нет доступных тем';
      default:
        return 'No topics available';
    }
  }
  
  // Helper method to get empty state message
  String _getEmptyStateMessage(String language) {
    switch (language) {
      case 'en':
        return 'There are currently no topics available for the selected language';
      case 'es':
        return 'Actualmente no hay temas disponibles para el idioma seleccionado';
      case 'uk':
        return 'На даний момент немає доступних тем для вибраної мови';
      case 'pl':
        return 'Obecnie nie ma dostępnych tematów dla wybranego języka';
      case 'ru':
        return 'В настоящее время нет доступных тем для выбранного языка';
      default:
        return 'There are currently no topics available for the selected language';
    }
  }
  
  // Helper method to get try again button text
  String _getTryAgainText(String language) {
    switch (language) {
      case 'en':
        return 'Try Again';
      case 'es':
        return 'Intentar de nuevo';
      case 'uk':
        return 'Повторити спробу';
      case 'pl':
        return 'Spróbuj ponownie';
      case 'ru':
        return 'Попробовать снова';
      default:
        return 'Try Again';
    }
  }
  
  @override
  void initState() {
    super.initState();
    loadTopics();
  }
  
  Future<void> loadTopics() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      
      final language = languageProvider.language;
      final state = stateProvider.selectedStateId ?? 'ALL'; // Use actual state ID from provider
      
      print('TopicQuizScreen: Loading topics with language=$language, state=$state');
      
      // Get license type 
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      
      // Fetch topics from Firebase
      final fetchedTopics = await serviceLocator.content.getQuizTopics(
        licenseType,
        language,
        state
      );
      
      if (mounted) {
        setState(() {
          topics = fetchedTopics;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quiz topics: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load topics. Please try again.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final topicProgress = progressProvider.progress.topicProgress;
    final overallProgress = progressProvider.progress.overallTopicProgress;
    
    // Get current language
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.language;
    
    // Title based on language
    String screenTitle = '';
    switch (currentLanguage) {
      case 'en':
        screenTitle = 'Learn by Topics';
        break;
      case 'es':
        screenTitle = 'Aprender por Temas';
        break;
      case 'uk':
        screenTitle = 'Вчити по темах';
        break;
      case 'pl':
        screenTitle = 'Ucz się według tematów';
        break;
      case 'ru':
        screenTitle = 'Учиться по темам';
        break;
      default:
        screenTitle = 'Learn by Topics';
    }
    
    // Create app bar
    final appBar = AppBar(
      title: Text(screenTitle),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    );
    
    // Show loading state
    if (isLoading) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show error state
    if (errorMessage != null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadTopics,
                child: Text(_getTryAgainText(currentLanguage)),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              _getSubtitleText(currentLanguage),
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
                    _getProgressCardTitle(currentLanguage),
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
            child: topics.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.format_list_bulleted,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      _getEmptyStateTitle(currentLanguage),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _getEmptyStateMessage(currentLanguage),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ) 
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  final topic = topics[index];
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
                                  _getQuestionsCountText(currentLanguage, topic.questionCount),
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
