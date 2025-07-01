import 'dart:math';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      
      // STEP 1: Try Firebase Functions (PRIMARY METHOD)
      print('🚀 Starting two-tier practice question fetch...');
      List<QuizQuestion> practiceQuestions = await _fetchRandomQuestions_PRIMARY(
        language: language,
        state: state,
        licenseType: licenseType,
        count: 40,
      );
      
      // STEP 2: Fallback to direct Firestore if needed
      if (practiceQuestions.length < 40) {
        print('🚨 Got only ${practiceQuestions.length} questions from Firebase Functions, trying direct Firestore fallback...');
        
        final fallbackQuestions = await _fetchDirectRandomQuestions_FALLBACK(
          language: language,
          state: state,
          licenseType: licenseType,
          count: 40,
        );
        
        if (fallbackQuestions.length > practiceQuestions.length) {
          print('🎉 Fallback provided more questions (${fallbackQuestions.length}) than primary (${practiceQuestions.length}), using fallback result');
          practiceQuestions = fallbackQuestions;
        } else {
          print('📊 Primary method result was better, keeping it');
        }
      }
      
      // STEP 3: Validate results
      if (practiceQuestions.isEmpty) {
        _errorMessage = 'No questions found for your state and language. Please check your settings.';
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      // STEP 4: Store questions locally and create practice test
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
      
      print('🎉 Practice test created successfully with ${questionIds.length} questions');
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
  
  // PRIMARY: Firebase Functions method to fetch random questions (for Practice Tickets)
  Future<List<QuizQuestion>> _fetchRandomQuestions_PRIMARY({
    required String language,
    required String state,
    required String licenseType,
    required int count,
  }) async {
    try {
      print('🎯 Primary fetch: language=$language, state=$state, count=$count');
      
      // Use Firebase Functions via service locator
      final practiceQuestions = await serviceLocator.content.getPracticeQuestions(
        language: language,
        state: state,
        count: count,
      );
      
      print('✅ Primary method result: ${practiceQuestions.length} questions');
      return practiceQuestions;
    } catch (e) {
      print('❌ Primary method error: $e');
      return [];
    }
  }
  
  // FALLBACK: Direct method to fetch random questions from Firestore (for Practice Tickets only)
  Future<List<QuizQuestion>> _fetchDirectRandomQuestions_FALLBACK({
    required String language,
    required String state,
    required String licenseType,
    required int count,
  }) async {
    try {
      print('🎯 Direct fetch: language=$language, state=$state, count=$count');
      
      // Check user's state from Firestore for consistency (like other methods)
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
        print('🎲 Selected ${selectedQuestions.length} random questions for practice');
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
      print('Fetching random questions for practice with: language=$language, state=$state, licenseType=$licenseType');
      
      // Get topics for the license type - Use 'IL' for state matching Firebase data
      final topics = await serviceLocator.content.getQuizTopics(
        language,
        state,
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
