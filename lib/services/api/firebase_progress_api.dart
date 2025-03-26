import '../../models/progress.dart';
import 'firebase_functions_client.dart';
import 'base/progress_api_interface.dart';

class FirebaseProgressApi implements ProgressApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  
  FirebaseProgressApi(this._functionsClient);
  
  /// Get the overall progress for a user
  @override
  Future<Map<String, dynamic>> getUserProgress([String? userId]) async {
    try {
      final Map<String, dynamic>? data = userId != null ? {'userId': userId} : null;
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getUserProgress',
        data: data,
      );
      
      return response;
    } catch (e) {
      throw 'Failed to fetch user progress: $e';
    }
  }
  
  /// Update the progress for a specific module
  @override
  Future<Map<String, dynamic>> updateModuleProgress(String moduleId, double progress, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {
        'moduleId': moduleId,
        'progress': progress,
      };
      
      if (userId != null) {
        data['userId'] = userId;
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateModuleProgress',
        data: data,
      );
      
      return response;
    } catch (e) {
      throw 'Failed to update module progress: $e';
    }
  }
  
  /// Update quiz progress for a topic
  @override
  Future<Map<String, dynamic>> updateTopicProgress(String topicId, double progress, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {
        'topicId': topicId,
        'progress': progress,
      };
      
      if (userId != null) {
        data['userId'] = userId;
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateTopicProgress',
        data: data,
      );
      
      return response;
    } catch (e) {
      throw 'Failed to update topic progress: $e';
    }
  }
  
  /// Save a question answer
  @override
  Future<Map<String, dynamic>> updateQuestionProgress(String questionId, bool isCorrect, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {
        'questionId': questionId,
        'isCorrect': isCorrect,
      };
      
      if (userId != null) {
        data['userId'] = userId;
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateQuestionProgress',
        data: data,
      );
      
      return response;
    } catch (e) {
      throw 'Failed to update question progress: $e';
    }
  }
  
  /// Save test score for practice test or exam
  @override
  Future<Map<String, dynamic>> saveTestScore(String testId, double score, String testType, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {
        'testId': testId,
        'score': score,
        'testType': testType, // 'practice' or 'exam'
      };
      
      if (userId != null) {
        data['userId'] = userId;
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'saveTestScore',
        data: data,
      );
      
      return response;
    } catch (e) {
      throw 'Failed to save test score: $e';
    }
  }
  
  /// Get saved items (bookmarked questions, topics, etc.)
  @override
  Future<dynamic> getSavedItems([String? userId]) async {
    try {
      final Map<String, dynamic>? data = userId != null ? {'userId': userId} : null;
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getSavedItems',
        data: data,
      );
      
      return response;
    } catch (e) {
      throw 'Failed to fetch saved items: $e';
    }
  }
  
  /// Add a saved item (bookmark a question, topic, etc.)
  @override
  Future<Map<String, dynamic>> saveItem(String itemId, String itemType, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {
        'itemId': itemId,
        'itemType': itemType,
      };
      
      if (userId != null && userId.isNotEmpty) {
        data['userId'] = userId;
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'addSavedItem',
        data: data,
      );
      
      return response;
    } catch (e) {
      print('Error in saveItem: $e');
      throw 'Failed to save item: $e';
    }
  }
  
  /// Remove a saved item (unbookmark a question, topic, etc.)
  @override
  Future<Map<String, dynamic>> removeSavedItem(String itemId, String itemType, [String? userId]) async {
    try {
      final Map<String, dynamic> data = {
        'itemId': itemId,
        'itemType': itemType,
      };
      
      if (userId != null && userId.isNotEmpty) {
        data['userId'] = userId;
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'removeSavedItem',
        data: data,
      );
      
      return response;
    } catch (e) {
      print('Error in removeSavedItem: $e');
      throw 'Failed to remove saved item: $e';
    }
  }
}
