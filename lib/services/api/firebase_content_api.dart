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
  
  /// Get quiz topics based on license type, language, and state
  @override
  Future<List<QuizTopic>> getQuizTopics(String licenseType, String language, String state) async {
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
              print('IMPORTANT - Overriding topic state parameter from "$stateValue" to Firestore user state: "$userState"');
              stateValue = userState;
            }
            
            print('DEBUG - User document state: ${userData['state']}, Final state for topics query: $stateValue');
          }
        }
      } catch (e) {
        print('Error checking user state for topics: $e');
      }
      
      print('Fetching quiz topics with: licenseType=$licenseType, language=$language, state=$stateValue');
      
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizTopics',
        data: {
          'licenseType': licenseType,
          'language': language,
          'state': stateValue,
        },
      );
      
      // Debug output
      print('Received response: $response');
      
      if (response == null || response.isEmpty) {
        print('Response was empty, returning empty list');
        // Return empty list instead of fallback data to ensure we only use Firebase data
        return [];
      }
      
      // Filter to ensure we only show topics matching the user's language
      // AND if state is "ALL", only show for appropriate language
      print('Filtering topics based on language: $language');
      final filteredResponse = response.where((item) {
        try {
          final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
          // Convert to Map<String, dynamic>
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ));
          
          // First, ensure the topic matches the user's language
          final topicLanguage = data['language']?.toString() ?? '';
          final languageMatches = (topicLanguage == language);
          
          if (!languageMatches) {
            return false;  // Skip if language doesn't match
          }
          
          // Then check state condition:
          // If ALL state, only show if language is "uk"
          final topicState = data['state']?.toString() ?? '';
          if (topicState == 'ALL') {
            return language == 'uk';  // Only show ALL state topics for Ukrainian
          }
          
          // For specific state topics, we've already confirmed language match above
          return true;
        } catch (e) {
          print('Error filtering topic: $e');
          return false;
        }
      }).toList();
      
      if (filteredResponse.isEmpty) {
        print('No topics match the language ($language) filter, returning empty list');
        return [];
      }
      
      return filteredResponse.map((item) {
        try {
          // Handle different possible types coming from Firebase Functions
          final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
          // Convert to Map<String, dynamic>
          final Map<String, dynamic> data = Map<String, dynamic>.from(rawData.map(
            (key, value) => MapEntry(key.toString(), value),
          ));
          
          print('Processing topic: ${data['id']} - ${data['title']}');
          
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
          
          return QuizTopic(
            id: data['id'].toString(),
            title: data['title'].toString(),
            questionCount: data['questionCount'] is int 
              ? data['questionCount'] as int 
              : int.tryParse(data['questionCount'].toString()) ?? 0,
            progress: data['progress'] != null ? 
              (data['progress'] is num ? 
                (data['progress'] as num).toDouble() : 
                double.tryParse(data['progress'].toString()) ?? 0.0) : 
              0.0,
            questionIds: questionIds,
          );
        } catch (e) {
          print('Error processing topic: $e');
          print('Raw item: $item');
          // Return null and filter out later
          return null;
        }
      })
      .where((topic) => topic != null) // Filter out null topics
      .cast<QuizTopic>() // Cast non-null topics
      .toList();
    } catch (e) {
      print('Error fetching quiz topics: $e');
      print('Returning empty list');
      
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
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String state, String licenseId) async {
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
      
      print('Fetching traffic rule topics from Firestore with: language=$language, state=$stateValue, licenseId=$licenseId');
      
      // Query Firestore collection
      QuerySnapshot querySnapshot;
      
      querySnapshot = await _firestore
          .collection('trafficRuleTopics')
          .where('language', isEqualTo: language)
          .where('state', whereIn: [stateValue, 'ALL'])
          .where('licenseId', isEqualTo: licenseId)
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
