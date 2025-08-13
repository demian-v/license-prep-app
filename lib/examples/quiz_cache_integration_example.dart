// Example of how to integrate quiz cache into Firebase Content API methods
// This example shows the pattern to follow for each method

import '../services/service_locator.dart';
import '../models/quiz_topic.dart';
import '../models/quiz_question.dart';

class QuizCacheIntegrationExample {
  
  /// Example: Adding cache to getQuizTopics method
  /// This shows the pattern - check cache first, fetch if needed, cache results
  Future<List<QuizTopic>> getQuizTopicsWithCache(String language, String state) async {
    try {
      // Step 1: Check cache first (BEFORE any Firebase/Firestore calls)
      print('🔍 Checking cache for quiz topics...');
      final cachedTopics = await serviceLocator.quizCache.getCachedQuizTopics(state, language);
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        print('💾 Cache HIT! Using ${cachedTopics.length} cached quiz topics');
        return cachedTopics;
      }
      print('📭 Cache MISS - fetching from Firebase/Firestore...');
      
      // Step 2: Your existing Firebase Functions + Firestore fallback logic
      List<QuizTopic> processedTopics = [];
      
      // Try Firebase Functions first (PRIMARY)
      try {
        // ... existing Firebase Functions code ...
        // processedTopics = await fetchFromFirebaseFunctions();
      } catch (e) {
        print('Firebase Functions failed: $e');
      }
      
      // Fallback to direct Firestore if needed (BACKUP)
      if (processedTopics.isEmpty) {
        try {
          // ... existing Firestore query code ...
          // processedTopics = await fetchFromFirestore();
        } catch (e) {
          print('Firestore query failed: $e');
        }
      }
      
      // Step 3: Cache the results before returning (if we got data)
      if (processedTopics.isNotEmpty) {
        print('💾 Caching ${processedTopics.length} topics for next time...');
        await serviceLocator.quizCache.cacheQuizTopics(processedTopics, state, language);
      }
      
      return processedTopics;
    } catch (e) {
      print('Error in getQuizTopicsWithCache: $e');
      return [];
    }
  }
  
  /// Example: Adding cache to getQuizQuestions method
  Future<List<QuizQuestion>> getQuizQuestionsWithCache(
    String topicId, 
    String language, 
    String state
  ) async {
    try {
      // Step 1: Check cache first
      print('🔍 Checking cache for quiz questions (topic: $topicId)...');
      final cachedQuestions = await serviceLocator.quizCache.getCachedQuizQuestions(
        state, 
        language, 
        topicId
      );
      
      if (cachedQuestions != null && cachedQuestions.isNotEmpty) {
        print('💾 Cache HIT! Using ${cachedQuestions.length} cached questions');
        return cachedQuestions;
      }
      print('📭 Cache MISS - fetching from Firebase/Firestore...');
      
      // Step 2: Existing fetching logic
      List<QuizQuestion> processedQuestions = [];
      // ... Firebase Functions + Firestore fallback ...
      
      // Step 3: Cache results
      if (processedQuestions.isNotEmpty) {
        print('💾 Caching ${processedQuestions.length} questions for topic $topicId...');
        await serviceLocator.quizCache.cacheQuizQuestions(
          processedQuestions, 
          state, 
          language, 
          topicId
        );
      }
      
      return processedQuestions;
    } catch (e) {
      print('Error in getQuizQuestionsWithCache: $e');
      return [];
    }
  }
  
  /// Example: Adding cache to getPracticeQuestions
  Future<List<QuizQuestion>> getPracticeQuestionsWithCache({
    required String language,
    required String state,
    required int count,
  }) async {
    try {
      // Step 1: Check cache first
      print('🔍 Checking cache for practice questions...');
      final cachedQuestions = await serviceLocator.quizCache.getCachedPracticeQuestions(
        state, 
        language
      );
      
      // If we have enough cached questions, use them
      if (cachedQuestions != null && cachedQuestions.length >= count) {
        print('💾 Cache HIT! Using cached practice questions');
        // Shuffle to provide variety even with cached questions
        final shuffled = List<QuizQuestion>.from(cachedQuestions)..shuffle();
        return shuffled.take(count).toList();
      }
      
      print('📭 Cache MISS or insufficient questions - fetching from Firebase...');
      
      // Step 2: Fetch from Firebase Functions
      List<QuizQuestion> processedQuestions = [];
      // ... existing Firebase Functions logic ...
      
      // Step 3: Cache ALL fetched questions (not just the requested count)
      // This way we can serve different counts from cache
      if (processedQuestions.isNotEmpty) {
        print('💾 Caching ${processedQuestions.length} practice questions...');
        await serviceLocator.quizCache.cachePracticeQuestions(
          processedQuestions, 
          state, 
          language
        );
      }
      
      return processedQuestions.take(count).toList();
    } catch (e) {
      print('Error in getPracticeQuestionsWithCache: $e');
      return [];
    }
  }
  
  /// Example: Cache invalidation on state change
  Future<void> handleStateChange(String oldState, String newState, String currentLanguage) async {
    print('🔄 State changed from $oldState to $newState - clearing quiz cache...');
    
    // Clear cache for the old state
    await serviceLocator.quizCache.clearQuizCache(oldState, currentLanguage);
    
    // Optionally, pre-fetch and cache data for the new state
    print('📥 Pre-fetching quiz data for new state: $newState...');
    await getQuizTopicsWithCache(currentLanguage, newState);
  }
  
  /// Example: Cache invalidation on language change
  Future<void> handleLanguageChange(String oldLanguage, String newLanguage, String currentState) async {
    print('🔄 Language changed from $oldLanguage to $newLanguage - clearing quiz cache...');
    
    // Clear cache for the old language
    await serviceLocator.quizCache.clearQuizCache(currentState, oldLanguage);
    
    // Optionally, pre-fetch and cache data for the new language
    print('📥 Pre-fetching quiz data for new language: $newLanguage...');
    await getQuizTopicsWithCache(newLanguage, currentState);
  }
  
  /// Example: Batch cache status check (useful for debugging)
  Future<void> checkCacheStatus(String state, String language) async {
    final status = await serviceLocator.quizCache.checkBatchCacheStatus(state, language);
    
    print('📊 Cache Status for $state/$language:');
    print('  - Topics cached: ${(status['topics_cache_valid'] == true) ? '✅' : '❌'}');
    print('  - Practice cached: ${(status['practice_cache_valid'] == true) ? '✅' : '❌'}');
    print('  - Exam cached: ${(status['exam_cache_valid'] == true) ? '✅' : '❌'}');
    print('  - Any valid: ${(status['any_valid'] == true) ? '✅' : '❌'}');
    print('  - All valid: ${(status['all_valid'] == true) ? '✅' : '❌'}');
    
    // Get detailed stats
    final stats = await serviceLocator.quizCache.getCacheStats();
    print('\n📈 Cache Statistics:');
    print('  - Quiz topics entries: ${stats['quiz_topics_cached']}');
    print('  - Quiz questions entries: ${stats['quiz_questions_cached']}');
    print('  - Practice questions entries: ${stats['practice_questions_cached']}');
    print('  - Exam questions entries: ${stats['exam_questions_cached']}');
    print('  - Total cache entries: ${stats['total_quiz_cache_entries']}');
  }
}

/// Integration pattern summary:
/// 
/// 1. CHECK CACHE FIRST
///    - Always check cache before any network calls
///    - Return cached data if valid
/// 
/// 2. FETCH IF NEEDED
///    - Keep all existing Firebase Functions logic
///    - Keep all existing Firestore fallback logic
///    - This maintains your backup mechanisms
/// 
/// 3. CACHE RESULTS
///    - Cache successful results before returning
///    - Don't cache empty results
/// 
/// 4. HANDLE ERRORS
///    - Cache operations should not break the flow
///    - Wrap cache calls in try-catch if needed
/// 
/// 5. INVALIDATE WHEN NEEDED
///    - Clear cache on state change
///    - Clear cache on language change
///    - Provide manual cache clear option
