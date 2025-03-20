import 'package:dio/dio.dart';
import '../../models/quiz_question.dart';
import '../../models/quiz_topic.dart';
import '../../models/road_sign.dart';
import '../../models/road_sign_category.dart';
import '../../models/traffic_light_info.dart';
import '../../models/traffic_rule_topic.dart';
import '../../models/theory_module.dart';
import '../../models/exam.dart';
import '../../models/practice_test.dart';
import 'api_client.dart';
import 'base/content_api_interface.dart';

class ContentApi implements ContentApiInterface {
  final ApiClient _apiClient;
  
  ContentApi(this._apiClient);
  
  // Helper method to parse quiz questions from API response
  List<QuizQuestion> _parseQuestions(List<dynamic> questionsData) {
    return questionsData.map((data) {
      return QuizQuestion(
        id: data['id'],
        topicId: data['topicId'],
        questionText: data['questionText'],
        options: List<String>.from(data['options']),
        correctAnswer: data['correctAnswer'],
        explanation: data['explanation'],
        ruleReference: data['ruleReference'],
        imagePath: data['imagePath'],
        type: _parseQuestionType(data['type']),
      );
    }).toList();
  }
  
  // Helper method to parse QuestionType enum
  QuestionType _parseQuestionType(String? typeStr) {
    if (typeStr == 'trueFalse') return QuestionType.trueFalse;
    if (typeStr == 'multipleChoice') return QuestionType.multipleChoice;
    return QuestionType.singleChoice; // Default
  }
  
  // Quiz Topics
  Future<List<QuizTopic>> getQuizTopics(String licenseType, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/quiz-topics',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      return (response.data as List).map((data) => QuizTopic(
        id: data['id'],
        title: data['title'],
        questionCount: data['questionCount'],
        progress: data['progress'] ?? 0.0,
        questionIds: List<String>.from(data['questionIds']),
      )).toList();
    } catch (e) {
      throw 'Failed to load quiz topics: ${e.toString()}';
    }
  }
  
  // Quiz Questions
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/quiz-questions',
        queryParameters: {
          'topicId': topicId,
          'language': language,
          'state': state,
        },
      );
      
      return (response.data as List).map((data) => QuizQuestion(
        id: data['id'],
        topicId: data['topicId'],
        questionText: data['questionText'],
        options: List<String>.from(data['options']),
        correctAnswer: data['correctAnswer'],
        explanation: data['explanation'],
        ruleReference: data['ruleReference'],
        imagePath: data['imagePath'],
        type: QuestionType.values.firstWhere(
          (e) => e.toString() == 'QuestionType.${data['type']}',
          orElse: () => QuestionType.singleChoice,
        ),
      )).toList();
    } catch (e) {
      throw 'Failed to load quiz questions: ${e.toString()}';
    }
  }
  
  // Road Sign Categories
  Future<List<RoadSignCategory>> getRoadSignCategories(String language) async {
    try {
      final response = await _apiClient.get(
        '/content/road-sign-categories',
        queryParameters: {
          'language': language,
        },
      );
      
      final List<dynamic> categoriesData = response.data;
      return categoriesData.map((data) {
        return RoadSignCategory(
          id: data['id'],
          title: data['title'],
          iconUrl: data['iconUrl'],
          description: data['description'],
          signs: [],  // Signs will be loaded separately via getRoadSigns method
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load road sign categories: ${e.toString()}';
    }
  }
  
  // Road Signs by Category
  Future<List<RoadSign>> getRoadSigns(String categoryId, String language) async {
    try {
      final response = await _apiClient.get(
        '/content/road-signs',
        queryParameters: {
          'categoryId': categoryId,
          'language': language,
        },
      );
      
      final List<dynamic> signsData = response.data;
      return signsData.map((data) {
        return RoadSign(
          id: data['id'],
          name: data['name'], 
          signCode: data['signCode'],
          imageUrl: data['imageUrl'],
          description: data['description'],
          installationGuidelines: data['installationGuidelines'],
          exampleImageUrl: data['exampleImageUrl'],
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load road signs: ${e.toString()}';
    }
  }
  
  // Traffic Light Information
  Future<List<TrafficLightInfo>> getTrafficLightInfo(String language) async {
    try {
      final response = await _apiClient.get(
        '/content/traffic-lights',
        queryParameters: {
          'language': language,
        },
      );
      
      final List<dynamic> trafficLightData = response.data;
      return trafficLightData.map((data) {
        return TrafficLightInfo(
          id: data['id'],
          title: data['title'], 
          content: data['content'],
          imageUrls: data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : [],
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load traffic light information: ${e.toString()}';
    }
  }
  
  // Traffic Rule Topics
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/traffic-rule-topics',
        queryParameters: {
          'language': language,
          'state': state,
        },
      );
      
      final List<dynamic> topicsData = response.data;
      return topicsData.map((data) {
        return TrafficRuleTopic(
          id: data['id'],
          title: data['title'],
          content: data['content'],
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load traffic rule topics: ${e.toString()}';
    }
  }
  
  // Theory Modules
  Future<List<TheoryModule>> getTheoryModules(String licenseType, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/theory-modules',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      final List<dynamic> modulesData = response.data;
      return modulesData.map((data) {
        return TheoryModule(
          id: data['id'],
          title: data['title'],
          licenseId: data['licenseId'],
          description: data['description'],
          estimatedTime: data['estimatedTime'],
          topics: data['topics'] != null ? List<String>.from(data['topics']) : [],
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load theory modules: ${e.toString()}';
    }
  }
  
  // Exams
  Future<List<Exam>> getExams(String licenseType, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/exams',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      final List<dynamic> examsData = response.data;
      return examsData.map((data) {
        return Exam(
          questionIds: List<String>.from(data['questionIds']),
          startTime: DateTime.parse(data['startTime']),
          timeLimit: data['timeLimit'],
          currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
          isCompleted: data['isCompleted'] ?? false,
          answers: data['answers'] != null 
            ? Map<String, bool>.from(data['answers']) 
            : {},
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load exams: ${e.toString()}';
    }
  }
  
  // Practice Tests
  Future<List<PracticeTest>> getPracticeTests(String licenseType, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/practice-tests',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': state,
        },
      );
      
      final List<dynamic> testsData = response.data;
      return testsData.map((data) {
        return PracticeTest(
          id: data['id'],
          licenseId: data['licenseId'],
          title: data['title'],
          description: data['description'],
          questions: data['questions'] ?? 0,
          timeLimit: data['timeLimit'],
        );
      }).toList();
    } catch (e) {
      throw 'Failed to load practice tests: ${e.toString()}';
    }
  }
  
  // Get specific exam questions
  Future<Exam> getExamWithQuestions(String examId, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/exams/$examId/questions',
        queryParameters: {
          'language': language,
          'state': state,
        },
      );
      
      final data = response.data;
      return Exam(
        questionIds: List<String>.from(data['questionIds']),
        startTime: DateTime.parse(data['startTime']),
        timeLimit: data['timeLimit'],
        currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
        isCompleted: data['isCompleted'] ?? false,
        answers: data['answers'] != null 
          ? Map<String, bool>.from(data['answers']) 
          : {},
      );
    } catch (e) {
      throw 'Failed to load exam questions: ${e.toString()}';
    }
  }
  
  // Get specific practice test questions
  Future<PracticeTest> getPracticeTestWithQuestions(String testId, String language, String state) async {
    try {
      final response = await _apiClient.get(
        '/content/practice-tests/$testId/questions',
        queryParameters: {
          'language': language,
          'state': state,
        },
      );
      
      final data = response.data;
      return PracticeTest(
        id: data['id'],
        licenseId: data['licenseId'],
        title: data['title'],
        description: data['description'],
        questions: data['questions'] ?? 0,
        timeLimit: data['timeLimit'],
      );
    } catch (e) {
      throw 'Failed to load practice test questions: ${e.toString()}';
    }
  }
}
