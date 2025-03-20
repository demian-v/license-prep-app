import 'package:dio/dio.dart';
import '../../models/progress.dart';
import '../../models/quiz_progress.dart';
import 'api_client.dart';
import 'base/progress_api_interface.dart';

class ProgressApi implements ProgressApiInterface {
  final ApiClient _apiClient;
  
  ProgressApi(this._apiClient);
  
  // Implementation of interface method
  @override
  Future<Map<String, dynamic>> getUserProgress([String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      final response = await _apiClient.get(
        '/progress/$id',
      );
      
      return response.data;
    } catch (e) {
      throw 'Failed to load user progress: ${e.toString()}';
    }
  }
  
  // Legacy method for backward compatibility
  Future<void> legacyUpdateModuleProgress(String userId, String moduleId, double progress) async {
    try {
      await _apiClient.put(
        '/progress/$userId/modules/$moduleId',
        data: {
          'progress': progress,
        },
      );
    } catch (e) {
      throw 'Failed to update module progress: ${e.toString()}';
    }
  }
  
  // Implementation of interface method
  @override
  Future<Map<String, dynamic>> updateModuleProgress(String moduleId, double progress, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      await legacyUpdateModuleProgress(id, moduleId, progress);
      return {'success': true};
    } catch (e) {
      throw 'Failed to update module progress: ${e.toString()}';
    }
  }
  
  // Get quiz progress for a user
  Future<QuizProgress> getQuizProgress([String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      final response = await _apiClient.get(
        '/progress/$id/quizzes',
      );
      
      final data = response.data;
      return QuizProgress(
        answeredQuestions: Map<String, bool>.from(data['answeredQuestions'] ?? {}),
        topicProgress: Map<String, double>.from(data['topicProgress'] ?? {}),
      );
    } catch (e) {
      throw 'Failed to load quiz progress: ${e.toString()}';
    }
  }
  
  // Update quiz progress
  Future<void> updateQuizProgress(QuizProgress progress, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      await _apiClient.put(
        '/progress/$id/quizzes',
        data: {
          'answeredQuestions': progress.answeredQuestions,
          'topicProgress': progress.topicProgress,
        },
      );
    } catch (e) {
      throw 'Failed to update quiz progress: ${e.toString()}';
    }
  }
  
  // Legacy method for backward compatibility
  Future<void> legacyUpdateTopicProgress(String userId, String topicId, double progress) async {
    try {
      await _apiClient.put(
        '/progress/$userId/quizzes/topics/$topicId',
        data: {
          'progress': progress,
        },
      );
    } catch (e) {
      throw 'Failed to update topic progress: ${e.toString()}';
    }
  }
  
  // Implementation of interface method
  @override
  Future<Map<String, dynamic>> updateTopicProgress(String topicId, double progress, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      await legacyUpdateTopicProgress(id, topicId, progress);
      return {'success': true};
    } catch (e) {
      throw 'Failed to update topic progress: ${e.toString()}';
    }
  }
  
  // Legacy method for backward compatibility
  Future<void> legacyUpdateQuestionProgress(String userId, String questionId, bool isCorrect) async {
    try {
      await _apiClient.put(
        '/progress/$userId/quizzes/questions/$questionId',
        data: {
          'isCorrect': isCorrect,
        },
      );
    } catch (e) {
      throw 'Failed to update question progress: ${e.toString()}';
    }
  }
  
  // Implementation of interface method
  @override
  Future<Map<String, dynamic>> updateQuestionProgress(String questionId, bool isCorrect, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      await legacyUpdateQuestionProgress(id, questionId, isCorrect);
      return {'success': true};
    } catch (e) {
      throw 'Failed to update question progress: ${e.toString()}';
    }
  }
  
  @override
  Future<Map<String, dynamic>> saveTestScore(String testId, double score, String testType, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      final response = await _apiClient.post(
        '/progress/$id/tests',
        data: {
          'testId': testId,
          'score': score,
          'testType': testType,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      return response.data ?? {'success': true};
    } catch (e) {
      throw 'Failed to save test score: ${e.toString()}';
    }
  }
  
  // Get practice test progress
  Future<Map<String, dynamic>> getPracticeTestProgress([String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      final response = await _apiClient.get(
        '/progress/$id/practice-tests',
      );
      
      return response.data;
    } catch (e) {
      throw 'Failed to load practice test progress: ${e.toString()}';
    }
  }
  
  // Update practice test progress
  Future<void> updatePracticeTestProgress(String userId, String testId, Map<String, dynamic> progress) async {
    try {
      await _apiClient.put(
        '/progress/$userId/practice-tests/$testId',
        data: progress,
      );
    } catch (e) {
      throw 'Failed to update practice test progress: ${e.toString()}';
    }
  }
  
  // Get exam results
  Future<List<Map<String, dynamic>>> getExamResults([String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      final response = await _apiClient.get(
        '/progress/$id/exams',
      );
      
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw 'Failed to load exam results: ${e.toString()}';
    }
  }
  
  // Save exam result
  Future<void> saveExamResult(String userId, String examId, Map<String, dynamic> result) async {
    try {
      await _apiClient.post(
        '/progress/$userId/exams',
        data: {
          'examId': examId,
          ...result,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw 'Failed to save exam result: ${e.toString()}';
    }
  }
  
  @override
  Future<dynamic> getSavedItems([String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      final response = await _apiClient.get(
        '/progress/$id/saved-items',
      );
      
      return response.data;
    } catch (e) {
      throw 'Failed to load saved items: ${e.toString()}';
    }
  }
  
  // Legacy method for maintaining compatibility
  Future<void> addSavedItem(String userId, String itemId, String itemType) async {
    try {
      await _apiClient.post(
        '/progress/$userId/saved-items',
        data: {
          'itemId': itemId,
          'itemType': itemType,
        },
      );
    } catch (e) {
      throw 'Failed to add saved item: ${e.toString()}';
    }
  }
  
  @override
  Future<Map<String, dynamic>> saveItem(String itemId, String itemType, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      await addSavedItem(id, itemId, itemType);
      return {'success': true};
    } catch (e) {
      throw 'Failed to save item: ${e.toString()}';
    }
  }
  
  // Legacy method for maintaining compatibility
  Future<void> legacyRemoveSavedItem(String userId, String itemId) async {
    try {
      await _apiClient.delete(
        '/progress/$userId/saved-items/$itemId',
      );
    } catch (e) {
      throw 'Failed to remove saved item: ${e.toString()}';
    }
  }
  
  @override
  Future<Map<String, dynamic>> removeSavedItem(String itemId, String itemType, [String? userId]) async {
    try {
      final String id = userId ?? await _getCurrentUserId();
      await legacyRemoveSavedItem(id, itemId);
      return {'success': true};
    } catch (e) {
      throw 'Failed to remove saved item: ${e.toString()}';
    }
  }
  
  // Sync offline progress
  Future<void> syncOfflineProgress(String userId, Map<String, dynamic> offlineProgress) async {
    try {
      await _apiClient.post(
        '/progress/$userId/sync',
        data: offlineProgress,
      );
    } catch (e) {
      throw 'Failed to sync offline progress: ${e.toString()}';
    }
  }
  
  // Helper method to get current user ID
  Future<String> _getCurrentUserId() async {
    final token = await _apiClient.getAuthToken();
    if (token == null) {
      throw 'User not authenticated';
    }
    
    // In a real app, you would decode the JWT token to get the user ID
    // For now, we'll use a dummy ID
    return 'current-user-id';
  }
}
