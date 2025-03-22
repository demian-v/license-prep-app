import '../../models/quiz_topic.dart';
import '../../models/quiz_question.dart';
import '../../models/road_sign_category.dart';
import '../../models/road_sign.dart';
import '../../models/theory_module.dart';
import '../../models/practice_test.dart';
import '../../models/traffic_light_info.dart';
import 'firebase_functions_client.dart';
import 'base/content_api_interface.dart';

/// Helper method to parse question type from string
QuestionType _parseQuestionType(String type) {
  switch (type.toLowerCase()) {
    case 'truefalse':
      return QuestionType.trueFalse;
    case 'multiplechoice':
      return QuestionType.multipleChoice;
    default:
      return QuestionType.singleChoice;
  }
}

class FirebaseContentApi implements ContentApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  
  FirebaseContentApi(this._functionsClient);
  
  /// Get quiz topics based on license type, language, and state
  Future<List<QuizTopic>> getQuizTopics(String licenseType, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      print('Fetching quiz topics with: licenseType=$licenseType, language=$language, state=$state');
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizTopics',
        data: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      // Debug output
      print('Received response: $response');
      
      if (response == null || response.isEmpty) {
        print('Response was empty, returning fallback data');
        // Return hardcoded sample data for testing
        return [
          QuizTopic(
            id: 'q_topic_il_ua_01',
            title: 'ЗАГАЛЬНІ ПОЛОЖЕННЯ',
            questionCount: 15,
            progress: 0.0,
            questionIds: [
              'q_il_ua_general_01',
              'q_il_ua_general_02',
              'q_il_ua_general_03',
            ],
          ),
        ];
      }
      
      return response.map((item) {
        try {
          // Handle different possible types coming from Firebase Functions
          final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
          // Convert to Map<String, dynamic>
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ));
          
          print('Processing topic: ${data['id']} - ${data['title']}');
          
          // Safe extraction of questionIds
          List<String> questionIds = [];
          if (data['questionIds'] != null) {
            if (data['questionIds'] is List) {
              questionIds = (data['questionIds'] as List)
                  .map((item) => item?.toString() ?? "")
                  .where((item) => item.trim().isNotEmpty)
                  .toList();
            }
          }
          
          return QuizTopic(
            id: data['id'].toString(),
            title: data['title'].toString(),
            questionCount: data['questionCount'] is int 
              ? data['questionCount'] as int 
              : int.tryParse(data['questionCount'].toString()) ?? 0,
            progress: data['progress'] != null ? 
              (data['progress'] is num ? 
                (data['progress'] as num).toDouble() : 
                double.tryParse(data['progress'].toString()) ?? 0.0) : 
              0.0,
            questionIds: questionIds,
          );
        } catch (e) {
          print('Error processing topic: $e');
          print('Raw item: $item');
          // Return null and filter out later
          return null;
        }
      })
      .where((topic) => topic != null) // Filter out null topics
      .cast<QuizTopic>() // Cast non-null topics
      .toList();
    } catch (e) {
      print('Error fetching quiz topics: $e');
      print('Returning fallback data');
      
      // Return hardcoded sample data if Firebase call fails
      return [
        QuizTopic(
          id: 'q_topic_il_ua_01',
          title: 'ЗАГАЛЬНІ ПОЛОЖЕННЯ',
          questionCount: 15,
          progress: 0.0,
          questionIds: [
            'q_il_ua_general_01',
            'q_il_ua_general_02',
            'q_il_ua_general_03',
          ],
        ),
      ];
    }
  }
  
  /// Get quiz questions based on topic ID, language, and state
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      print('Fetching quiz questions with: topicId=$topicId, language=$language, state=$state');
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizQuestions',
        data: {
          'topicId': topicId,
          'language': language,
          'state': state,
        },
      );
      
      // Debug output
      print('Received questions response: $response');
      
      if (response == null || response.isEmpty) {
        print('Questions response was empty, returning fallback data');
        // Return hardcoded sample data for testing
        return [
          QuizQuestion(
            id: 'q_il_ua_general_01',
            topicId: topicId,
            questionText: 'Чи належить до проїзної частини велосипедна смуга?',
            options: ['Так, належить.', 'Ні, не належить.'],
            correctAnswer: 'Смуга руху',
            explanation: 'Смуга руху — це поздовжня смуга на проїзній частині завширшки щонайменше 2,75 м, що позначена або не позначена дорожньою розміткою і призначена для руху нерейкових транспортних засобів.',
            ruleReference: 'Загальні положення - Визначення',
            imagePath: 'assets/images/section1/lane_marking.png',
            type: QuestionType.singleChoice,
          ),
          QuizQuestion(
            id: 'q_il_ua_general_02',
            topicId: topicId,
            questionText: 'Що таке "розділювальна смуга"?',
            options: ['Розділює зустрічні потоки транспорту', 'Відокремлює пішохідну частину', 'Визначає межі стоянки'],
            correctAnswer: 'Розділює зустрічні потоки транспорту',
            explanation: 'Розділювальна смуга — відокремлює проїзні частини дороги на самостійні проїзди і (або) відокремлює проїзну частину дороги від трамвайної колії.',
            ruleReference: 'Загальні положення - Визначення',
            type: QuestionType.singleChoice,
          ),
        ];
      }
      
      return response.map((item) {
        try {
          // Handle different possible types coming from Firebase Functions
          final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
          // Convert to Map<String, dynamic>
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ));
          
          print('Processing question: ${data['id']}');
          
          // Safe extraction of options
          List<String> options = [];
          if (data['options'] != null) {
            if (data['options'] is List) {
              options = (data['options'] as List)
                  .map((item) => item?.toString() ?? "")
                  .where((item) => item.isNotEmpty)
                  .toList();
            }
          }
          
          // Extract the correct answer value - checking multiple possible field names
          // This handles the case where correct answer is stored in correctAnswerString
          var correctAnswer = "";
          if (data.containsKey('correctAnswer') && data['correctAnswer'] != null) {
            correctAnswer = data['correctAnswer'].toString();
          } else if (data.containsKey('correctAnswerString') && data['correctAnswerString'] != null) {
            correctAnswer = data['correctAnswerString'].toString();
          }
          
          print('Question ID: ${data['id']}, Correct Answer: $correctAnswer');
          
          return QuizQuestion(
            id: data['id'].toString(),
            topicId: data['topicId'].toString(),
            questionText: data['questionText'].toString(),
            options: options,
            correctAnswer: correctAnswer,
            explanation: data['explanation']?.toString(),
            ruleReference: data['ruleReference']?.toString(),
            imagePath: data['imagePath']?.toString(),
            type: data['type'] != null ? 
              _parseQuestionType(data['type'].toString()) : 
              QuestionType.singleChoice,
          );
        } catch (e) {
          print('Error processing question: $e');
          print('Raw item: $item');
          // Return null and filter out later
          return null;
        }
      })
      .where((question) => question != null) // Filter out null questions
      .cast<QuizQuestion>() // Cast non-null questions
      .toList();
    } catch (e) {
      print('Error fetching quiz questions: $e');
      print('Returning fallback question data');
      
      // Return hardcoded sample data if Firebase call fails
      return [
        QuizQuestion(
          id: 'q_il_ua_general_01',
          topicId: topicId,
          questionText: 'Чи належить до проїзної частини велосипедна смуга?',
          options: ['Так, належить.', 'Ні, не належить.'],
          correctAnswer: 'Смуга руху',
          explanation: 'Смуга руху — це поздовжня смуга на проїзній частині завширшки щонайменше 2,75 м, що позначена або не позначена дорожньою розміткою і призначена для руху нерейкових транспортних засобів.',
          ruleReference: 'Загальні положення - Визначення',
          imagePath: 'assets/images/section1/lane_marking.png',
          type: QuestionType.singleChoice,
        ),
        QuizQuestion(
          id: 'q_il_ua_general_02',
          topicId: topicId,
          questionText: 'Що таке "розділювальна смуга"?',
          options: ['Розділює зустрічні потоки транспорту', 'Відокремлює пішохідну частину', 'Визначає межі стоянки'],
          correctAnswer: 'Розділює зустрічні потоки транспорту',
          explanation: 'Розділювальна смуга — відокремлює проїзні частини дороги на самостійні проїзди і (або) відокремлює проїзну частину дороги від трамвайної колії.',
          ruleReference: 'Загальні положення - Визначення',
          type: QuestionType.singleChoice,
        ),
      ];
    }
  }
  
  /// Get road sign categories for a specific language
  Future<List<RoadSignCategory>> getRoadSignCategories(String language) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getRoadSignCategories',
        data: {
          'language': language,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        // For API response, we might not get all the road signs upfront
        // We'll create an empty list and let another API call populate it
        return RoadSignCategory(
          id: data['id'] as String,
          title: data['name'] as String, // name in API -> title in model
          iconUrl: data['iconPath'] ?? '', // iconPath in API -> iconUrl in model
          description: data['description'] as String,
          signs: [], // Initialize with empty list, to be populated later
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch road sign categories: $e';
    }
  }
  
  /// Get road signs for a specific category and language
  Future<List<RoadSign>> getRoadSigns(String categoryId, String language) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getRoadSigns',
        data: {
          'categoryId': categoryId,
          'language': language,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        return RoadSign(
          id: data['id'] as String,
          name: data['name'] as String,
          signCode: data['code'] ?? '', // code in API -> signCode in model
          imageUrl: data['imagePath'] ?? '', // imagePath in API -> imageUrl in model
          description: data['description'] as String,
          installationGuidelines: data['rules'] ?? '', // rules in API -> installationGuidelines in model
          exampleImageUrl: data['exampleImagePath'], // Optional field
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch road signs: $e';
    }
  }
  
  /// Get theory modules based on license type, language, and state
  Future<List<TheoryModule>> getTheoryModules(String licenseType, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getTheoryModules',
        data: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        return TheoryModule(
          id: data['id'] as String,
          licenseId: data['licenseId'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          estimatedTime: data['estimatedTime'] as int? ?? 30, // Default to 30 minutes if not provided
          topics: List<String>.from(data['topics'] ?? []),
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch theory modules: $e';
    }
  }
  
  /// Get practice tests based on license type, language, and state
  Future<List<PracticeTest>> getPracticeTests(String licenseType, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getPracticeTests',
        data: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        return PracticeTest(
          id: data['id'] as String,
          licenseId: data['licenseId'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          questions: data['questionCount'] as int, // questionCount in API -> questions in model
          timeLimit: data['duration'] as int, // duration in API -> timeLimit in model
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch practice tests: $e';
    }
  }
  
  /// Get traffic light information for a specific language
  Future<TrafficLightInfo> getTrafficLightInfo(String language) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getTrafficLightInfo',
        data: {
          'language': language,
        },
      );
      
      return TrafficLightInfo(
        id: response['id'] as String,
        title: response['title'] as String,
        content: response['content'] as String,
        imageUrls: List<String>.from(response['imageUrls'] ?? []),
      );
    } catch (e) {
      // If API call fails, return default traffic light info
      return TrafficLightInfo(
        id: 'traffic-light',
        title: 'Сигнали світлофора',
        content: 'Інформація про сигнали світлофора тимчасово недоступна.',
        imageUrls: [],
      );
    }
  }
}
