import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../services/service_locator.dart';
import '../screens/quiz_question_screen.dart';

class TopicQuizScreen extends StatefulWidget {
  @override
  _TopicQuizScreenState createState() => _TopicQuizScreenState();
}

class _TopicQuizScreenState extends State<TopicQuizScreen> with TickerProviderStateMixin {
  List<QuizTopic> topics = [];
  bool isLoading = true;
  String? errorMessage;
  late AnimationController _titleAnimationController;
  late Animation<double> _titlePulseAnimation;
  
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
    
    // Initialize title animation
    _titleAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _titlePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the subtle pulse animation
    _titleAnimationController.repeat(reverse: true);
    
    loadTopics();
  }
  
  @override
  void dispose() {
    _titleAnimationController.dispose();
    super.dispose();
  }

  // Enhanced topic title widget with animation
  Widget _buildEnhancedTopicTitle(String topicTitle) {
    // Choose gradient color based on topic for variety
    Color endColor;
    IconData topicIcon;
    
    // Dynamic theming based on topic content
    if (topicTitle.toLowerCase().contains('загальн') || topicTitle.toLowerCase().contains('general')) {
      endColor = Colors.purple.shade50.withOpacity(0.6);
      topicIcon = Icons.info_outline;
    } else if (topicTitle.toLowerCase().contains('правила') || topicTitle.toLowerCase().contains('rule')) {
      endColor = Colors.blue.shade50.withOpacity(0.6);
      topicIcon = Icons.rule;
    } else if (topicTitle.toLowerCase().contains('безпек') || topicTitle.toLowerCase().contains('safety')) {
      endColor = Colors.green.shade50.withOpacity(0.6);
      topicIcon = Icons.security;
    } else if (topicTitle.toLowerCase().contains('велосипед') || topicTitle.toLowerCase().contains('bike')) {
      endColor = Colors.orange.shade50.withOpacity(0.6);
      topicIcon = Icons.directions_bike;
    } else {
      endColor = Colors.indigo.shade50.withOpacity(0.6);
      topicIcon = Icons.school;
    }
    
    return AnimatedBuilder(
      animation: _titlePulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _titlePulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, endColor],
                stops: [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  topicIcon,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    topicTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method for topic card gradients
  LinearGradient _getTopicCardGradient(int index, String topicTitle) {
    Color startColor = Colors.white;
    Color endColor;
    
    // Cycle through the exact same pastel colors as main test screen cards
    if (topicTitle.toLowerCase().contains('загальн') || topicTitle.toLowerCase().contains('general')) {
      endColor = Colors.purple.shade50.withOpacity(0.4);
    } else if (topicTitle.toLowerCase().contains('правила') || topicTitle.toLowerCase().contains('rule')) {
      endColor = Colors.blue.shade50.withOpacity(0.4);
    } else if (topicTitle.toLowerCase().contains('безпек') || topicTitle.toLowerCase().contains('safety')) {
      endColor = Colors.green.shade50.withOpacity(0.4);
    } else if (topicTitle.toLowerCase().contains('велосипед') || topicTitle.toLowerCase().contains('bike')) {
      endColor = Colors.orange.shade50.withOpacity(0.4);
    } else if (topicTitle.toLowerCase().contains('пішоход') || topicTitle.toLowerCase().contains('pedestrian')) {
      endColor = Colors.teal.shade50.withOpacity(0.4);
    } else if (topicTitle.toLowerCase().contains('транспорт') || topicTitle.toLowerCase().contains('transport')) {
      endColor = Colors.indigo.shade50.withOpacity(0.4);
    } else {
      // Fallback to cycling through colors
      switch (index % 3) {
        case 0:
          endColor = Colors.blue.shade50.withOpacity(0.3);
          break;
        case 1:
          endColor = Colors.green.shade50.withOpacity(0.3);
          break;
        case 2:
          endColor = Colors.orange.shade50.withOpacity(0.3);
          break;
        case 3:
          endColor = Colors.purple.shade50.withOpacity(0.4);
          break;
        default:
          endColor = Colors.blue.shade50.withOpacity(0.4);
      }
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get thematic icon for topics
  IconData _getTopicIcon(String topicTitle) {
    if (topicTitle.toLowerCase().contains('загальн') || topicTitle.toLowerCase().contains('general')) {
      return Icons.info_outline;
    } else if (topicTitle.toLowerCase().contains('правила') || topicTitle.toLowerCase().contains('rule')) {
      return Icons.rule;
    } else if (topicTitle.toLowerCase().contains('безпек') || topicTitle.toLowerCase().contains('safety')) {
      return Icons.security;
    } else if (topicTitle.toLowerCase().contains('велосипед') || topicTitle.toLowerCase().contains('bike')) {
      return Icons.directions_bike;
    } else if (topicTitle.toLowerCase().contains('пішоход') || topicTitle.toLowerCase().contains('pedestrian')) {
      return Icons.directions_walk;
    } else if (topicTitle.toLowerCase().contains('транспорт') || topicTitle.toLowerCase().contains('transport')) {
      return Icons.directions_bus;
    } else if (topicTitle.toLowerCase().contains('водінн') || topicTitle.toLowerCase().contains('driving')) {
      return Icons.drive_eta;
    } else {
      return Icons.quiz;
    }
  }


  // Section header styled exactly like "Тестування" on test screen
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

  // Enhanced topic card widget - NO percentage indicators on individual cards
  Widget _buildEnhancedTopicCard(QuizTopic topic, int index, String currentLanguage) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: _getTopicCardGradient(index, topic.title),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                // Enhanced topic icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.grey.shade100],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getTopicIcon(topic.title),
                      color: Colors.black54,
                      size: 24,
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
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Future<void> loadTopics() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      
      final language = languageProvider.language;
      final state = stateProvider.selectedStateId ?? 'ALL'; // Use actual state ID from provider
      
      print('TopicQuizScreen: Loading topics with language=$language, state=$state');
      
      // Fetch topics from Firebase
      final fetchedTopics = await serviceLocator.content.getQuizTopics(
        language,
        state,
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
    
    // Create enhanced app bar
    final appBar = AppBar(
      title: _buildEnhancedTopicTitle(screenTitle),
      centerTitle: true,
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
          // Section header styled exactly like "Тестування"
          _buildSectionHeader(_getSubtitleText(currentLanguage)),
          
          // Enhanced topic list
          Expanded(
            child: topics.isEmpty 
            ? Container(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.grey.shade50.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.format_list_bulleted,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      _getEmptyStateTitle(currentLanguage),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      _getEmptyStateMessage(currentLanguage),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ) 
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: topics.length,
                itemBuilder: (context, index) {
                  final topic = topics[index];
                  
                  return _buildEnhancedTopicCard(topic, index, currentLanguage);
                },
              ),
          ),
        ],
      ),
    );
  }
}
