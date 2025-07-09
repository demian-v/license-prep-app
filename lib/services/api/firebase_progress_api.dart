import '../../models/progress.dart';
import 'firebase_functions_client.dart';
import 'base/progress_api_interface.dart';
import '../direct_firestore_service.dart';
import 'package:flutter/foundation.dart';

class FirebaseProgressApi implements ProgressApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  final DirectFirestoreService _directFirestoreService;
  
  FirebaseProgressApi(this._functionsClient) : _directFirestoreService = DirectFirestoreService();
  
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
      // 🥇 PRIMARY: Try Firebase Functions first
      debugPrint('FirebaseProgressApi: Trying Firebase Functions for getSavedItems');
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getSavedQuestions',
        data: {},
      );
      
      debugPrint('FirebaseProgressApi: Firebase Functions succeeded for getSavedItems');
      return response;
      
    } catch (e) {
      debugPrint('FirebaseProgressApi: Firebase Functions failed for getSavedItems: $e');
      debugPrint('FirebaseProgressApi: Trying Direct Firestore fallback');
      
      try {
        // 🥈 BACKUP: Direct Firestore fallback
        if (userId == null || userId.isEmpty) {
          throw 'User ID is required for direct Firestore access';
        }
        
        final savedQuestionIds = await _directFirestoreService.getSavedQuestionsDirect(userId);
        
        debugPrint('FirebaseProgressApi: Direct Firestore succeeded for getSavedItems');
        return {
          'success': true,
          'savedQuestions': savedQuestionIds,
          'count': savedQuestionIds.length,
          'method': 'direct'
        };
        
      } catch (directError) {
        debugPrint('FirebaseProgressApi: Direct Firestore also failed: $directError');
        throw 'Both Firebase Functions and Direct Firestore failed for getSavedItems: $directError';
      }
    }
  }
  
  /// Get saved questions with content (Optimized for direct question loading)
  @override
  Future<dynamic> getSavedQuestionsWithContent([String? userId]) async {
    try {
      // 🥇 PRIMARY: Try optimized Firebase Functions first
      debugPrint('FirebaseProgressApi: Trying Firebase Functions for getSavedQuestionsWithContent');
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getSavedQuestionsWithContent',
        data: {},
      );
      
      debugPrint('FirebaseProgressApi: Firebase Functions succeeded for getSavedQuestionsWithContent');
      return response;
      
    } catch (e) {
      debugPrint('FirebaseProgressApi: Firebase Functions failed for getSavedQuestionsWithContent: $e');
      throw 'Optimized Firebase Functions failed for getSavedQuestionsWithContent: $e';
    }
  }
  
  /// Add a saved item (bookmark a question, topic, etc.)
  @override
  Future<Map<String, dynamic>> saveItem(String itemId, String itemType, [String? userId]) async {
    try {
      // 🥇 PRIMARY: Try Firebase Functions first
      debugPrint('FirebaseProgressApi: Trying Firebase Functions for saveItem');
      
      final Map<String, dynamic> data = {
        'questionId': itemId, // Use questionId for the new Firebase Functions
      };
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'addSavedQuestion',
        data: data,
      );
      
      debugPrint('FirebaseProgressApi: Firebase Functions succeeded for saveItem');
      return response;
      
    } catch (e) {
      debugPrint('FirebaseProgressApi: Firebase Functions failed for saveItem: $e');
      debugPrint('FirebaseProgressApi: Trying Direct Firestore fallback');
      
      try {
        // 🥈 BACKUP: Direct Firestore fallback
        if (userId == null || userId.isEmpty) {
          throw 'User ID is required for direct Firestore access';
        }
        
        await _directFirestoreService.addSavedQuestionDirect(userId, itemId);
        
        debugPrint('FirebaseProgressApi: Direct Firestore succeeded for saveItem');
        return {
          'success': true,
          'message': 'Question saved successfully',
          'questionId': itemId,
          'method': 'direct'
        };
        
      } catch (directError) {
        debugPrint('FirebaseProgressApi: Direct Firestore also failed: $directError');
        throw 'Both Firebase Functions and Direct Firestore failed for saveItem: $directError';
      }
    }
  }
  
  /// Remove a saved item (unbookmark a question, topic, etc.)
  @override
  Future<Map<String, dynamic>> removeSavedItem(String itemId, String itemType, [String? userId]) async {
    try {
      // 🥇 PRIMARY: Try Firebase Functions first
      debugPrint('FirebaseProgressApi: Trying Firebase Functions for removeSavedItem');
      
      final Map<String, dynamic> data = {
        'questionId': itemId, // Use questionId for the new Firebase Functions
      };
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'removeSavedQuestion',
        data: data,
      );
      
      debugPrint('FirebaseProgressApi: Firebase Functions succeeded for removeSavedItem');
      return response;
      
    } catch (e) {
      debugPrint('FirebaseProgressApi: Firebase Functions failed for removeSavedItem: $e');
      debugPrint('FirebaseProgressApi: Trying Direct Firestore fallback');
      
      try {
        // 🥈 BACKUP: Direct Firestore fallback
        if (userId == null || userId.isEmpty) {
          throw 'User ID is required for direct Firestore access';
        }
        
        await _directFirestoreService.removeSavedQuestionDirect(userId, itemId);
        
        debugPrint('FirebaseProgressApi: Direct Firestore succeeded for removeSavedItem');
        return {
          'success': true,
          'message': 'Question removed successfully',
          'questionId': itemId,
          'method': 'direct'
        };
        
      } catch (directError) {
        debugPrint('FirebaseProgressApi: Direct Firestore also failed: $directError');
        throw 'Both Firebase Functions and Direct Firestore failed for removeSavedItem: $directError';
      }
    }
  }
}
