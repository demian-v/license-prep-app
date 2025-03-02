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
}