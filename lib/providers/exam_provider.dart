import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/quiz_question.dart';
import '../data/quiz_data.dart';

class ExamProvider extends ChangeNotifier {
  Exam? _currentExam;
  Timer? _timer;
  
  Exam? get currentExam => _currentExam;
  bool get isExamInProgress => _currentExam != null && !_currentExam!.isCompleted;
  
  // Start a new exam with 40 random questions
  void startNewExam() {
    // Collect all question IDs from quiz topics
    final allQuestionIds = <String>[];
    for (final topic in quizTopics) {
      allQuestionIds.addAll(topic.questionIds);
    }
    
    // Shuffle and take 40 random question IDs
    final Random random = Random();
    allQuestionIds.shuffle(random);
    final selectedQuestionIds = allQuestionIds.take(40).toList();
    
    // Create a new exam
    _currentExam = Exam(
      questionIds: selectedQuestionIds,
      startTime: DateTime.now(),
      timeLimit: 60, // 60 minutes
    );
    
    // Start timer for UI updates
    _startTimer();
    
    notifyListeners();
  }
  
  // Answer the current question and move to the next
  void answerQuestion(String questionId, bool isCorrect) {
    if (_currentExam == null || _currentExam!.isCompleted) return;
    
    // Save the answer
    final updatedAnswers = Map<String, bool>.from(_currentExam!.answers);
    updatedAnswers[questionId] = isCorrect;
    
    // Update the exam state
    _currentExam = _currentExam!.copyWith(
      answers: updatedAnswers,
    );
    
    notifyListeners();
  }
  
  // Move to the next question
  void goToNextQuestion() {
    if (_currentExam == null || _currentExam!.isCompleted) return;
    
    if (_currentExam!.currentQuestionIndex < _currentExam!.questionIds.length - 1) {
      _currentExam = _currentExam!.copyWith(
        currentQuestionIndex: _currentExam!.currentQuestionIndex + 1,
      );
      notifyListeners();
    } else {
      // If it's the last question, complete the exam
      completeExam();
    }
  }
  
  // Skip the current question
  void skipQuestion() {
    goToNextQuestion();
  }
  
  // Complete the exam
  void completeExam() {
    if (_currentExam == null) return;
    
    _currentExam = _currentExam!.copyWith(
      isCompleted: true,
    );
    
    _stopTimer();
    
    // Store exam results - in a real app you'd save to local storage or API
    
    notifyListeners();
  }
  
  // Cancel/exit the current exam
  void cancelExam() {
    _stopTimer();
    _currentExam = null;
    notifyListeners();
  }
  
  // Get the current question
  QuizQuestion? getCurrentQuestion() {
    if (_currentExam == null) return null;
    
    final questionId = _currentExam!.questionIds[_currentExam!.currentQuestionIndex];
    return quizQuestions[questionId];
  }
  
  // Check if time limit is exceeded and complete exam if needed
  void _checkTimeLimit() {
    if (_currentExam == null || _currentExam!.isCompleted) return;
    
    if (_currentExam!.isTimeLimitExceeded) {
      completeExam();
    }
    
    notifyListeners();
  }
  
  // Start a timer for UI updates
  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _checkTimeLimit();
    });
  }
  
  // Stop the timer
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
  
  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
