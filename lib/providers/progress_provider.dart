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
        await serviceLocator.progress.updateModuleProgress(moduleId, 1.0, userId);
        
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
      await serviceLocator.progress.saveTestScore(
        testId, 
        score,
        'practice', // Assuming it's a practice test
        userId
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
      
      // Try to sync with API after updating local state
      try {
        // Use the concrete implementation for this specialized method
        await serviceLocator.progressApi.syncOfflineProgress(
          userId, 
          {
            'completedModules': [],
            'testScores': {},
            'topicProgress': {},
            'savedQuestions': [],
          }
        );
      } catch (e) {
        debugPrint('Error syncing reset progress to server: $e');
        // Continue anyway since local state is already updated
      }
      
      notifyListeners();
    } catch (e) {
      // Fallback to local implementation if something fails
      debugPrint('Error in resetProgressWithUserId: $e');
      
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
    // Check if savedItems is already initialized
    Map<String, List<String>> updatedSavedItems = 
      Map<String, List<String>>.from(progress.savedItems);
    
    // Initialize 'question' list if it doesn't exist
    if (!updatedSavedItems.containsKey('question')) {
      updatedSavedItems['question'] = [];
    }
    
    List<String> questionsList = List<String>.from(updatedSavedItems['question'] ?? []);
    bool isCurrentlySaved = questionsList.contains(questionId);
    
    // Also check old savedQuestions for backward compatibility
    if (!isCurrentlySaved) {
      isCurrentlySaved = progress.savedQuestions.contains(questionId);
    }
    
    // Get the current order mapping
    Map<String, Map<String, int>> updatedSavedItemsOrder = 
      Map<String, Map<String, int>>.from(progress.savedItemsOrder);
    
    // Initialize 'question' order map if it doesn't exist
    if (!updatedSavedItemsOrder.containsKey('question')) {
      updatedSavedItemsOrder['question'] = {};
    }
    
    Map<String, int> questionOrderMap = Map<String, int>.from(updatedSavedItemsOrder['question'] ?? {});
    
    if (isCurrentlySaved) {
      // Remove if already saved
      questionsList.remove(questionId);
      questionOrderMap.remove(questionId);
    } else {
      // Add if not saved and set the order to be the current timestamp
      // This way newer questions will have higher order numbers
      questionsList.add(questionId);
      questionOrderMap[questionId] = DateTime.now().millisecondsSinceEpoch;
    }
    
    updatedSavedItems['question'] = questionsList;
    updatedSavedItemsOrder['question'] = questionOrderMap;
    
    // Update local state immediately - use both for compatibility
    final List<String> updatedSavedQuestions = List<String>.from(progress.savedQuestions);
    if (isCurrentlySaved) {
      updatedSavedQuestions.remove(questionId);
    } else if (!updatedSavedQuestions.contains(questionId)) {
      updatedSavedQuestions.add(questionId);
    }
    
    final updatedProgress = progress.copyWith(
      savedItems: updatedSavedItems,
      savedQuestions: updatedSavedQuestions,
      savedItemsOrder: updatedSavedItemsOrder,
    );
    
    progress = updatedProgress;
    
    // Save to SharedPreferences for offline persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
    
    // Notify listeners to update UI
    notifyListeners();
    
    // Then try to sync with the server
    try {
      // IMPORTANT: Use the correct API interface
      // The service locator returns the appropriate implementation (REST or Firebase)
      // based on how it was initialized in main.dart
      if (isCurrentlySaved) {
        // Remove if already saved
        await serviceLocator.progress.removeSavedItem(questionId, 'question', userId);
      } else {
        // Add if not saved
        await serviceLocator.progress.saveItem(questionId, 'question', userId);
      }
      
      // No need to update local state again as we've already done it
    } catch (e) {
      // Log the error but don't revert the UI change
      // This allows the app to work offline while providing detailed error info
      debugPrint('API error while syncing saved question: $e');
      
      // We could show a toast message here to inform the user of sync issues
      // but the local state will remain correct
    }
  }
  
  // Check if a question is saved - check both places for backward compatibility
  bool isQuestionSaved(String questionId) {
    final savedQuestionsInNewStructure = progress.savedItems['question'] ?? [];
    return progress.savedQuestions.contains(questionId) || 
           savedQuestionsInNewStructure.contains(questionId);
  }
  
  // Get the saved order for a question
  int getQuestionSaveOrder(String questionId) {
    final orderMap = progress.savedItemsOrder['question'] ?? {};
    return orderMap[questionId] ?? 0;
  }
  
  // Migrate saved questions from old to new structure if needed
  Future<void> migrateSavedQuestionsIfNeeded(String userId) async {
    if (progress.savedQuestions.isNotEmpty && 
        (!progress.savedItems.containsKey('question') || progress.savedItems['question']!.isEmpty)) {
      
      debugPrint('Migrating saved questions from old to new structure');
      
      // Update local model
      Map<String, List<String>> updatedSavedItems = 
        Map<String, List<String>>.from(progress.savedItems);
      updatedSavedItems['question'] = List<String>.from(progress.savedQuestions);
      
      // Create order timestamps for each question, using incrementing values
      // so the original order is preserved
      Map<String, Map<String, int>> updatedSavedItemsOrder = 
        Map<String, Map<String, int>>.from(progress.savedItemsOrder);
      
      Map<String, int> questionOrderMap = {};
      final baseTime = DateTime.now().millisecondsSinceEpoch;
      
      for (int i = 0; i < progress.savedQuestions.length; i++) {
        questionOrderMap[progress.savedQuestions[i]] = baseTime + i;
      }
      
      updatedSavedItemsOrder['question'] = questionOrderMap;
      
      final updatedProgress = progress.copyWith(
        savedItems: updatedSavedItems,
        savedItemsOrder: updatedSavedItemsOrder,
      );
      
      progress = updatedProgress;
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('progress', jsonEncode(updatedProgress.toJson()));
      
      // Sync with server
      try {
        for (String questionId in progress.savedQuestions) {
          await serviceLocator.progress.saveItem(questionId, 'question', userId);
        }
        debugPrint('Migration complete');
      } catch (e) {
        debugPrint('API error during migration: $e');
      }
      
      notifyListeners();
    }
  }
  
  // For backwards compatibility with existing code
  Future<void> updateTopicProgress(String topicId, double progressValue) async {
    await updateTopicProgressWithUserId(topicId, progressValue, '');
  }

  // New method with userId parameter
  Future<void> updateTopicProgressWithUserId(String topicId, double progressValue, String userId) async {
    try {
      // Try to use the API
      await serviceLocator.progress.updateTopicProgress(topicId, progressValue, userId);
      
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
      // Try to use the API to sync progress - using concrete implementation
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
