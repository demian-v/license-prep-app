import 'package:dio/dio.dart';
import '../../models/quiz_question.dart';
import '../../models/quiz_topic.dart';
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
  @override
  Future<List<QuizTopic>> getQuizTopics(String language, String state) async {
    try {
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/quiz-topics',
        queryParameters: {
          'language': language,
          'state': stateValue,
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
  
  // Practice Questions
  @override
  Future<List<QuizQuestion>> getPracticeQuestions({
    required String language,
    required String state,
    required int count,
  }) async {
    try {
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/practice-questions',
        queryParameters: {
          'language': language,
          'state': stateValue,
          'count': count,
        },
      );
      
      return (response.data as List).map((data) => QuizQuestion(
        id: data['id'],
        topicId: data['topicId'] ?? '',
        questionText: data['questionText'],
        options: List<String>.from(data['options'] ?? []),
        correctAnswer: data['correctAnswer'],
        explanation: data['explanation'],
        ruleReference: data['ruleReference'],
        imagePath: data['imagePath'],
        type: _parseQuestionType(data['type']),
      )).toList();
    } catch (e) {
      throw 'Failed to load practice questions: ${e.toString()}';
    }
  }
  
  // Quiz Questions
  @override
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state) async {
    try {
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/quiz-questions',
        queryParameters: {
          'topicId': topicId,
          'language': language,
          'state': stateValue,
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
  
  
  // Traffic Rule Topics
  @override
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String state) async {
    try {
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/traffic-rule-topics',
        queryParameters: {
          'language': language,
          'state': stateValue,
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
  
  // Get a specific traffic rule topic by ID
  @override
  Future<TrafficRuleTopic?> getTrafficRuleTopic(String topicId) async {
    try {
      final response = await _apiClient.get(
        '/content/traffic-rule-topics/$topicId',
      );
      
      if (response.data != null) {
        final data = response.data;
        return TrafficRuleTopic(
          id: data['id'],
          title: data['title'],
          content: data['content'],
        );
      }
      
      return null;
    } catch (e) {
      throw 'Failed to load traffic rule topic: ${e.toString()}';
    }
  }
  
  @override
  Future<QuizQuestion?> getQuestionById(String questionId) async {
    try {
      final response = await _apiClient.get(
        '/content/question/$questionId',
      );
      
      if (response.data != null) {
        return QuizQuestion.fromMap(response.data);
      }
      
      return null;
    } catch (e) {
      throw 'Failed to load question: ${e.toString()}';
    }
  }
  
  // Theory Modules
  @override
  Future<List<TheoryModule>> getTheoryModules(String licenseType, String language, String state) async {
    try {
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/theory-modules',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': stateValue,
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
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/exams',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': stateValue,
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
  
  // Preload all quiz questions (not supported in REST API implementation)
  @override
  Future<void> preloadAllQuizQuestions(String state, String language) async {
    // This is a no-op for the REST API implementation
    // Pre-loading is only implemented for Firebase Content API which has direct cache access
    print('⚠️ [REST API] Pre-loading not supported in REST API implementation');
    // The REST API doesn't have direct access to the cache service
    // Normal API calls will be made when needed
    return;
  }
  
  // Practice Tests
  @override
  Future<List<PracticeTest>> getPracticeTests(String licenseType, String language, String state) async {
    try {
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/practice-tests',
        queryParameters: {
          'licenseType': licenseType,
          'language': language,
          'state': stateValue,
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
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/exams/$examId/questions',
        queryParameters: {
          'language': language,
          'state': stateValue,
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
      // Use 'ALL' as default if state is empty
      final stateValue = state.isEmpty ? 'ALL' : state;
      
      final response = await _apiClient.get(
        '/content/practice-tests/$testId/questions',
        queryParameters: {
          'language': language,
          'state': stateValue,
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
