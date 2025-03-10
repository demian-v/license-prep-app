import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/progress.dart';

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

  Future<void> completeModule(String moduleId) async {
    if (!progress.completedModules.contains(moduleId)) {
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

  Future<void> saveTestScore(String testId, double score) async {
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
  
  Future<void> resetProgress() async {
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
  }
  
  // Toggle a question's saved status
  Future<void> toggleSavedQuestion(String questionId) async {
    final List<String> updatedSavedQuestions = List<String>.from(progress.savedQuestions);
    
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
  
  // Check if a question is saved
  bool isQuestionSaved(String questionId) {
    return progress.savedQuestions.contains(questionId);
  }
  
  // Add a method to update topic progress
  Future<void> updateTopicProgress(String topicId, double progressValue) async {
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
