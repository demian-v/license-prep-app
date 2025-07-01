import 'dart:math';
import 'dart:async';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    String language = 'uk',
    String state = 'all',
    String licenseType = 'driver',
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // STEP 1: Try Firebase Functions (PRIMARY METHOD)
      print('🚀 Starting two-tier exam question fetch...');
      List<QuizQuestion> examQuestions = await _fetchRandomQuestions_PRIMARY(
        language: language,
        state: state,
        licenseType: licenseType,
        count: 40,
      );
      
      // STEP 2: Fallback to direct Firestore if needed
      if (examQuestions.length < 40) {
        print('🚨 Got only ${examQuestions.length} questions from Firebase Functions, trying direct Firestore fallback...');
        
        final fallbackQuestions = await _fetchDirectRandomQuestions_FALLBACK(
          language: language,
          state: state,
          licenseType: licenseType,
          count: 40,
        );
        
        if (fallbackQuestions.length > examQuestions.length) {
          print('🎉 Fallback provided more questions (${fallbackQuestions.length}) than primary (${examQuestions.length}), using fallback result');
          examQuestions = fallbackQuestions;
        } else {
          print('📊 Primary method result was better, keeping it');
        }
      }
      
      // STEP 3: Validate results
      if (examQuestions.isEmpty) {
        _errorMessage = 'No questions found for your state and language. Please check your settings.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // STEP 4: Store questions locally and create exam
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
        timeLimit: 60, // 60 minutes - KEY DIFFERENCE FROM PRACTICE (which uses 0)
      );
      
      print('🎉 Exam created successfully with ${questionIds.length} questions');
      _isLoading = false;
      notifyListeners();
      
      // Start timer for UI updates - UNIQUE TO EXAM (Practice doesn't have this)
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
  
  // Helper method to parse question type from string
  QuestionType _parseQuestionType(String type) {
    switch (type.toLowerCase()) {
      case 'truefalse':
        return QuestionType.trueFalse;
      case 'multiplechoice':
        return QuestionType.multipleChoice;
      default:
        return QuestionType.singleChoice;
    }
  }
  
  // PRIMARY: Firebase Functions method to fetch random questions (for Take Exam)
  Future<List<QuizQuestion>> _fetchRandomQuestions_PRIMARY({
    required String language,
    required String state,
    required String licenseType,
    required int count,
  }) async {
    try {
      print('🎯 Primary fetch: language=$language, state=$state, count=$count');
      
      // Use Firebase Functions via service locator
      final examQuestions = await serviceLocator.content.getPracticeQuestions(
        language: language,
        state: state,
        count: count,
      );
      
      print('✅ Primary method result: ${examQuestions.length} questions');
      return examQuestions;
    } catch (e) {
      print('❌ Primary method error: $e');
      return [];
    }
  }
  
  // FALLBACK: Direct method to fetch random questions from Firestore (for Take Exam)
  Future<List<QuizQuestion>> _fetchDirectRandomQuestions_FALLBACK({
    required String language,
    required String state,
    required String licenseType,
    required int count,
  }) async {
    try {
      print('🎯 Direct fetch: language=$language, state=$state, count=$count');
      
      // Check user's state from Firestore for consistency
      var stateValue = state;
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            if (userState != null && userState.isNotEmpty) {
              print('🔧 Using user state from Firestore: $userState (overriding $stateValue)');
              stateValue = userState;
            }
          }
        }
      } catch (e) {
        print('⚠️ Could not check user state: $e, using provided state: $stateValue');
      }
      
      // Single Firestore query - no complex topic fetching
      final querySnapshot = await FirebaseFirestore.instance
          .collection('quizQuestions')
          .where('language', isEqualTo: language)
          .where('state', whereIn: [stateValue, 'ALL'])
          .get();
      
      print('📋 Direct query found ${querySnapshot.docs.length} questions');
      
      if (querySnapshot.docs.isEmpty) {
        print('❌ No questions found in direct query');
        return [];
      }
      
      // Convert to QuizQuestion objects
      final allQuestions = <QuizQuestion>[];
      
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          
          // Safe extraction of options
          List<String> options = [];
          if (data['options'] != null && data['options'] is List) {
            options = (data['options'] as List)
                .map((item) => item?.toString() ?? "")
                .where((item) => item.isNotEmpty)
                .toList();
          }
          
          // Extract the correct answer value
          dynamic correctAnswer;
          if (data['correctAnswers'] != null && data['correctAnswers'] is List) {
            correctAnswer = (data['correctAnswers'] as List)
                .map((item) => item.toString())
                .toList();
          } else if (data['correctAnswer'] != null) {
            correctAnswer = data['correctAnswer'].toString();
          } else if (data['correctAnswerString'] != null) {
            String answerStr = data['correctAnswerString'].toString();
            if (data['type']?.toString()?.toLowerCase() == 'multiplechoice') {
              correctAnswer = answerStr.split(', ').map((s) => s.trim()).toList();
            } else {
              correctAnswer = answerStr;
            }
          }
          
          final question = QuizQuestion(
            id: data['id'] ?? doc.id,
            topicId: data['topicId'] ?? '',
            questionText: data['questionText'] ?? 'No question text',
            options: options,
            correctAnswer: correctAnswer,
            explanation: data['explanation']?.toString(),
            ruleReference: data['ruleReference']?.toString(),
            imagePath: data['imagePath']?.toString(),
            type: _parseQuestionType(data['type'] ?? 'singleChoice'),
          );
          
          allQuestions.add(question);
        } catch (e) {
          print('❌ Error processing question ${doc.id}: $e');
        }
      }
      
      print('✅ Processed ${allQuestions.length} questions successfully');
      
      // Shuffle and take requested count
      if (allQuestions.isNotEmpty) {
        allQuestions.shuffle(Random());
        final selectedQuestions = allQuestions.take(min(count, allQuestions.length)).toList();
        print('🎲 Selected ${selectedQuestions.length} random questions for exam');
        return selectedQuestions;
      }
      
      return [];
      
    } catch (e) {
      print('❌ Direct fetch error: $e');
      return [];
    }
  }
  
  // OLD: Complex method (kept as backup) - fetches questions by topics first
  Future<List<QuizQuestion>> _fetchRandomQuestions_OLD({
    required String language,
    required String state,
    required String licenseType,
    required int count,
  }) async {
    try {
      print('Fetching random questions for exam with: language=$language, licenseType=$licenseType');
      
      // Get topics for the license type - Use 'IL' for state matching Firebase data
      final topics = await serviceLocator.content.getQuizTopics(
        language,
        state,
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
    
    // Always notify listeners every second so timer display updates in real-time
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
