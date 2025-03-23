import 'dart:math';
import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/quiz_question.dart';
import '../services/service_locator.dart';

class ExamProvider extends ChangeNotifier {
  Exam? _currentExam;
  Timer? _timer;
  Map<String, QuizQuestion> _loadedQuestions = {};
  bool _isLoading = false;
  String? _errorMessage;
  
  Exam? get currentExam => _currentExam;
  bool get isExamInProgress => _currentExam != null && !_currentExam!.isCompleted;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Start a new exam with 40 random questions
  Future<void> startNewExam({
    required String language,
    required String state,
    required String licenseType,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // Fetch random questions from Firebase
      final examQuestions = await _fetchRandomQuestions(
        language: language,
        state: state,
        licenseType: licenseType,
        count: 40 // Number of questions for the exam
      );
      
      if (examQuestions.isEmpty) {
        _errorMessage = 'Failed to load exam questions';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // Store questions locally
      _loadedQuestions = {};
      final questionIds = <String>[];
      
      for (final question in examQuestions) {
        _loadedQuestions[question.id] = question;
        questionIds.add(question.id);
      }
      
      // Create the exam
      _currentExam = Exam(
        questionIds: questionIds,
        startTime: DateTime.now(),
        timeLimit: 60, // 60 minutes
      );
      
      _isLoading = false;
      notifyListeners();
      
      // Start timer for UI updates
      _startTimer();
    } catch (e) {
      print('Error starting exam: $e');
      _errorMessage = 'Failed to start exam: $e';
      _isLoading = false;
      _currentExam = null;
      notifyListeners();
    }
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
      print('Fetching random questions for exam with: language=$language, licenseType=$licenseType');
      
      // Get topics for the license type - Use 'IL' for state matching Firebase data
      final topics = await serviceLocator.content.getQuizTopics(
        licenseType,
        language,
        'IL' // Use 'IL' instead of lowercase 'all' to match Firebase data
      );
      
      print('Fetched ${topics.length} topics for exam');
      
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
      
      print('Total questions collected for exam: ${allQuestions.length}');
      
      // Shuffle and select random questions
      if (allQuestions.isEmpty) {
        return [];
      }
      
      final Random random = Random();
      allQuestions.shuffle(random);
      
      // Take the requested number of questions or all if less available
      return allQuestions.take(min(count, allQuestions.length)).toList();
    } catch (e) {
      print('Error fetching random questions: $e');
      return [];
    }
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
