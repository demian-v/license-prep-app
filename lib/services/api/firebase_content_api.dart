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
        print('📋 Raw Firebase Function Response:');
        print('   - Response type: ${response.runtimeType}');
        print('   - Response length: ${response?.length ?? 0}');
        
        if (response != null && response.isNotEmpty) {
          // Log each topic ID before filtering
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
          
          // Enhanced filtering with detailed logging
          print('🔍 Starting filtering process for language: $language');
          final List<Map<String, dynamic>> filteredResponse = [];
          
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
                (key, value) => MapEntry(key.toString(), value),
              ));
              
              final topicId = data['id']?.toString() ?? 'unknown';
              final topicLanguage = data['language']?.toString() ?? '';
              final topicState = data['state']?.toString() ?? '';
              
              print('   🔍 Checking topic $topicId:');
              print('     - Topic language: "$topicLanguage" vs Required: "$language"');
              print('     - Topic state: "$topicState"');
              
              // First, ensure the topic matches the user's language
              final languageMatches = (topicLanguage == language);
              
              if (!languageMatches) {
                print('     ❌ FILTERED OUT: Language mismatch');
                continue;
              }
              
              // Simplified state logic - let's be more permissive
              bool stateMatches = true;
              
              // Only filter out if there's a clear state mismatch
              if (topicState.isNotEmpty && stateValue != 'ALL' && topicState != 'ALL' && topicState != stateValue) {
                stateMatches = false;
              }
              
              if (!stateMatches) {
                print('     ❌ FILTERED OUT: State mismatch');
                continue;
              }
              
              print('     ✅ PASSED FILTERING');
              filteredResponse.add(data);
            } catch (e) {
              print('     ❌ Error filtering topic ${i + 1}: $e');
            }
          }
          
          print('✅ After filtering: ${filteredResponse.length} topics remain');
          
          // Enhanced processing with better error handling
          for (int i = 0; i < filteredResponse.length; i++) {
            try {
              final data = filteredResponse[i];
              final topicId = data['id']?.toString() ?? 'unknown';
              
              print('🔨 Processing topic $topicId:');
              
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
              
              print('   - Title: $title');
              print('   - Question Count: $questionCount');
              print('   - Question IDs: ${questionIds.length} items');
              
              final topic = QuizTopic(
                id: topicId,
                title: title,
                questionCount: questionCount,
                progress: progress,
                questionIds: questionIds,
              );
              
              processedTopics.add(topic);
              print('   ✅ Successfully processed topic $topicId');
              
            } catch (e) {
              print('   ❌ Error processing topic ${i + 1}: $e');
              print('   Raw data: ${filteredResponse[i]}');
              // Continue processing other topics instead of filtering out
            }
          }
          
          print('📊 Firebase Functions result: ${processedTopics.length} topics processed');
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
              print('IMPORTANT - Overriding state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('DEBUG - User document state: ${userData['state']}, Final state for query: $stateValue');
          }
        }
      } catch (e) {
        print('Error checking user state: $e');
      }
      
      print('Fetching quiz questions with: topicId=$topicId, language=$language, state=$stateValue');
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizQuestions',
        data: {
          'topicId': topicId,
          'language': language,
          'state': stateValue,
        },
      );
      
      // Debug output
      print('Received questions response: $response');
      
      if (response == null || response.isEmpty) {
        print('Questions response was empty, returning empty list');
        // Return empty list instead of fallback data
        return [];
      }
      
      return response.map((item) {
        try {
          // Handle different possible types coming from Firebase Functions
          final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
          // Convert to Map<String, dynamic>
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ));
          
          print('Processing question: ${data['id']}');
          
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
          
          print('Question ID: ${data['id']}, Correct Answer: $correctAnswer');
          
          return QuizQuestion(
            id: data['id'].toString(),
            topicId: data['topicId'].toString(),
            questionText: data['questionText'].toString(),
            options: options,
            correctAnswer: correctAnswer,
            explanation: data['explanation']?.toString(),
            ruleReference: data['ruleReference']?.toString(),
            imagePath: data['imagePath']?.toString(),
            type: data['type'] != null ? 
              _parseQuestionType(data['type'].toString()) : 
              QuestionType.singleChoice,
          );
        } catch (e) {
          print('Error processing question: $e');
          print('Raw item: $item');
          // Return null and filter out later
          return null;
        }
      })
      .where((question) => question != null) // Filter out null questions
      .cast<QuizQuestion>() // Cast non-null questions
      .toList();
    } catch (e) {
      print('Error fetching quiz questions: $e');
      print('Returning empty list');
      
      // Return empty list instead of fallback data
      return [];
    }
  }
  
  
  /// Get traffic rule topics from Firestore
  /// This is used for the direct Firestore approach
  @override
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String state) async {
    try {
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
              print('IMPORTANT - Overriding traffic topics state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('DEBUG - User document state: ${userData['state']}, Final state for traffic topics query: $stateValue');
          }
        }
      } catch (e) {
        print('Error checking user state for traffic topics: $e');
      }
      
      print('Fetching traffic rule topics from Firestore with: language=$language, state=$stateValue');
      
      // Query Firestore collection
      QuerySnapshot querySnapshot;
      
      querySnapshot = await _firestore
          .collection('trafficRuleTopics')
          .where('language', isEqualTo: language)
          .where('state', isEqualTo: stateValue)
          .orderBy('order')
          .get();
      
      print('Got ${querySnapshot.docs.length} traffic rule topics from Firestore');
      
      // Process results
      List<TrafficRuleTopic> topics = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return TrafficRuleTopic.fromFirestore(data, doc.id);
      }).toList();
      
      return topics;
    } catch (e) {
      print('Error fetching traffic rule topics from Firestore: $e');
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
              print('IMPORTANT - Overriding theory modules state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('DEBUG - User document state: ${userData['state']}, Final state for theory modules query: $stateValue');
          }
        }
      } catch (e) {
        print('Error checking user state for theory modules: $e');
      }
      
      print('Attempting to fetch theory modules with state=$stateValue, language=$language');
      
      List<TheoryModule> modules = [];
      
      // Try to get from Firestore directly first
      try {
        // Query Firestore collection
        print('Querying Firestore collection: theoryModules');
        print('Query parameters: language=$language, state=[${stateValue}, ALL], licenseId=$licenseType');
        
        QuerySnapshot querySnapshot = await _firestore
            .collection('theoryModules')
            .where('language', isEqualTo: language)
            .where('state', whereIn: [stateValue, 'ALL'])
            .where('licenseId', isEqualTo: licenseType)
            .orderBy('order')
            .get();
        
        print('Got ${querySnapshot.docs.length} theory modules from Firestore');
        
        // Process results
        if (querySnapshot.docs.isNotEmpty) {
          modules = querySnapshot.docs.map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              print('Processing module: ${data['id'] ?? doc.id} - ${data['title'] ?? 'No title'}');
              return TheoryModule.fromFirestore(data, doc.id);
            } catch (e) {
              print('Error processing module doc: $e');
              return null;
            }
          })
          .where((module) => module != null)
          .cast<TheoryModule>()
          .toList();
          
          if (modules.isNotEmpty) {
            print('Successfully processed ${modules.length} modules from Firestore');
            return modules;
          } else {
            print('No valid modules found in Firestore results');
          }
        } else {
          print('No theory modules found in Firestore');
        }
      } catch (e) {
        print('Error fetching theory modules from Firestore: $e');
        print('Will try Firebase Functions');
      }
      
      // Try to use Firebase Functions API as a fallback
      try {
        print('Attempting to use Firebase Functions API');
        final functionsResponse = await _functionsClient.callFunction<List<dynamic>>(
          'getTheoryModules',
          data: {
            'licenseType': licenseType,
            'language': language,
            'state': stateValue,
          },
        );
        
        if (functionsResponse != null && functionsResponse.isNotEmpty) {
          print('Received response from Firebase Functions');
          modules = functionsResponse.map((item) {
            try {
              if (item is Map) {
                // Convert to Map<String, dynamic> safely
                final Map<String, dynamic> data = Map<String, dynamic>.from(
                  (item as Map).map((key, value) => MapEntry(key.toString(), value))
                );
                
                return TheoryModule(
                  id: data['id'].toString(),
                  licenseId: data['licenseId'].toString(),
                  title: data['title'].toString(),
                  description: data['description'].toString(),
                  estimatedTime: (data['estimatedTime'] is int) 
                    ? data['estimatedTime'] as int 
                    : int.tryParse(data['estimatedTime'].toString()) ?? 30,
                  topics: data['topics'] is List 
                    ? List<String>.from(data['topics']) 
                    : <String>[],
                  language: data['language']?.toString() ?? language,
                  state: data['state']?.toString() ?? stateValue,
                  icon: data['icon']?.toString() ?? 'menu_book',
                  type: data['type']?.toString() ?? 'module',
                  order: (data['order'] is int) 
                    ? data['order'] as int 
                    : int.tryParse(data['order'].toString()) ?? 0,
                );
              }
              return null;
            } catch (e) {
              print('Error processing module from functions: $e');
              return null;
            }
          })
          .where((module) => module != null)
          .cast<TheoryModule>()
          .toList();
          
          if (modules.isNotEmpty) {
            print('Successfully processed ${modules.length} modules from Firebase Functions');
            return modules;
          } else {
            print('No valid modules found in Firebase Functions results');
          }
        } else {
          print('No results from Firebase Functions');
        }
      } catch (e) {
        print('Error fetching theory modules from Firebase Functions: $e');
      }
      
      // If we got here, return an empty list
      print('No theory modules found through any method, returning empty list');
      return [];
    } catch (e) {
      throw 'Failed to fetch theory modules: $e';
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
