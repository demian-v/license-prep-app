import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../models/quiz_topic.dart';
import '../../models/quiz_question.dart';
import '../../models/theory_module.dart';
import '../../models/practice_test.dart';
import '../../models/traffic_rule_topic.dart';
import '../service_locator.dart';
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

/// True when an error is the server refusing for lack of an active
/// subscription or trial (risk #3's entitlement gate), rather than a fault.
bool isEntitlementDenial(Object error) {
  final text = error.toString();
  return text.contains('permission-denied')
      && (text.contains('subscription') || text.contains('Anonymous'));
}

class FirebaseContentApi implements ContentApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  FirebaseContentApi(this._functionsClient);
  
  /// Map topic IDs and titles to their local asset paths with multilingual support
  String? _getTopicIconAsset(String topicId, String topicTitle) {
    final id = topicId.toLowerCase();
    final title = topicTitle.toLowerCase();
    
    // Primary method: Language-agnostic ID pattern matching
    if (id.endsWith('_01')) return 'assets/images/topic_icons/1_general_provision.png';
    if (id.endsWith('_02')) return 'assets/images/topic_icons/2_traffic_laws.png';
    if (id.endsWith('_03')) return 'assets/images/topic_icons/3_passenger_safety.png';
    if (id.endsWith('_04')) return 'assets/images/topic_icons/4_pedestrian_rights.png';
    if (id.endsWith('_05')) return 'assets/images/topic_icons/5_bicycles_and_motorcycles.png';
    if (id.endsWith('_06')) return 'assets/images/topic_icons/6_special_transportation_vehicles.png';
    if (id.endsWith('_07')) return 'assets/images/topic_icons/7_driving_difficult_conditions.png';
    if (id.endsWith('_08')) return 'assets/images/topic_icons/8_impaired_driving.png';
    if (id.endsWith('_09')) return 'assets/images/topic_icons/9_road_signs_markings.png';
    if (id.endsWith('_10')) return 'assets/images/topic_icons/10_insurance_responsibility.png';
    
    // Fallback: Multilingual keyword matching
    return _getIconByKeywords(id, title);
  }
  
  /// Fallback method for multilingual keyword-based icon matching
  String? _getIconByKeywords(String id, String title) {
    // Topic 1: General Provisions
    if (_matchesKeywords(id, title, [
      'general', 'provision', 'disposiciones', 'generales', 'загальн', 'положення',
      'ogólne', 'przepisy', 'общие', 'положения'
    ])) {
      return 'assets/images/topic_icons/1_general_provision.png';
    }
    
    // Topic 2: Traffic Laws
    if (_matchesKeywords(id, title, [
      'traffic', 'law', 'leyes', 'tránsito', 'transito', 'правила', 'дорожн',
      'prawo', 'ruchu', 'дорожного', 'движения'
    ])) {
      return 'assets/images/topic_icons/2_traffic_laws.png';
    }
    
    // Topic 3: Passenger Safety
    if (_matchesKeywords(id, title, [
      'passenger', 'safety', 'seguridad', 'pasajeros', 'безпека', 'пасажир',
      'bezpieczeństwo', 'pasażer', 'безопасность', 'пассажир'
    ])) {
      return 'assets/images/topic_icons/3_passenger_safety.png';
    }
    
    // Topic 4: Pedestrian Rights
    if (_matchesKeywords(id, title, [
      'pedestrian', 'right', 'derechos', 'peatones', 'пішохід', 'права',
      'piesi', 'prawa', 'пешеход', 'права'
    ])) {
      return 'assets/images/topic_icons/4_pedestrian_rights.png';
    }
    
    // Topic 5: Bicycles and Motorcycles
    if (_matchesKeywords(id, title, [
      'bicycle', 'motorcycle', 'bicicletas', 'motocicletas', 'велосипед', 'мотоцикл',
      'rower', 'motocykl', 'велосипед', 'мотоцикл'
    ])) {
      return 'assets/images/topic_icons/5_bicycles_and_motorcycles.png';
    }
    
    // Topic 6: Special Transportation Vehicles
    if (_matchesKeywords(id, title, [
      'special', 'transport', 'vehículos', 'transporte', 'especiales',
      'спеціальн', 'транспорт', 'specjalne', 'pojazdy', 'специальн', 'транспорт'
    ])) {
      return 'assets/images/topic_icons/6_special_transportation_vehicles.png';
    }
    
    // Topic 7: Driving in Difficult Conditions
    if (_matchesKeywords(id, title, [
      'driving', 'difficult', 'conducir', 'condiciones', 'difíciles',
      'водіння', 'складн', 'prowadzenie', 'trudnych', 'вождение', 'сложн'
    ])) {
      return 'assets/images/topic_icons/7_driving_difficult_conditions.png';
    }
    
    // Topic 8: Impaired Driving
    if (_matchesKeywords(id, title, [
      'impaired', 'alcohol', 'conducir', 'efectos', 'alcohol',
      'сп\'янілий', 'алкоголь', 'prowadzenie', 'alkohol', 'пьяный', 'алкоголь'
    ])) {
      return 'assets/images/topic_icons/8_impaired_driving.png';
    }
    
    // Topic 9: Road Signs and Markings
    if (_matchesKeywords(id, title, [
      'road', 'sign', 'marking', 'señales', 'marcas', 'viales',
      'дорожн', 'знак', 'розмітка', 'znaki', 'oznakowanie', 'дорожные', 'знаки'
    ])) {
      return 'assets/images/topic_icons/9_road_signs_markings.png';
    }
    
    // Topic 10: Insurance and Responsibility
    if (_matchesKeywords(id, title, [
      'insurance', 'responsibility', 'seguros', 'responsabilidad',
      'страхування', 'відповідальність', 'ubezpieczenia', 'odpowiedzialność',
      'страхование', 'ответственность'
    ])) {
      return 'assets/images/topic_icons/10_insurance_responsibility.png';
    }
    
    return null; // No match found
  }
  
  /// Helper method to check if any keywords match in ID or title
  bool _matchesKeywords(String id, String title, List<String> keywords) {
    for (String keyword in keywords) {
      if (id.contains(keyword) || title.contains(keyword)) {
        return true;
      }
    }
    return false;
  }
  
  /// Helper method to convert Firebase Functions data to Firestore-compatible format
  /// This allows us to reuse the working Firestore processing logic
  Map<String, dynamic> _convertFirebaseFunctionData(Map<dynamic, dynamic> rawData) {
    final Map<String, dynamic> convertedData = {};
    
    rawData.forEach((key, value) {
      final String stringKey = key.toString();
      
      if (value == null) {
        convertedData[stringKey] = null;
      } else if (value is Map) {
        // Recursively convert nested maps (like sections)
        convertedData[stringKey] = _convertFirebaseFunctionData(Map<dynamic, dynamic>.from(value));
      } else if (value is List) {
        // Convert lists that may contain maps (like sections array)
        convertedData[stringKey] = value.map((item) {
          if (item is Map) {
            return _convertFirebaseFunctionData(Map<dynamic, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        // Keep primitive types as-is
        convertedData[stringKey] = value;
      }
    });
    
    return convertedData;
  }
  
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
  
  /// Helper method to sort questions by their numeric ID suffix (for Learn by Topics)
  List<QuizQuestion> _sortQuestionsByNumericId(List<QuizQuestion> questions) {
    questions.sort((a, b) {
      final aNum = _extractNumericSuffixFromQuestionId(a.id);
      final bNum = _extractNumericSuffixFromQuestionId(b.id);
      return aNum.compareTo(bNum);
    });
    return questions;
  }
  
  /// Helper method to extract numeric suffix from question ID
  int _extractNumericSuffixFromQuestionId(String questionId) {
    // Extract numeric part from IDs like "q_il_en_duties_01" -> 1
    final regex = RegExp(r'_(\d+)$');
    final match = regex.firstMatch(questionId);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
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
      
      // 🔍 STEP 1: Check cache first
      print('💾 [CACHE CHECK] Checking for cached quiz topics...');
      final cachedTopics = await serviceLocator.quizCache.getCachedQuizTopics(stateValue, language);
      
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        print('💾 [CACHE HIT] Using ${cachedTopics.length} cached quiz topics');
        print('🎉 Returning cached topics:');
        for (int i = 0; i < cachedTopics.length; i++) {
          print('   ${i + 1}. ${cachedTopics[i].id} - ${cachedTopics[i].title}');
        }
        return cachedTopics;
      }
      
      print('📭 [CACHE MISS] No cached topics found, fetching from Firebase...');
      
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
                iconAsset: _getTopicIconAsset(topicId, title),
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
        // Risk #3 follow-up — an entitlement refusal is not a transient error.
        // Falling through to the direct Firestore fallback below is pointless
        // (the rules require the same entitlement and deny it too) and, worse,
        // it converts a clear "you need a subscription" into an empty list that
        // every screen then reports as missing content. Let it propagate.
        if (isEntitlementDenial(e)) rethrow;
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
                  iconAsset: _getTopicIconAsset(topicId, title),
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
      
      // 💾 STEP 3: Cache the results if we got any topics
      if (processedTopics.isNotEmpty) {
        print('💾 [CACHE SAVE] Caching ${processedTopics.length} topics for future use...');
        await serviceLocator.quizCache.cacheQuizTopics(processedTopics, stateValue, language);
        print('✅ [CACHE SAVE] Topics successfully cached');
      }
      
      return processedTopics;
    } catch (e) {
      print('💥 Critical error fetching quiz topics: $e');
      print('📍 Stack trace: ${StackTrace.current}');
      // Risk #3 follow-up — an entitlement refusal must reach the caller.
      // Returning [] here turns "you need a subscription" into "no content".
      if (isEntitlementDenial(e)) rethrow;
      
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
      
      // 🔍 STEP 1: Check cache first for questions of this topic
      print('💾 [CACHE CHECK] Checking for cached questions for topic: $topicId');
      final cachedQuestions = await serviceLocator.quizCache.getCachedPracticeQuestions(stateValue, language);
      
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        print('🔍 [DEBUG] Analyzing cached questions for topic matching...');
        print('🔍 [DEBUG] Target topicId: "$topicId"');
        print('🔍 [DEBUG] Total cached questions: ${cachedQuestions.length}');
        
        // Show all matching questions for the selected topic
        print('🔍 [DEBUG] Sample of cached questions (prioritized by relevance):');

        // Get ALL matching questions (no limit)
        final matchingQuestions = cachedQuestions.where((q) => q.topicId == topicId).toList();

        if (matchingQuestions.isEmpty) {
          print('🔍 [DEBUG] ⚠️ No matching questions found for "$topicId"');
        } else {
          // Display all matching questions
          for (int i = 0; i < matchingQuestions.length; i++) {
            final q = matchingQuestions[i];
            print('   ${i+1}. ${q.id} -> topicId: "${q.topicId}" ✅ MATCH');
          }
        }
        
        // Get unique topicIds from cache for analysis
        final uniqueTopicIds = cachedQuestions.map((q) => q.topicId).toSet().toList();
        print('🔍 [DEBUG] Unique topicIds in cache: ${uniqueTopicIds.join(", ")}');
        
        // Filter cached questions by topicId
        var topicQuestions = cachedQuestions.where((q) => q.topicId == topicId).toList();
        print('🔍 [DEBUG] Found ${topicQuestions.length} matching questions for topicId "$topicId"');
        
        if (topicQuestions.isNotEmpty) {
          print('💾 [CACHE HIT] Found ${topicQuestions.length} cached questions for topic $topicId');
          // Sort questions by numeric ID for Learn by Topics
          topicQuestions = _sortQuestionsByNumericId(topicQuestions);
          print('🔢 [SORT] Sorted cached questions by numeric ID for Learn by Topics');
          print('🎯 [CACHE HIT] Returning sorted questions: ${topicQuestions.map((q) => q.id).take(5).join(", ")}${topicQuestions.length > 5 ? "..." : ""}');
          return topicQuestions;
        }
        print('📭 [CACHE PARTIAL] Cache exists but no questions match topicId "$topicId"');
        print('📭 [CACHE ANALYSIS] This suggests a topicId format mismatch or missing data');
      }
      
      print('📭 [CACHE MISS] No cached questions for topic, fetching from Firebase...');
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
          // Sort Firebase Functions questions by numeric ID for Learn by Topics
          if (processedQuestions.isNotEmpty) {
            processedQuestions = _sortQuestionsByNumericId(processedQuestions);
            print('🔢 [SORT] Sorted Firebase Functions questions by numeric ID for Learn by Topics');
          }
        } else {
          print('❌ Firebase Functions returned empty response');
        }
      } catch (e) {
        print('❌ Error with Firebase Functions: $e');
        // Risk #3 follow-up — an entitlement refusal is not a transient error.
        // Falling through to the direct Firestore fallback below is pointless
        // (the rules require the same entitlement and deny it too) and, worse,
        // it converts a clear "you need a subscription" into an empty list that
        // every screen then reports as missing content. Let it propagate.
        if (isEntitlementDenial(e)) rethrow;
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
            var firestoreQuestions = <QuizQuestion>[];
            
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
              // Sort Firestore questions by numeric ID for Learn by Topics
              firestoreQuestions = _sortQuestionsByNumericId(firestoreQuestions);
              print('🔢 [SORT] Sorted Firestore questions by numeric ID for Learn by Topics');
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
      // Risk #3 follow-up — an entitlement refusal must reach the caller.
      // Returning [] here turns "you need a subscription" into "no content".
      if (isEntitlementDenial(e)) rethrow;
      
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
          
          // Enhanced processing using the reusable converter (same logic as Firestore)
          for (int i = 0; i < response.length; i++) {
            try {
              final item = response[i];
              final Map<dynamic, dynamic> rawData = item as Map<dynamic, dynamic>;
              
              // Use the new recursive converter to make Firebase Functions data compatible
              final Map<String, dynamic> data = _convertFirebaseFunctionData(rawData);
              
              final topicId = data['id']?.toString() ?? 'unknown';
              
              print('🔨 Processing topic $topicId:');
              
              // Now we can reuse the exact same working logic as Firestore! ✅
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
        // Risk #3 follow-up — an entitlement refusal is not a transient error.
        // Falling through to the direct Firestore fallback below is pointless
        // (the rules require the same entitlement and deny it too) and, worse,
        // it converts a clear "you need a subscription" into an empty list that
        // every screen then reports as missing content. Let it propagate.
        if (isEntitlementDenial(e)) rethrow;
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
      // Risk #3 follow-up — an entitlement refusal must reach the caller.
      // Returning [] here turns "you need a subscription" into "no content".
      if (isEntitlementDenial(e)) rethrow;
      
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
        // Risk #3 follow-up — an entitlement refusal is not a transient error.
        // Falling through to the direct Firestore fallback below is pointless
        // (the rules require the same entitlement and deny it too) and, worse,
        // it converts a clear "you need a subscription" into an empty list that
        // every screen then reports as missing content. Let it propagate.
        if (isEntitlementDenial(e)) rethrow;
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
      // Risk #3 follow-up — an entitlement refusal must reach the caller.
      // Returning [] here turns "you need a subscription" into "no content".
      if (isEntitlementDenial(e)) rethrow;
      
      // Return empty list instead of throwing
      return [];
    }
  }
  
  /// Preload all quiz questions for a given state and language into cache
  /// This method fetches ALL questions and caches them for quick access
  Future<void> preloadAllQuizQuestions(String state, String language) async {
    try {
      print('🔍 [PRELOAD] Checking cache status for quiz questions...');
      
      // Check if questions are already cached
      final cachedQuestions = await serviceLocator.quizCache.getCachedPracticeQuestions(state, language);
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        print('💾 [PRELOAD] Cache already contains ${cachedQuestions.length} questions - skipping preload');
        return;
      }
      
      print('📭 [PRELOAD] Cache empty - fetching all quiz questions for state=$state, language=$language');
      
      // Ensure language code is correct (use 'uk' for Ukrainian)
      if (language == 'ua') {
        language = 'uk';
        print('🔧 [PRELOAD] Corrected language code from ua to uk');
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
              print('⚠️ [PRELOAD] Using Firestore user state: "$userState" instead of "$stateValue"');
              stateValue = userState;
            }
          }
        }
      } catch (e) {
        print('❌ [PRELOAD] Error checking user state: $e');
      }
      
      // First attempt: Try Firebase Functions to get ALL questions
      List<QuizQuestion> allQuestions = [];
      
      try {
        print('📞 [PRELOAD] Attempting Firebase Functions: getPracticeQuestions (fetching ALL)');
        
        // Request a large number to get all available questions
        final response = await _functionsClient.callFunction<List<dynamic>>(
          'getPracticeQuestions',
          data: {
            'language': language,
            'state': stateValue,
            'count': 500, // Request more than we'll ever have
          },
        );
        
        if (response != null && response.isNotEmpty) {
          print('📋 [PRELOAD] Firebase Functions returned ${response.length} questions');
          
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
              
              allQuestions.add(question);
            } catch (e) {
              print('❌ [PRELOAD] Error processing question ${i + 1}: $e');
            }
          }
        }
      } catch (e) {
        print('❌ [PRELOAD] Firebase Functions error: $e');
      }
      
      // Fallback: Direct Firestore query if Firebase Functions failed
      if (allQuestions.isEmpty) {
        print('🚨 [PRELOAD] Firebase Functions failed, trying direct Firestore query...');
        
        try {
          final querySnapshot = await _firestore
              .collection('quizQuestions')
              .where('language', isEqualTo: language)
              .where('state', whereIn: [stateValue, 'ALL'])
              .get();
          
          print('📋 [PRELOAD] Direct Firestore found ${querySnapshot.docs.length} questions');
          
          for (var doc in querySnapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              
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
              print('❌ [PRELOAD] Error processing Firestore question: $e');
            }
          }
        } catch (e) {
          print('❌ [PRELOAD] Direct Firestore error: $e');
        }
      }
      
      // Cache the results if we got any questions
      if (allQuestions.isNotEmpty) {
        print('💾 [PRELOAD] Caching ${allQuestions.length} questions for future use...');
        await serviceLocator.quizCache.cachePracticeQuestions(allQuestions, stateValue, language);
        print('✅ [PRELOAD] Successfully pre-loaded and cached ${allQuestions.length} quiz questions');
      } else {
        print('⚠️ [PRELOAD] No questions found to cache');
      }
      
    } catch (e) {
      print('💥 [PRELOAD] Critical error during preload: $e');
      // Silent failure - app continues to work with regular fetching
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
      
      // 🔍 STEP 1: Check cache first
      print('💾 [CACHE CHECK] Checking for cached practice questions...');
      final cachedQuestions = await serviceLocator.quizCache.getCachedPracticeQuestions(stateValue, language);
      
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        print('💾 [CACHE HIT] Using ${cachedQuestions.length} cached questions');
        // Shuffle and return requested count
        final shuffled = List<QuizQuestion>.from(cachedQuestions)..shuffle();
        final selectedQuestions = shuffled.take(count).toList();
        print('🎯 Selected ${selectedQuestions.length} random questions from cache for practice/exam');
        return selectedQuestions;
      }
      
      print('📭 [CACHE MISS] No cached questions found, fetching from Firebase...');
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
