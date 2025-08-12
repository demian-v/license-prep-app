import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../models/quiz_topic.dart';
import '../../models/quiz_question.dart';
import '../../models/theory_module.dart';
import '../../models/practice_test.dart';
import '../../models/traffic_rule_topic.dart';
import 'firebase_functions_client.dart';
import 'base/content_api_interface.dart';

/// Helper method to parse question type from string
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

class FirebaseContentApi implements ContentApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  FirebaseContentApi(this._functionsClient);
  
  /// Helper method to extract order from topic ID for sorting
  int _extractOrderFromId(String id) {
    // Extract numeric part from IDs like "q_topic_il_ua_01" -> 1
    final regex = RegExp(r'_(\d+)$');
    final match = regex.firstMatch(id);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }
  
  /// Get quiz topics based on language and state
  @override
  Future<List<QuizTopic>> getQuizTopics(String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('🔧 Corrected language code from ua to uk');
      }
      
      // Require specific state - no "ALL" fallback
      if (state == null || state.isEmpty) {
        print('🚫 State is required for quiz topics query');
        return [];
      }
      var stateValue = state;
      print('🏢 State value for Firebase query: $stateValue');
      
      // First try to get the user's state from Firestore to ensure we're using the most up-to-date value
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            // If the user has a state in Firestore, use that instead of the parameter
            if (userState != null && userState.isNotEmpty) {
              print('⚠️ IMPORTANT - Overriding topic state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('🔍 DEBUG - User document state: ${userData['state']}, Final state for topics query: $stateValue');
          }
        }
      } catch (e) {
        print('❌ Error checking user state for topics: $e');
      }
      
      // First attempt: Try Firebase Functions
      List<QuizTopic> processedTopics = [];
      
      try {
        print('📞 Attempting Firebase Functions: getQuizTopics with: language=$language, state=$stateValue');
        
        final response = await _functionsClient.callFunction<List<dynamic>>(
          'getQuizTopics',
          data: {
            'language': language,
            'state': stateValue,
            'limit': 10,
          },
        );
        
        // Enhanced debug output
        if (response != null && response.isNotEmpty) {
          print('📋 Firebase Function returned ${response.length} topics');
          
          // Process response directly without filtering (Firebase Function already filtered the data)
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              final topicId = data['id']?.toString() ?? 'unknown';
              
              // Safe extraction of questionIds
              List<String> questionIds = [];
              if (data['questionIds'] != null) {
                if (data['questionIds'] is List) {
                  questionIds = (data['questionIds'] as List)
                      .map((item) => item?.toString() ?? "")
                      .where((item) => item.trim().isNotEmpty)
                      .toList();
                }
              }
              
              // More robust data extraction
              final title = data['title']?.toString() ?? 'Untitled Topic';
              final questionCount = data['questionCount'] is int 
                ? data['questionCount'] as int 
                : int.tryParse(data['questionCount']?.toString() ?? '0') ?? 0;
              final progress = data['progress'] != null ? 
                (data['progress'] is num ? 
                  (data['progress'] as num).toDouble() : 
                  double.tryParse(data['progress'].toString()) ?? 0.0) : 
                0.0;
              
              final topic = QuizTopic(
                id: topicId,
                title: title,
                questionCount: questionCount,
                progress: progress,
                questionIds: questionIds,
              );
              
              processedTopics.add(topic);
              
            } catch (e) {
              print('❌ Error processing topic ${i + 1}: $e');
              // Continue processing other topics
            }
          }
          
          print('✅ Successfully processed ${processedTopics.length} topics from Firebase Functions');
        } else {
          print('❌ Firebase Functions returned empty response');
        }
      } catch (e) {
        print('❌ Error with Firebase Functions: $e');
      }
      
      // Second attempt: Direct Firestore query (especially if we got less than expected)
      // Try direct Firestore query for any language if Firebase Functions didn't work
      if (processedTopics.length == 0) {
        print('🚨 Got only ${processedTopics.length} topics from Firebase Functions, trying direct Firestore query...');
        
        try {
          print('📞 Attempting direct Firestore query: quizTopics collection');
          
          // Simplified query to avoid composite index requirement
          // We'll sort manually after fetching
          QuerySnapshot querySnapshot = await _firestore
              .collection('quizTopics')
              .where('language', isEqualTo: language)
              .where('state', isEqualTo: stateValue)
              .orderBy('order')
              .limit(10)
              .get();
          
          print('📋 Direct Firestore result: ${querySnapshot.docs.length} documents found (before state filtering)');
          
          if (querySnapshot.docs.isNotEmpty) {
            final List<QuizTopic> firestoreTopics = [];
            
            for (var doc in querySnapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final topicId = data['id']?.toString() ?? doc.id;
                final topicState = data['state']?.toString() ?? '';
                
                // Manual state filtering since we couldn't use it in the query
                bool includeThisTopic = false;
                if (topicState == 'ALL' || topicState == stateValue) {
                  includeThisTopic = true;
                } else if (stateValue == 'ALL') {
                  includeThisTopic = true;
                }
                
                if (!includeThisTopic) {
                  print('🔨 Skipping Firestore topic: $topicId - state mismatch ($topicState vs $stateValue)');
                  continue;
                }
                
                print('🔨 Processing Firestore topic: $topicId - ${data['title']} (state: $topicState)');
                
                // Safe extraction of questionIds
                List<String> questionIds = [];
                if (data['questionIds'] != null) {
                  if (data['questionIds'] is List) {
                    questionIds = (data['questionIds'] as List)
                        .map((item) => item?.toString() ?? "")
                        .where((item) => item.trim().isNotEmpty)
                        .toList();
                  }
                }
                
                final title = data['title']?.toString() ?? 'Untitled Topic';
                final questionCount = data['questionCount'] is int 
                  ? data['questionCount'] as int 
                  : int.tryParse(data['questionCount']?.toString() ?? '0') ?? 0;
                final progress = data['progress'] != null ? 
                  (data['progress'] is num ? 
                    (data['progress'] as num).toDouble() : 
                    double.tryParse(data['progress'].toString()) ?? 0.0) : 
                  0.0;
                
                final topic = QuizTopic(
                  id: topicId,
                  title: title,
                  questionCount: questionCount,
                  progress: progress,
                  questionIds: questionIds,
                );
                
                firestoreTopics.add(topic);
                print('   ✅ Successfully processed Firestore topic: $topicId');
                
              } catch (e) {
                print('   ❌ Error processing Firestore topic: $e');
              }
            }
            
            // Sort manually since we couldn't sort in the query
            firestoreTopics.sort((a, b) {
              // Extract order from ID if available, otherwise use title
              final aOrder = _extractOrderFromId(a.id);
              final bOrder = _extractOrderFromId(b.id);
              return aOrder.compareTo(bOrder);
            });
            
            if (firestoreTopics.length > processedTopics.length) {
              print('🎉 Firestore provided more topics (${firestoreTopics.length}) than Firebase Functions (${processedTopics.length}), using Firestore result');
              processedTopics = firestoreTopics;
            } else {
              print('📊 Firebase Functions result was better, keeping it');
            }
          } else {
            print('❌ No topics found in Firestore either');
          }
        } catch (e) {
          print('❌ Error querying Firestore directly: $e');
        }
      }
      
      print('🎉 Final result: ${processedTopics.length} topics successfully processed');
      for (int i = 0; i < processedTopics.length; i++) {
        print('   ${i + 1}. ${processedTopics[i].id} - ${processedTopics[i].title}');
      }
      
      return processedTopics;
    } catch (e) {
      print('💥 Critical error fetching quiz topics: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      
      // Return empty list instead of fallback data
      return [];
    }
  }
  
  /// Get quiz questions based on topic ID, language, and state
  @override
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('🔧 Corrected language code from ua to uk');
      }
      
      // If state is null or empty, we'll query without state filtering
      // This allows us to show the empty state UI when no state is selected
      var stateValue = (state == null || state.isEmpty) ? 'ALL' : state;
      print('🏢 State value for Firebase query: $stateValue (original value: $state)');
      
      // First try to get the user's state from Firestore to ensure we're using the most up-to-date value
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            // If the user has a state in Firestore, use that instead of the parameter
            if (userState != null && userState.isNotEmpty) {
              print('⚠️ IMPORTANT - Overriding questions state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('🔍 DEBUG - User document state: ${userData['state']}, Final state for questions query: $stateValue');
          }
        }
      } catch (e) {
        print('❌ Error checking user state for questions: $e');
      }
      
      print('🎯 Fetching quiz questions with: topicId=$topicId, language=$language, state=$stateValue');
      
      // First attempt: Try Firebase Functions (PRIMARY METHOD)
      List<QuizQuestion> processedQuestions = [];
      
      try {
        print('📞 Attempting Firebase Functions: getQuizQuestions with: topicId=$topicId, language=$language, state=$stateValue');
        
        final response = await _functionsClient.callFunction<List<dynamic>>(
          'getQuizQuestions',
          data: {
            'topicId': topicId,
            'language': language,
            'state': stateValue,
          },
        );
        
        // Enhanced debug output
        print('📋 Raw Firebase Function Response:');
        print('   - Response type: ${response.runtimeType}');
        print('   - Response length: ${response?.length ?? 0}');
        
        if (response != null && response.isNotEmpty) {
          // Log each question ID before filtering
          print('📝 Questions received from Firebase Function:');
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              print('   ${i + 1}. ${data['id']} - Topic: ${data['topicId']} (lang: ${data['language']}, state: ${data['state']})');
            } catch (e) {
              print('   ${i + 1}. ❌ Error reading question: $e');
            }
          }
          
          // Enhanced processing with better error handling
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              
              final questionId = data['id']?.toString() ?? 'unknown';
              
              print('🔨 Processing question $questionId:');
              
              // Safe extraction of options
              List<String> options = [];
              if (data['options'] != null) {
                if (data['options'] is List) {
                  options = (data['options'] as List)
                      .map((item) => item?.toString() ?? "")
                      .where((item) => item.isNotEmpty)
                      .toList();
                }
              }
              
              // Extract the correct answer value - checking multiple possible field names
              // Handle different formats (array or string)
              dynamic correctAnswer;
              if (data.containsKey('correctAnswers') && data['correctAnswers'] != null) {
                // If it's stored as an array in Firestore
                if (data['correctAnswers'] is List) {
                  correctAnswer = (data['correctAnswers'] as List)
                      .map((item) => item.toString())
                      .toList();
                }
              } else if (data.containsKey('correctAnswer') && data['correctAnswer'] != null) {
                correctAnswer = data['correctAnswer'].toString();
              } else if (data.containsKey('correctAnswerString') && data['correctAnswerString'] != null) {
                // For backward compatibility, split comma-separated values
                String answerStr = data['correctAnswerString'].toString();
                if (data['type']?.toString()?.toLowerCase() == 'multiplechoice') {
                  correctAnswer = answerStr.split(', ').map((s) => s.trim()).toList();
                } else {
                  correctAnswer = answerStr;
                }
              }
              
              // Safe text preview to avoid RangeError
              final questionText = data['questionText']?.toString() ?? 'No text';
              final preview = questionText.length > 50 ? questionText.substring(0, 50) + '...' : questionText;
              print('   - Question Text: $preview');
              print('   - Options: ${options.length} items');
              print('   - Correct Answer: $correctAnswer');
              
              final question = QuizQuestion(
                id: questionId,
                topicId: data['topicId']?.toString() ?? topicId,
                questionText: data['questionText']?.toString() ?? 'No question text',
                options: options,
                correctAnswer: correctAnswer,
                explanation: data['explanation']?.toString(),
                ruleReference: data['ruleReference']?.toString(),
                imagePath: data['imagePath']?.toString(),
                type: data['type'] != null ? 
                  _parseQuestionType(data['type'].toString()) : 
                  QuestionType.singleChoice,
              );
              
              processedQuestions.add(question);
              print('   ✅ Successfully processed question $questionId');
              
            } catch (e) {
              print('   ❌ Error processing question ${i + 1}: $e');
              print('   Raw data: ${response[i]}');
              // Continue processing other questions instead of failing completely
            }
          }
          
          print('📊 Firebase Functions result: ${processedQuestions.length} questions processed');
        } else {
          print('❌ Firebase Functions returned empty response');
        }
      } catch (e) {
        print('❌ Error with Firebase Functions: $e');
      }
      
      // Second attempt: Direct Firestore query (FALLBACK METHOD)
      if (processedQuestions.length == 0) {
        print('🚨 Got only ${processedQuestions.length} questions from Firebase Functions, trying direct Firestore query...');
        
        try {
          print('📞 Attempting direct Firestore query: quizQuestions collection');
          print('Query parameters: topicId=$topicId, language=$language, state=[${stateValue}, ALL]');
          
          QuerySnapshot querySnapshot = await _firestore
              .collection('quizQuestions')
              .where('topicId', isEqualTo: topicId)
              .where('language', isEqualTo: language)
              .where('state', whereIn: [stateValue, 'ALL'])
              .get();
          
          print('📋 Direct Firestore result: ${querySnapshot.docs.length} documents found');
          
          if (querySnapshot.docs.isNotEmpty) {
            final List<QuizQuestion> firestoreQuestions = [];
            
            for (var doc in querySnapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final questionId = data['id']?.toString() ?? doc.id;
                
                print('🔨 Processing Firestore question: $questionId - Topic: ${data['topicId']} (state: ${data['state']})');
                
                // Safe extraction of options
                List<String> options = [];
                if (data['options'] != null) {
                  if (data['options'] is List) {
                    options = (data['options'] as List)
                        .map((item) => item?.toString() ?? "")
                        .where((item) => item.isNotEmpty)
                        .toList();
                  }
                }
                
                // Extract the correct answer value - checking multiple possible field names
                dynamic correctAnswer;
                if (data.containsKey('correctAnswers') && data['correctAnswers'] != null) {
                  if (data['correctAnswers'] is List) {
                    correctAnswer = (data['correctAnswers'] as List)
                        .map((item) => item.toString())
                        .toList();
                  }
                } else if (data.containsKey('correctAnswer') && data['correctAnswer'] != null) {
                  correctAnswer = data['correctAnswer'].toString();
                } else if (data.containsKey('correctAnswerString') && data['correctAnswerString'] != null) {
                  String answerStr = data['correctAnswerString'].toString();
                  if (data['type']?.toString()?.toLowerCase() == 'multiplechoice') {
                    correctAnswer = answerStr.split(', ').map((s) => s.trim()).toList();
                  } else {
                    correctAnswer = answerStr;
                  }
                }
                
                final question = QuizQuestion(
                  id: questionId,
                  topicId: data['topicId']?.toString() ?? topicId,
                  questionText: data['questionText']?.toString() ?? 'No question text',
                  options: options,
                  correctAnswer: correctAnswer,
                  explanation: data['explanation']?.toString(),
                  ruleReference: data['ruleReference']?.toString(),
                  imagePath: data['imagePath']?.toString(),
                  type: data['type'] != null ? 
                    _parseQuestionType(data['type'].toString()) : 
                    QuestionType.singleChoice,
                );
                
                firestoreQuestions.add(question);
                print('   ✅ Successfully processed Firestore question: $questionId');
                
              } catch (e) {
                print('   ❌ Error processing Firestore question: $e');
              }
            }
            
            if (firestoreQuestions.length > processedQuestions.length) {
              print('🎉 Firestore provided more questions (${firestoreQuestions.length}) than Firebase Functions (${processedQuestions.length}), using Firestore result');
              processedQuestions = firestoreQuestions;
            } else {
              print('📊 Firebase Functions result was better, keeping it');
            }
          } else {
            print('❌ No questions found in Firestore either');
          }
        } catch (e) {
          print('❌ Error querying Firestore directly: $e');
        }
      }
      
      print('🎉 Final result: ${processedQuestions.length} questions successfully processed');
      for (int i = 0; i < processedQuestions.length && i < 5; i++) {
        final questionText = processedQuestions[i].questionText;
        final preview = questionText.length > 50 ? questionText.substring(0, 50) + '...' : questionText;
        print('   ${i + 1}. ${processedQuestions[i].id} - $preview');
      }
      if (processedQuestions.length > 5) {
        print('   ... and ${processedQuestions.length - 5} more questions');
      }
      
      return processedQuestions;
    } catch (e) {
      print('💥 Critical error fetching quiz questions: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      
      // Return empty list instead of throwing
      return [];
    }
  }
  
  /// Get a specific quiz question by ID
  @override
  Future<QuizQuestion?> getQuestionById(String questionId) async {
    try {
      print('🔍 Fetching question by document ID: $questionId');
      
      // Get document directly by ID (not by field query)
      final DocumentSnapshot docSnapshot = await _firestore
          .collection('quizQuestions')
          .doc(questionId)
          .get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        
        // Safe text preview to avoid RangeError
        final questionText = data['questionText']?.toString() ?? 'No text';
        final preview = questionText.length > 50 ? questionText.substring(0, 50) + '...' : questionText;
        print('✅ Found question: $questionId - $preview');
        
        // Safe extraction of options
        List<String> options = [];
        if (data['options'] != null && data['options'] is List) {
          options = (data['options'] as List)
              .map((item) => item?.toString() ?? "")
              .where((item) => item.isNotEmpty)
              .toList();
        }
        
        // Extract correct answer
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
        
        return QuizQuestion(
          id: questionId, // Use the document ID
          topicId: data['topicId'] ?? '',
          questionText: data['questionText'] ?? 'No question text',
          options: options,
          correctAnswer: correctAnswer,
          explanation: data['explanation']?.toString(),
          ruleReference: data['ruleReference']?.toString(),
          imagePath: data['imagePath']?.toString(),
          type: _parseQuestionType(data['type'] ?? 'singleChoice'),
        );
      }
      
      print('❌ Question document not found: $questionId');
      return null;
    } catch (e) {
      print('❌ Error fetching question by ID $questionId: $e');
      return null;
    }
  }
  
  /// Get traffic rule topics with Firebase Functions primary + Firestore fallback
  /// Enhanced to match theory modules 2-way fetching pattern
  @override
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('🔧 Corrected language code from ua to uk');
      }
      
      // If state is null or empty, we'll query without state filtering
      // This allows us to show the empty state UI when no state is selected
      var stateValue = (state == null || state.isEmpty) ? 'ALL' : state;
      print('🏢 State value for Firebase query: $stateValue (original value: $state)');
      
      // First try to get the user's state from Firestore to ensure we're using the most up-to-date value
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            // If the user has a state in Firestore, use that instead of the parameter
            if (userState != null && userState.isNotEmpty) {
              print('⚠️ IMPORTANT - Overriding traffic topics state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('🔍 DEBUG - User document state: ${userData['state']}, Final state for traffic topics query: $stateValue');
          }
        }
      } catch (e) {
        print('❌ Error checking user state for traffic topics: $e');
      }
      
      print('🎯 Fetching traffic rule topics with: language=$language, state=$stateValue');
      
      // First attempt: Try Firebase Functions (PRIMARY METHOD - NEW!)
      List<TrafficRuleTopic> processedTopics = [];
      
      try {
        print('📞 Attempting Firebase Functions: getTrafficRuleTopics with: language=$language, state=$stateValue');
        
        final response = await _functionsClient.callFunction<List<dynamic>>(
          'getTrafficRuleTopics',
          data: {
            'language': language,
            'state': stateValue,
          },
        );
        
        // Enhanced debug output
        print('📋 Raw Firebase Function Response:');
        print('   - Response type: ${response.runtimeType}');
        print('   - Response length: ${response?.length ?? 0}');
        
        if (response != null && response.isNotEmpty) {
          // Log each topic ID before processing
          print('📝 Topics received from Firebase Function:');
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              print('   ${i + 1}. ${data['id']} - ${data['title']} (lang: ${data['language']}, state: ${data['state']})');
            } catch (e) {
              print('   ${i + 1}. ❌ Error reading topic: $e');
            }
          }
          
          // Enhanced processing with better error handling
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              
              final topicId = data['id']?.toString() ?? 'unknown';
              
              print('🔨 Processing topic $topicId:');
              
              final topic = TrafficRuleTopic.fromFirestore(data, topicId);
              processedTopics.add(topic);
              print('   ✅ Successfully processed topic $topicId');
              
            } catch (e) {
              print('   ❌ Error processing topic ${i + 1}: $e');
              print('   Raw data: ${response[i]}');
              // Continue processing other topics instead of failing completely
            }
          }
          
          print('📊 Firebase Functions result: ${processedTopics.length} topics processed');
        } else {
          print('❌ Firebase Functions returned empty response');
        }
      } catch (e) {
        print('❌ Error with Firebase Functions: $e');
      }
      
      // Second attempt: Direct Firestore query (FALLBACK METHOD)
      if (processedTopics.length == 0) {
        print('🚨 Got only ${processedTopics.length} topics from Firebase Functions, trying direct Firestore query...');
        
        try {
          print('📞 Attempting direct Firestore query: trafficRuleTopics collection');
          print('Query parameters: language=$language, state=$stateValue');
          
          // Enhanced Firestore query - remove orderBy to avoid composite index issues
          QuerySnapshot querySnapshot = await _firestore
              .collection('trafficRuleTopics')
              .where('language', isEqualTo: language)
              .where('state', isEqualTo: stateValue)
              .get(); // Removed .orderBy('order') to avoid index issues
          
          print('📋 Direct Firestore result: ${querySnapshot.docs.length} documents found');
          
          if (querySnapshot.docs.isNotEmpty) {
            final List<TrafficRuleTopic> firestoreTopics = [];
            
            for (var doc in querySnapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final topicId = data['id']?.toString() ?? doc.id;
                
                print('🔨 Processing Firestore topic: $topicId - ${data['title']} (state: ${data['state']})');
                
                final topic = TrafficRuleTopic.fromFirestore(data, doc.id);
                firestoreTopics.add(topic);
                print('   ✅ Successfully processed Firestore topic: $topicId');
                
              } catch (e) {
                print('   ❌ Error processing Firestore topic: $e');
              }
            }
            
            // Manual sorting by order field since we removed orderBy from query
            firestoreTopics.sort((a, b) {
              final aOrder = a.order ?? 0;
              final bOrder = b.order ?? 0;
              return aOrder.compareTo(bOrder);
            });
            
            if (firestoreTopics.length > processedTopics.length) {
              print('🎉 Firestore provided more topics (${firestoreTopics.length}) than Firebase Functions (${processedTopics.length}), using Firestore result');
              processedTopics = firestoreTopics;
            } else {
              print('📊 Firebase Functions result was better, keeping it');
            }
          } else {
            print('❌ No topics found in Firestore either');
          }
        } catch (e) {
          print('❌ Error querying Firestore directly: $e');
        }
      }
      
      // Final result
      if (processedTopics.isEmpty) {
        print('⚠️ No traffic topics found - will show "Coming soon" message in UI');
      }
      
      print('🎉 Final result: ${processedTopics.length} traffic topics successfully processed');
      for (int i = 0; i < processedTopics.length; i++) {
        print('   ${i + 1}. ${processedTopics[i].id} - ${processedTopics[i].title}');
      }
      
      return processedTopics;
    } catch (e) {
      print('💥 Critical error fetching traffic rule topics: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      
      // Return empty list - UI will show "Coming soon" message
      return [];
    }
  }
  
  /// Get a specific traffic rule topic by ID from Firestore
  @override
  Future<TrafficRuleTopic?> getTrafficRuleTopic(String topicId) async {
    try {
      print('Fetching traffic rule topic from Firestore with ID: $topicId');
      
      DocumentSnapshot docSnapshot = await _firestore
          .collection('trafficRuleTopics')
          .doc(topicId)
          .get();
      
      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        return TrafficRuleTopic.fromFirestore(data, docSnapshot.id);
      }
      
      print('No topic found with ID: $topicId');
      return null;
    } catch (e) {
      print('Error fetching traffic rule topic from Firestore: $e');
      return null;
    }
  }

  /// Get theory modules based on license type, language, and state
  @override
  Future<List<TheoryModule>> getTheoryModules(String licenseType, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('🔧 Corrected language code from ua to uk');
      }
      
      // If state is null or empty, we'll query without state filtering
      // This allows us to show the empty state UI when no state is selected
      var stateValue = (state == null || state.isEmpty) ? 'ALL' : state;
      print('🏢 State value for Firebase query: $stateValue (original value: $state)');
      
      // First try to get the user's state from Firestore to ensure we're using the most up-to-date value
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            // If the user has a state in Firestore, use that instead of the parameter
            if (userState != null && userState.isNotEmpty) {
              print('⚠️ IMPORTANT - Overriding theory modules state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('🔍 DEBUG - User document state: ${userData['state']}, Final state for theory modules query: $stateValue');
          }
        }
      } catch (e) {
        print('❌ Error checking user state for theory modules: $e');
      }
      
      print('🎯 Attempting to fetch theory modules with state=$stateValue, language=$language, licenseType=$licenseType');
      
      // First attempt: Try Firebase Functions (PRIMARY METHOD)
      List<TheoryModule> processedModules = [];
      
      try {
        print('📞 Attempting Firebase Functions: getTheoryModules with: licenseType=$licenseType, language=$language, state=$stateValue');
        
        final response = await _functionsClient.callFunction<List<dynamic>>(
          'getTheoryModules',
          data: {
            'licenseType': licenseType,
            'language': language,
            'state': stateValue,
          },
        );
        
        // Enhanced debug output
        print('📋 Raw Firebase Function Response:');
        print('   - Response type: ${response.runtimeType}');
        print('   - Response length: ${response?.length ?? 0}');
        
        if (response != null && response.isNotEmpty) {
          // Log each module ID before filtering
          print('📝 Modules received from Firebase Function:');
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              print('   ${i + 1}. ${data['id']} - ${data['title']} (lang: ${data['language']}, state: ${data['state']})');
            } catch (e) {
              print('   ${i + 1}. ❌ Error reading module: $e');
            }
          }
          
          // Enhanced processing with better error handling
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              
              final moduleId = data['id']?.toString() ?? 'unknown';
              
              print('🔨 Processing module $moduleId:');
              
              // More robust data extraction
              final title = data['title']?.toString() ?? 'Untitled Module';
              final description = data['description']?.toString() ?? '';
              final estimatedTime = data['estimatedTime'] is int 
                ? data['estimatedTime'] as int 
                : int.tryParse(data['estimatedTime']?.toString() ?? '30') ?? 30;
              
              // Safe extraction of topics
              List<String> topics = [];
              if (data['topics'] != null) {
                if (data['topics'] is List) {
                  topics = (data['topics'] as List)
                      .map((item) => item?.toString() ?? "")
                      .where((item) => item.trim().isNotEmpty)
                      .toList();
                }
              }
              
              print('   - Title: $title');
              print('   - Description: $description');
              print('   - Estimated Time: $estimatedTime');
              print('   - Topics: ${topics.length} items');
              
              final module = TheoryModule(
                id: moduleId,
                licenseId: data['licenseId']?.toString() ?? licenseType,
                title: title,
                description: description,
                estimatedTime: estimatedTime,
                topics: topics,
                language: data['language']?.toString() ?? language,
                state: data['state']?.toString() ?? stateValue,
                icon: data['icon']?.toString() ?? 'menu_book',
                type: data['type']?.toString() ?? 'module',
                order: data['order'] is int 
                  ? data['order'] as int 
                  : int.tryParse(data['order']?.toString() ?? '0') ?? 0,
                theoryModulesCount: data['theory_modules_count']?.toString() ?? '0', // Map module count from Firebase Functions
              );
              
              processedModules.add(module);
              print('   ✅ Successfully processed module $moduleId');
              
            } catch (e) {
              print('   ❌ Error processing module ${i + 1}: $e');
              print('   Raw data: ${response[i]}');
              // Continue processing other modules instead of failing completely
            }
          }
          
          print('📊 Firebase Functions result: ${processedModules.length} modules processed');
        } else {
          print('❌ Firebase Functions returned empty response');
        }
      } catch (e) {
        print('❌ Error with Firebase Functions: $e');
      }
      
      // Second attempt: Direct Firestore query (FALLBACK METHOD)
      if (processedModules.length == 0) {
        print('🚨 Got only ${processedModules.length} modules from Firebase Functions, trying direct Firestore query...');
        
        try {
          print('📞 Attempting direct Firestore query: theoryModules collection');
          print('Query parameters: language=$language, state=[${stateValue}, ALL], licenseId=$licenseType');
          
          QuerySnapshot querySnapshot = await _firestore
              .collection('theoryModules')
              .where('language', isEqualTo: language)
              .where('state', whereIn: [stateValue, 'ALL'])
              .where('licenseId', isEqualTo: licenseType)
              .orderBy('order')
              .get();
          
          print('📋 Direct Firestore result: ${querySnapshot.docs.length} documents found');
          
          if (querySnapshot.docs.isNotEmpty) {
            final List<TheoryModule> firestoreModules = [];
            
            for (var doc in querySnapshot.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final moduleId = data['id']?.toString() ?? doc.id;
                
                print('🔨 Processing Firestore module: $moduleId - ${data['title']} (state: ${data['state']})');
                
                final module = TheoryModule.fromFirestore(data, doc.id);
                firestoreModules.add(module);
                print('   ✅ Successfully processed Firestore module: $moduleId');
                
              } catch (e) {
                print('   ❌ Error processing Firestore module: $e');
              }
            }
            
            if (firestoreModules.length > processedModules.length) {
              print('🎉 Firestore provided more modules (${firestoreModules.length}) than Firebase Functions (${processedModules.length}), using Firestore result');
              processedModules = firestoreModules;
            } else {
              print('📊 Firebase Functions result was better, keeping it');
            }
          } else {
            print('❌ No modules found in Firestore either');
          }
        } catch (e) {
          print('❌ Error querying Firestore directly: $e');
        }
      }
      
      print('🎉 Final result: ${processedModules.length} theory modules successfully processed');
      for (int i = 0; i < processedModules.length; i++) {
        print('   ${i + 1}. ${processedModules[i].id} - ${processedModules[i].title}');
      }
      
      return processedModules;
    } catch (e) {
      print('💥 Critical error fetching theory modules: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      
      // Return empty list instead of throwing
      return [];
    }
  }
  
  /// Get practice questions for random practice tests
  @override
  Future<List<QuizQuestion>> getPracticeQuestions({
    required String language,
    required String state,
    required int count,
  }) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('🔧 Corrected language code from ua to uk');
      }
      
      // Get user's state from Firestore for consistency
      var stateValue = state;
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            if (userState != null && userState.isNotEmpty) {
              print('⚠️ IMPORTANT - Overriding practice questions state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
          }
        }
      } catch (e) {
        print('❌ Error checking user state for practice questions: $e');
      }
      
      print('🎯 Fetching practice questions with Firebase Functions: language=$language, state=$stateValue, count=$count');
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getPracticeQuestions',
        data: {
          'language': language,
          'state': stateValue,
          'count': count,
        },
      );
      
      print('📋 Firebase Functions response: ${response?.length ?? 0} questions');
      
      if (response != null && response.isNotEmpty) {
        final List<QuizQuestion> processedQuestions = [];
        
        for (int i = 0; i < response.length; i++) {
          try {
            final item = response[i];
            final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
            final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
              (key, value) => MapEntry(key.toString(), value),
            ));
            
            // Safe extraction of options
            List<String> options = [];
            if (data['options'] != null && data['options'] is List) {
              options = (data['options'] as List)
                  .map((item) => item?.toString() ?? "")
                  .where((item) => item.isNotEmpty)
                  .toList();
            }
            
            // Extract correct answer
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
              id: data['id'] ?? 'unknown',
              topicId: data['topicId'] ?? '',
              questionText: data['questionText'] ?? 'No question text',
              options: options,
              correctAnswer: correctAnswer,
              explanation: data['explanation']?.toString(),
              ruleReference: data['ruleReference']?.toString(),
              imagePath: data['imagePath']?.toString(),
              type: _parseQuestionType(data['type'] ?? 'singleChoice'),
            );
            
            processedQuestions.add(question);
          } catch (e) {
            print('❌ Error processing practice question ${i + 1}: $e');
          }
        }
        
        print('✅ Processed ${processedQuestions.length} practice questions from Firebase Functions');
        return processedQuestions;
      }
      
      return [];
    } catch (e) {
      print('💥 Error fetching practice questions from Firebase Functions: $e');
      throw 'Failed to fetch practice questions: $e';
    }
  }
  
  /// Get practice tests based on license type, language, and state
  @override
  Future<List<PracticeTest>> getPracticeTests(String licenseType, String language, String state) async {
    try {
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('Corrected language code from ua to uk');
      }
      
      // If state is null or empty, we'll query without state filtering
      // This allows us to show the empty state UI when no state is selected
      var stateValue = (state == null || state.isEmpty) ? 'ALL' : state;
      print('State value for Firebase query: $stateValue (original value: $state)');
      
      // First try to get the user's state from Firestore to ensure we're using the most up-to-date value
      try {
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final userState = userData['state'] as String?;
            
            // If the user has a state in Firestore, use that instead of the parameter
            if (userState != null && userState.isNotEmpty) {
              print('IMPORTANT - Overriding practice tests state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('DEBUG - User document state: ${userData['state']}, Final state for practice tests query: $stateValue');
          }
        }
      } catch (e) {
        print('Error checking user state for practice tests: $e');
      }
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getPracticeTests',
        data: {
          'licenseType': licenseType,
          'language': language,
          'state': stateValue,
        },
      );
      
      return response.map((item) {
        final Map<String, dynamic> data = item as Map<String, dynamic>;
        return PracticeTest(
          id: data['id'] as String,
          licenseId: data['licenseId'] as String,
          title: data['title'] as String,
          description: data['description'] as String,
          questions: data['questionCount'] as int, // questionCount in API -> questions in model
          timeLimit: data['duration'] as int, // duration in API -> timeLimit in model
        );
      }).toList();
    } catch (e) {
      throw 'Failed to fetch practice tests: $e';
    }
  }
}
