import '../../models/quiz_topic.dart';
import '../../models/quiz_question.dart';
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
        print('Response was empty, returning empty list');
        // Return empty list instead of fallback data to ensure we only use Firebase data
        return [];
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
      print('Returning empty list');
      
      // Return empty list instead of fallback data
      return [];
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
        print('Questions response was empty, returning empty list');
        // Return empty list instead of fallback data
        return [];
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
          // Handle different formats (array or string)
          dynamic correctAnswer;
          if (data.containsKey('correctAnswers') && data['correctAnswers'] != null) {
            // If it's stored as an array in Firestore
            if (data['correctAnswers'] is List) {
              correctAnswer = (data['correctAnswers'] as List)
                  .map((item) => item.toString())
                  .toList();
            }
          } else if (data.containsKey('correctAnswer') && data['correctAnswer'] != null) {
            correctAnswer = data['correctAnswer'].toString();
          } else if (data.containsKey('correctAnswerString') && data['correctAnswerString'] != null) {
            // For backward compatibility, split comma-separated values
            String answerStr = data['correctAnswerString'].toString();
            if (data['type']?.toString()?.toLowerCase() == 'multiplechoice') {
              correctAnswer = answerStr.split(', ').map((s) => s.trim()).toList();
            } else {
              correctAnswer = answerStr;
            }
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
      print('Returning empty list');
      
      // Return empty list instead of fallback data
      return [];
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
  
}
