import 'package:dio/dio.dart';
import '../../models/progress.dart';
import '../../models/quiz_progress.dart';
import 'api_client.dart';

class ProgressApi {
  final ApiClient _apiClient;
  
  ProgressApi(this._apiClient);
  
  // Get overall user progress
  Future<Map<String, dynamic>> getUserProgress(String userId) async {
    try {
      final response = await _apiClient.get(
        '/progress/$userId',
      );
      
      return response.data;
    } catch (e) {
      throw 'Failed to load user progress: ${e.toString()}';
    }
  }
  
  // Update overall progress for a specific module
  Future<void> updateModuleProgress(String userId, String moduleId, double progress) async {
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
  
  // Get quiz progress for a user
  Future<QuizProgress> getQuizProgress(String userId) async {
    try {
      final response = await _apiClient.get(
        '/progress/$userId/quizzes',
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
  Future<void> updateQuizProgress(String userId, QuizProgress progress) async {
    try {
      await _apiClient.put(
        '/progress/$userId/quizzes',
        data: {
          'answeredQuestions': progress.answeredQuestions,
          'topicProgress': progress.topicProgress,
        },
      );
    } catch (e) {
      throw 'Failed to update quiz progress: ${e.toString()}';
    }
  }
  
  // Update progress for a specific topic
  Future<void> updateTopicProgress(String userId, String topicId, double progress) async {
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
  
  // Update progress for a specific question
  Future<void> updateQuestionProgress(String userId, String questionId, bool isCorrect) async {
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
  
  // Get practice test progress
  Future<Map<String, dynamic>> getPracticeTestProgress(String userId) async {
    try {
      final response = await _apiClient.get(
        '/progress/$userId/practice-tests',
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
  Future<List<Map<String, dynamic>>> getExamResults(String userId) async {
    try {
      final response = await _apiClient.get(
        '/progress/$userId/exams',
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
  
  // Get saved items
  Future<List<String>> getSavedItems(String userId) async {
    try {
      final response = await _apiClient.get(
        '/progress/$userId/saved-items',
      );
      
      return List<String>.from(response.data);
    } catch (e) {
      throw 'Failed to load saved items: ${e.toString()}';
    }
  }
  
  // Add item to saved items
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
  
  // Remove item from saved items
  Future<void> removeSavedItem(String userId, String itemId) async {
    try {
      await _apiClient.delete(
        '/progress/$userId/saved-items/$itemId',
      );
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
}
