import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/progress.dart';
import '../models/quiz_progress.dart';
import '../services/service_locator.dart';

class ProgressProvider extends ChangeNotifier {
  UserProgress progress;

  ProgressProvider(this.progress);

  Future<void> selectLicense(String licenseId) async {
    final updatedProgress = progress.copyWith(
      selectedLicense: licenseId,
    );
    
    progress = updatedProgress;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
    
    notifyListeners();
  }

  // For backwards compatibility with existing code
  Future<void> completeModule(String moduleId) async {
    await completeModuleWithUserId(moduleId, '');
  }

  // New method with userId parameter
  Future<void> completeModuleWithUserId(String moduleId, String userId) async {
    if (!progress.completedModules.contains(moduleId)) {
      try {
        // Try to use the API
        await serviceLocator.progressApi.updateModuleProgress(userId, moduleId, 1.0);
        
        final updatedCompletedModules = List<String>.from(progress.completedModules)..add(moduleId);
        final updatedProgress = progress.copyWith(
          completedModules: updatedCompletedModules,
        );
        
        progress = updatedProgress;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
        
        notifyListeners();
      } catch (e) {
        // Fallback to local implementation if API is not available
        debugPrint('API error, updating locally: $e');
        
        final updatedCompletedModules = List<String>.from(progress.completedModules)..add(moduleId);
        final updatedProgress = progress.copyWith(
          completedModules: updatedCompletedModules,
        );
        
        progress = updatedProgress;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
        
        notifyListeners();
      }
    }
  }

  // For backwards compatibility with existing code
  Future<void> saveTestScore(String testId, double score) async {
    await saveTestScoreWithUserId(testId, score, '');
  }

  // New method with userId parameter
  Future<void> saveTestScoreWithUserId(String testId, double score, String userId) async {
    try {
      // Try to use the API
      await serviceLocator.progressApi.updatePracticeTestProgress(
        userId, 
        testId, 
        {'score': score}
      );
      
      final updatedScores = Map<String, double>.from(progress.testScores);
      updatedScores[testId] = score;
      
      final updatedProgress = progress.copyWith(
        testScores: updatedScores,
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    } catch (e) {
      // Fallback to local implementation if API is not available
      debugPrint('API error, updating locally: $e');
      
      final updatedScores = Map<String, double>.from(progress.testScores);
      updatedScores[testId] = score;
      
      final updatedProgress = progress.copyWith(
        testScores: updatedScores,
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    }
  }
  
  // For backwards compatibility with existing code
  Future<void> resetProgress() async {
    await resetProgressWithUserId('');
  }

  // New method with userId parameter
  Future<void> resetProgressWithUserId(String userId) async {
    try {
      // Sync with API first - send empty progress
      await serviceLocator.progressApi.syncOfflineProgress(
        userId, 
        {
          'completedModules': [],
          'testScores': {},
          'topicProgress': {},
          'savedQuestions': [],
        }
      );
      
      // Create a new empty progress object, keeping only the selected license
      final updatedProgress = UserProgress(
        completedModules: [],
        testScores: {},
        selectedLicense: progress.selectedLicense,
        topicProgress: {}, // Reset topic progress to empty
        savedQuestions: [], // Reset saved questions to empty
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    } catch (e) {
      // Fallback to local implementation if API is not available
      debugPrint('API error, resetting locally: $e');
      
      final updatedProgress = UserProgress(
        completedModules: [],
        testScores: {},
        selectedLicense: progress.selectedLicense,
        topicProgress: {}, // Reset topic progress to empty
        savedQuestions: [], // Reset saved questions to empty
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    }
  }
  
  // For backwards compatibility with existing code
  Future<void> toggleSavedQuestion(String questionId) async {
    await toggleSavedQuestionWithUserId(questionId, '');
  }

  // New method with userId parameter
  Future<void> toggleSavedQuestionWithUserId(String questionId, String userId) async {
    final List<String> updatedSavedQuestions = List<String>.from(progress.savedQuestions);
    
    try {
      if (updatedSavedQuestions.contains(questionId)) {
        // Remove if already saved
        await serviceLocator.progressApi.removeSavedItem(userId, questionId);
        updatedSavedQuestions.remove(questionId);
      } else {
        // Add if not saved
        await serviceLocator.progressApi.addSavedItem(userId, questionId, 'question');
        updatedSavedQuestions.add(questionId);
      }
      
      final updatedProgress = progress.copyWith(
        savedQuestions: updatedSavedQuestions,
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    } catch (e) {
      // Fallback to local implementation if API is not available
      debugPrint('API error, updating locally: $e');
      
      if (updatedSavedQuestions.contains(questionId)) {
        // Remove if already saved
        updatedSavedQuestions.remove(questionId);
      } else {
        // Add if not saved
        updatedSavedQuestions.add(questionId);
      }
      
      final updatedProgress = progress.copyWith(
        savedQuestions: updatedSavedQuestions,
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    }
  }
  
  // Check if a question is saved
  bool isQuestionSaved(String questionId) {
    return progress.savedQuestions.contains(questionId);
  }
  
  // For backwards compatibility with existing code
  Future<void> updateTopicProgress(String topicId, double progressValue) async {
    await updateTopicProgressWithUserId(topicId, progressValue, '');
  }

  // New method with userId parameter
  Future<void> updateTopicProgressWithUserId(String topicId, double progressValue, String userId) async {
    try {
      // Try to use the API
      await serviceLocator.progressApi.updateTopicProgress(userId, topicId, progressValue);
      
      final updatedTopicProgress = Map<String, double>.from(progress.topicProgress);
      updatedTopicProgress[topicId] = progressValue;
      
      final updatedProgress = progress.copyWith(
        topicProgress: updatedTopicProgress,
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    } catch (e) {
      // Fallback to local implementation if API is not available
      debugPrint('API error, updating locally: $e');
      
      final updatedTopicProgress = Map<String, double>.from(progress.topicProgress);
      updatedTopicProgress[topicId] = progressValue;
      
      final updatedProgress = progress.copyWith(
        topicProgress: updatedTopicProgress,
      );
      
      progress = updatedProgress;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      notifyListeners();
    }
  }

  // Sync local progress with server
  Future<void> syncProgress(String userId) async {
    try {
      // Try to use the API to sync progress
      await serviceLocator.progressApi.syncOfflineProgress(
        userId, 
        {
          'completedModules': progress.completedModules,
          'testScores': progress.testScores,
          'topicProgress': progress.topicProgress,
          'savedQuestions': progress.savedQuestions,
        }
      );
      
      // Optionally fetch and merge remote changes
      // This would require implementing logic to handle conflicts
      
    } catch (e) {
      debugPrint('API error during sync: $e');
      // No local fallback needed as this is just a sync operation
    }
  }
  
  // Load quiz progress from the API
  Future<QuizProgress?> loadQuizProgress(String userId) async {
    try {
      return await serviceLocator.progressApi.getQuizProgress(userId);
    } catch (e) {
      debugPrint('API error loading quiz progress: $e');
      return null;
    }
  }
  
  // Save exam result
  Future<void> saveExamResult(String examId, Map<String, dynamic> result, String userId) async {
    try {
      await serviceLocator.progressApi.saveExamResult(userId, examId, result);
      // No need to update local progress as we'll fetch results when needed
    } catch (e) {
      debugPrint('API error saving exam result: $e');
      // Could implement local storage of exam results as a fallback
    }
  }
}
