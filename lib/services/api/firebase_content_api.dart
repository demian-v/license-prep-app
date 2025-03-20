import '../../models/quiz_topic.dart';
import '../../models/quiz_question.dart';
import '../../models/road_sign_category.dart';
import '../../models/road_sign.dart';
import '../../models/theory_module.dart';
import '../../models/practice_test.dart';
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
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizTopics',
        data: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        return QuizTopic(
          id: data['id'] as String,
          title: data['title'] as String,
          questionCount: data['questionCount'] as int,
          progress: data['progress'] != null ? (data['progress'] as num).toDouble() : 0.0,
          questionIds: List<String>.from(data['questionIds'] ?? []),
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch quiz topics: $e';
    }
  }
  
  /// Get quiz questions based on topic ID, language, and state
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state) async {
    try {
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizQuestions',
        data: {
          'topicId': topicId,
          'language': language,
          'state': state,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        return QuizQuestion(
          id: data['id'] as String,
          topicId: data['topicId'] as String,
          questionText: data['questionText'] as String,
          options: List<String>.from(data['options'] ?? []),
          correctAnswer: data['correctAnswer'],
          explanation: data['explanation'] as String?,
          ruleReference: data['ruleReference'] as String?,
          imagePath: data['imagePath'] as String?,
          type: _parseQuestionType(data['type'] as String),
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch quiz questions: $e';
    }
  }
  
  /// Get road sign categories for a specific language
  Future<List<RoadSignCategory>> getRoadSignCategories(String language) async {
    try {
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
}
