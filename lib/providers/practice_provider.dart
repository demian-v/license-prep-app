import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' show min;
import '../models/exam.dart';
import '../models/quiz_question.dart';
import '../services/service_locator.dart';

class PracticeProvider extends ChangeNotifier {
  Exam? _currentPractice;
  Map<String, QuizQuestion> _loadedQuestions = {};
  bool _isLoading = false;
  String? _errorMessage;
  
  Exam? get currentPractice => _currentPractice;
  bool get isPracticeInProgress => _currentPractice != null && !_currentPractice!.isCompleted;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Start a new practice test with 40 random questions (no time limit)
  Future<void> startNewPractice({
    String language = 'uk',
    String state = 'all',
    String licenseType = 'driver',
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // Fetch random questions from Firebase
      final practiceQuestions = await _fetchRandomQuestions(
        language: language,
        state: state,
        licenseType: licenseType,
        count: 40 // Number of questions for the practice test
      );
      
      if (practiceQuestions.isEmpty) {
        _errorMessage = 'Failed to load practice questions';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Store questions locally
      _loadedQuestions = {};
      final questionIds = <String>[];
      
      for (final question in practiceQuestions) {
        _loadedQuestions[question.id] = question;
        questionIds.add(question.id);
      }
      
      // Create the practice test
      _currentPractice = Exam(
        questionIds: questionIds,
        startTime: DateTime.now(),
        timeLimit: 0, // No time limit
      );
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error starting practice test: $e');
      _errorMessage = 'Failed to start practice test: $e';
      _isLoading = false;
      _currentPractice = null;
      notifyListeners();
    }
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
    return _loadedQuestions[questionId];
  }
  
  // Helper method to fetch random questions
  Future<List<QuizQuestion>> _fetchRandomQuestions({
    required String language,
    required String state,
    required String licenseType,
    required int count,
  }) async {
    try {
      print('Fetching random questions for practice with: language=$language, state=$state, licenseType=$licenseType');
      
      // Get topics for the license type - Use 'IL' for state matching Firebase data
      final topics = await serviceLocator.content.getQuizTopics(
        licenseType,
        language,
        'IL' // Use 'IL' instead of lowercase 'all' to match Firebase data
      );
      
      print('Fetched ${topics.length} topics');
      
      // Collect questions from all topics
      List<QuizQuestion> allQuestions = [];
      
      for (final topic in topics) {
        print('Fetching questions for topic: ${topic.id}');
        
        final topicQuestions = await serviceLocator.content.getQuizQuestions(
          topic.id,
          language,
          'IL' // Use 'IL' instead of lowercase 'all' to match Firebase data
        );
        
        print('Fetched ${topicQuestions.length} questions for topic ${topic.id}');
        allQuestions.addAll(topicQuestions);
      }
      
      print('Total questions collected: ${allQuestions.length}');
      
      // Shuffle and select random questions
      if (allQuestions.isEmpty) {
        print('No questions found, returning empty list');
        return [];
      }
      
      final Random random = Random();
      allQuestions.shuffle(random);
      
      final selectedQuestions = allQuestions.take(min(count, allQuestions.length)).toList();
      print('Selected ${selectedQuestions.length} random questions for practice');
      
      // Take the requested number of questions or all if less available
      return selectedQuestions;
    } catch (e) {
      print('Error fetching random questions: $e');
      return [];
    }
  }
}
