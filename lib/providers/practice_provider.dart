import 'dart:math';
import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/quiz_question.dart';
import '../data/quiz_data.dart';

class PracticeProvider extends ChangeNotifier {
  Exam? _currentPractice;
  
  Exam? get currentPractice => _currentPractice;
  bool get isPracticeInProgress => _currentPractice != null && !_currentPractice!.isCompleted;
  
  // Start a new practice test with 40 random questions (no time limit)
  void startNewPractice() {
    // Collect all question IDs from quiz topics
    final allQuestionIds = <String>[];
    for (final topic in quizTopics) {
      allQuestionIds.addAll(topic.questionIds);
    }
    
    // Shuffle and take 40 random question IDs
    final Random random = Random();
    allQuestionIds.shuffle(random);
    final selectedQuestionIds = allQuestionIds.take(40).toList();
    
    // Create a new practice test (using Exam model with 0 time limit)
    _currentPractice = Exam(
      questionIds: selectedQuestionIds,
      startTime: DateTime.now(),
      timeLimit: 0, // No time limit
    );
    
    notifyListeners();
  }
  
  // Answer the current question and move to the next
  void answerQuestion(String questionId, bool isCorrect) {
    if (_currentPractice == null || _currentPractice!.isCompleted) return;
    
    // Save the answer
    final updatedAnswers = Map<String, bool>.from(_currentPractice!.answers);
    updatedAnswers[questionId] = isCorrect;
    
    // Update the practice state
    _currentPractice = _currentPractice!.copyWith(
      answers: updatedAnswers,
    );
    
    notifyListeners();
  }
  
  // Move to the next question
  void goToNextQuestion() {
    if (_currentPractice == null || _currentPractice!.isCompleted) return;
    
    if (_currentPractice!.currentQuestionIndex < _currentPractice!.questionIds.length - 1) {
      _currentPractice = _currentPractice!.copyWith(
        currentQuestionIndex: _currentPractice!.currentQuestionIndex + 1,
      );
      notifyListeners();
    } else {
      // If it's the last question, complete the practice
      completePractice();
    }
  }
  
  // Skip the current question
  void skipQuestion() {
    goToNextQuestion();
  }
  
  // Complete the practice
  void completePractice() {
    if (_currentPractice == null) return;
    
    _currentPractice = _currentPractice!.copyWith(
      isCompleted: true,
    );
    
    notifyListeners();
  }
  
  // Cancel/exit the current practice
  void cancelPractice() {
    _currentPractice = null;
    notifyListeners();
  }
  
  // Get the current question
  QuizQuestion? getCurrentQuestion() {
    if (_currentPractice == null) return null;
    
    final questionId = _currentPractice!.questionIds[_currentPractice!.currentQuestionIndex];
    return quizQuestions[questionId];
  }
}
