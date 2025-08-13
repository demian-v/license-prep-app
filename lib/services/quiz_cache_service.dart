import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_topic.dart';
import '../models/quiz_question.dart';

/// Service for caching quiz data locally to reduce Firebase calls
class QuizCacheService {
  // Cache prefixes for different types of quiz data
  static const String _QUIZ_TOPICS_PREFIX = 'quiz_topics_';
  static const String _QUIZ_QUESTIONS_PREFIX = 'quiz_questions_';
  static const String _PRACTICE_QUESTIONS_PREFIX = 'practice_questions_';
  static const String _EXAM_QUESTIONS_PREFIX = 'exam_questions_';
  static const String _META_PREFIX = 'quiz_cache_meta_';
  
  // Cache duration - 24 hours like theory cache
  static const Duration _CACHE_DURATION = Duration(hours: 24);
  
  // Maximum questions to cache per topic
  static const int _MAX_QUESTIONS_PER_TOPIC = 100;
  
  
  /// Generate cache key for quiz topics
  String _generateTopicsCacheKey(String state, String language) {
    return '${_QUIZ_TOPICS_PREFIX}${state}_$language';
  }
  
  /// Generate metadata key for quiz topics cache
  String _generateTopicsMetaKey(String state, String language) {
    return '${_META_PREFIX}topics_${state}_$language';
  }
  
  /// Generate cache key for quiz questions by topic
  String _generateQuestionsCacheKey(String state, String language, String topicId) {
    // Clean topic ID to avoid issues with special characters
    final cleanTopicId = topicId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return '${_QUIZ_QUESTIONS_PREFIX}${state}_${language}_$cleanTopicId';
  }
  
  /// Generate metadata key for quiz questions cache
  String _generateQuestionsMetaKey(String state, String language, String topicId) {
    final cleanTopicId = topicId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return '${_META_PREFIX}questions_${state}_${language}_$cleanTopicId';
  }
  
  /// Generate cache key for practice questions
  String _generatePracticeCacheKey(String state, String language) {
    return '${_PRACTICE_QUESTIONS_PREFIX}${state}_$language';
  }
  
  /// Generate metadata key for practice questions cache
  String _generatePracticeMetaKey(String state, String language) {
    return '${_META_PREFIX}practice_${state}_$language';
  }
  
  /// Generate cache key for exam questions
  String _generateExamCacheKey(String state, String language) {
    return '${_EXAM_QUESTIONS_PREFIX}${state}_$language';
  }
  
  /// Generate metadata key for exam questions cache
  String _generateExamMetaKey(String state, String language) {
    return '${_META_PREFIX}exam_${state}_$language';
  }
  
  /// Check if cache is valid
  Future<bool> _isCacheValid(String metaKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(metaKey);
      
      if (metaJson == null) {
        print('📋 No cache metadata found for key: $metaKey');
        return false;
      }
      
      final metadata = Map<String, dynamic>.from(jsonDecode(metaJson));
      final cachedTime = DateTime.parse(metadata['timestamp']);
      final now = DateTime.now();
      
      final isValid = now.difference(cachedTime) < _CACHE_DURATION;
      print('📋 Cache for $metaKey: ${isValid ? 'VALID' : 'EXPIRED'} (age: ${now.difference(cachedTime).inHours}h)');
      
      return isValid;
    } catch (e) {
      print('❌ Error checking cache validity for $metaKey: $e');
      return false;
    }
  }
  
  /// Store metadata for cache entry
  Future<void> _storeMetadata(String metaKey, Map<String, dynamic> additionalData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metadata = {
        'timestamp': DateTime.now().toIso8601String(),
        ...additionalData,
      };
      await prefs.setString(metaKey, jsonEncode(metadata));
    } catch (e) {
      print('❌ Error storing metadata for $metaKey: $e');
    }
  }
  
  // ============= QUIZ TOPICS CACHING =============
  
  /// Check if quiz topics cache is valid
  Future<bool> isTopicsCacheValid(String state, String language) async {
    final metaKey = _generateTopicsMetaKey(state, language);
    return _isCacheValid(metaKey);
  }
  
  /// Cache quiz topics
  Future<void> cacheQuizTopics(List<QuizTopic> topics, String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store topics data
      final cacheKey = _generateTopicsCacheKey(state, language);
      final topicsData = topics.map((t) => {
        'id': t.id,
        'title': t.title,
        'questionCount': t.questionCount,
        'progress': t.progress,
        'questionIds': t.questionIds,
      }).toList();
      
      await prefs.setString(cacheKey, jsonEncode(topicsData));
      
      // Store metadata
      final metaKey = _generateTopicsMetaKey(state, language);
      await _storeMetadata(metaKey, {
        'state': state,
        'language': language,
        'count': topics.length,
      });
      
      print('💾 Cached ${topics.length} quiz topics for ${state}_$language');
    } catch (e) {
      print('❌ Error caching quiz topics: $e');
    }
  }
  
  /// Retrieve cached quiz topics
  Future<List<QuizTopic>?> getCachedQuizTopics(String state, String language) async {
    try {
      // Check if cache is valid first
      if (!await isTopicsCacheValid(state, language)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateTopicsCacheKey(state, language);
      
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        print('📋 No cached topics found for ${state}_$language');
        return null;
      }
      
      final List<dynamic> topicsList = jsonDecode(cachedJson);
      final topics = topicsList.map((topicData) {
        final data = Map<String, dynamic>.from(topicData);
        return QuizTopic(
          id: data['id'] ?? '',
          title: data['title'] ?? '',
          questionCount: data['questionCount'] ?? 0,
          progress: (data['progress'] ?? 0.0).toDouble(),
          questionIds: List<String>.from(data['questionIds'] ?? []),
        );
      }).toList();
      
      print('✅ Retrieved ${topics.length} cached quiz topics for ${state}_$language');
      return topics;
    } catch (e) {
      print('❌ Error retrieving cached quiz topics: $e');
      return null;
    }
  }
  
  // ============= QUIZ QUESTIONS CACHING =============
  
  /// Check if quiz questions cache is valid
  Future<bool> isQuestionsCacheValid(String state, String language, String topicId) async {
    final metaKey = _generateQuestionsMetaKey(state, language, topicId);
    return _isCacheValid(metaKey);
  }
  
  /// Cache quiz questions for a specific topic
  Future<void> cacheQuizQuestions(List<QuizQuestion> questions, String state, String language, String topicId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limit the number of questions to cache
      final questionsToCache = questions.take(_MAX_QUESTIONS_PER_TOPIC).toList();
      
      // Store questions data
      final cacheKey = _generateQuestionsCacheKey(state, language, topicId);
      final questionsData = questionsToCache.map((q) => {
        'id': q.id,
        'topicId': q.topicId,
        'questionText': q.questionText,
        'options': q.options,
        'correctAnswer': q.correctAnswer,
        'explanation': q.explanation,
        'ruleReference': q.ruleReference,
        'imagePath': q.imagePath,
        'type': q.type.toString().split('.').last,
      }).toList();
      
      await prefs.setString(cacheKey, jsonEncode(questionsData));
      
      // Store metadata
      final metaKey = _generateQuestionsMetaKey(state, language, topicId);
      await _storeMetadata(metaKey, {
        'state': state,
        'language': language,
        'topicId': topicId,
        'count': questionsToCache.length,
      });
      
      print('💾 Cached ${questionsToCache.length} quiz questions for topic $topicId (${state}_$language)');
    } catch (e) {
      print('❌ Error caching quiz questions: $e');
    }
  }
  
  /// Retrieve cached quiz questions for a specific topic
  Future<List<QuizQuestion>?> getCachedQuizQuestions(String state, String language, String topicId) async {
    try {
      // Check if cache is valid first
      if (!await isQuestionsCacheValid(state, language, topicId)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateQuestionsCacheKey(state, language, topicId);
      
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        print('📋 No cached questions found for topic $topicId (${state}_$language)');
        return null;
      }
      
      final List<dynamic> questionsList = jsonDecode(cachedJson);
      final questions = questionsList.map((questionData) {
        final data = Map<String, dynamic>.from(questionData);
        return QuizQuestion(
          id: data['id'] ?? '',
          topicId: data['topicId'] ?? '',
          questionText: data['questionText'] ?? '',
          options: List<String>.from(data['options'] ?? []),
          correctAnswer: data['correctAnswer'],
          explanation: data['explanation'],
          ruleReference: data['ruleReference'],
          imagePath: data['imagePath'],
          type: _parseQuestionType(data['type'] ?? 'singleChoice'),
        );
      }).toList();
      
      print('✅ Retrieved ${questions.length} cached quiz questions for topic $topicId');
      return questions;
    } catch (e) {
      print('❌ Error retrieving cached quiz questions: $e');
      return null;
    }
  }
  
  // ============= PRACTICE QUESTIONS CACHING =============
  
  /// Check if practice questions cache is valid
  Future<bool> isPracticeCacheValid(String state, String language) async {
    final metaKey = _generatePracticeMetaKey(state, language);
    return _isCacheValid(metaKey);
  }
  
  /// Cache practice questions
  Future<void> cachePracticeQuestions(List<QuizQuestion> questions, String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache all questions (no limit)
      final questionsToCache = questions;
      
      // Store questions data
      final cacheKey = _generatePracticeCacheKey(state, language);
      final questionsData = questionsToCache.map((q) => {
        'id': q.id,
        'topicId': q.topicId,
        'questionText': q.questionText,
        'options': q.options,
        'correctAnswer': q.correctAnswer,
        'explanation': q.explanation,
        'ruleReference': q.ruleReference,
        'imagePath': q.imagePath,
        'type': q.type.toString().split('.').last,
      }).toList();
      
      await prefs.setString(cacheKey, jsonEncode(questionsData));
      
      // Store metadata
      final metaKey = _generatePracticeMetaKey(state, language);
      await _storeMetadata(metaKey, {
        'state': state,
        'language': language,
        'count': questionsToCache.length,
      });
      
      print('💾 Cached ${questionsToCache.length} practice questions for ${state}_$language');
    } catch (e) {
      print('❌ Error caching practice questions: $e');
    }
  }
  
  /// Retrieve cached practice questions
  Future<List<QuizQuestion>?> getCachedPracticeQuestions(String state, String language) async {
    try {
      // Check if cache is valid first
      if (!await isPracticeCacheValid(state, language)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generatePracticeCacheKey(state, language);
      
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        print('📋 No cached practice questions found for ${state}_$language');
        return null;
      }
      
      final List<dynamic> questionsList = jsonDecode(cachedJson);
      final questions = questionsList.map((questionData) {
        final data = Map<String, dynamic>.from(questionData);
        return QuizQuestion(
          id: data['id'] ?? '',
          topicId: data['topicId'] ?? '',
          questionText: data['questionText'] ?? '',
          options: List<String>.from(data['options'] ?? []),
          correctAnswer: data['correctAnswer'],
          explanation: data['explanation'],
          ruleReference: data['ruleReference'],
          imagePath: data['imagePath'],
          type: _parseQuestionType(data['type'] ?? 'singleChoice'),
        );
      }).toList();
      
      print('✅ Retrieved ${questions.length} cached practice questions');
      return questions;
    } catch (e) {
      print('❌ Error retrieving cached practice questions: $e');
      return null;
    }
  }
  
  // ============= EXAM QUESTIONS CACHING =============
  
  /// Check if exam questions cache is valid
  Future<bool> isExamCacheValid(String state, String language) async {
    final metaKey = _generateExamMetaKey(state, language);
    return _isCacheValid(metaKey);
  }
  
  /// Cache exam questions
  Future<void> cacheExamQuestions(List<QuizQuestion> questions, String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store questions data
      final cacheKey = _generateExamCacheKey(state, language);
      final questionsData = questions.map((q) => {
        'id': q.id,
        'topicId': q.topicId,
        'questionText': q.questionText,
        'options': q.options,
        'correctAnswer': q.correctAnswer,
        'explanation': q.explanation,
        'ruleReference': q.ruleReference,
        'imagePath': q.imagePath,
        'type': q.type.toString().split('.').last,
      }).toList();
      
      await prefs.setString(cacheKey, jsonEncode(questionsData));
      
      // Store metadata
      final metaKey = _generateExamMetaKey(state, language);
      await _storeMetadata(metaKey, {
        'state': state,
        'language': language,
        'count': questions.length,
      });
      
      print('💾 Cached ${questions.length} exam questions for ${state}_$language');
    } catch (e) {
      print('❌ Error caching exam questions: $e');
    }
  }
  
  /// Retrieve cached exam questions
  Future<List<QuizQuestion>?> getCachedExamQuestions(String state, String language) async {
    try {
      // Check if cache is valid first
      if (!await isExamCacheValid(state, language)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateExamCacheKey(state, language);
      
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        print('📋 No cached exam questions found for ${state}_$language');
        return null;
      }
      
      final List<dynamic> questionsList = jsonDecode(cachedJson);
      final questions = questionsList.map((questionData) {
        final data = Map<String, dynamic>.from(questionData);
        return QuizQuestion(
          id: data['id'] ?? '',
          topicId: data['topicId'] ?? '',
          questionText: data['questionText'] ?? '',
          options: List<String>.from(data['options'] ?? []),
          correctAnswer: data['correctAnswer'],
          explanation: data['explanation'],
          ruleReference: data['ruleReference'],
          imagePath: data['imagePath'],
          type: _parseQuestionType(data['type'] ?? 'singleChoice'),
        );
      }).toList();
      
      print('✅ Retrieved ${questions.length} cached exam questions');
      return questions;
    } catch (e) {
      print('❌ Error retrieving cached exam questions: $e');
      return null;
    }
  }
  
  // ============= CACHE MANAGEMENT =============
  
  /// Clear specific quiz cache entry
  Future<void> clearQuizCache(String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear topics cache
      await prefs.remove(_generateTopicsCacheKey(state, language));
      await prefs.remove(_generateTopicsMetaKey(state, language));
      
      // Clear practice cache
      await prefs.remove(_generatePracticeCacheKey(state, language));
      await prefs.remove(_generatePracticeMetaKey(state, language));
      
      // Clear exam cache
      await prefs.remove(_generateExamCacheKey(state, language));
      await prefs.remove(_generateExamMetaKey(state, language));
      
      // Note: Topic-specific questions cache cleared separately when needed
      
      print('🗑️ Cleared quiz cache for ${state}_$language');
    } catch (e) {
      print('❌ Error clearing quiz cache: $e');
    }
  }
  
  /// Clear all quiz caches
  Future<void> clearAllQuizCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Find all keys that start with our quiz cache prefixes
      final cacheKeys = keys.where((key) => 
        key.startsWith(_QUIZ_TOPICS_PREFIX) || 
        key.startsWith(_QUIZ_QUESTIONS_PREFIX) ||
        key.startsWith(_PRACTICE_QUESTIONS_PREFIX) ||
        key.startsWith(_EXAM_QUESTIONS_PREFIX) ||
        (key.startsWith(_META_PREFIX) && (
          key.contains('topics_') || 
          key.contains('questions_') || 
          key.contains('practice_') ||
          key.contains('exam_')
        ))
      ).toList();
      
      // Remove all cache keys
      for (final key in cacheKeys) {
        await prefs.remove(key);
      }
      
      print('🗑️ Cleared all quiz caches (${cacheKeys.length} entries)');
    } catch (e) {
      print('❌ Error clearing all quiz caches: $e');
    }
  }
  
  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final topicsCacheKeys = keys.where((key) => key.startsWith(_QUIZ_TOPICS_PREFIX)).length;
      final questionsCacheKeys = keys.where((key) => key.startsWith(_QUIZ_QUESTIONS_PREFIX)).length;
      final practiceCacheKeys = keys.where((key) => key.startsWith(_PRACTICE_QUESTIONS_PREFIX)).length;
      final examCacheKeys = keys.where((key) => key.startsWith(_EXAM_QUESTIONS_PREFIX)).length;
      final metaKeys = keys.where((key) => 
        key.startsWith(_META_PREFIX) && (
          key.contains('topics_') || 
          key.contains('questions_') || 
          key.contains('practice_') ||
          key.contains('exam_')
        )
      ).length;
      
      return {
        'quiz_topics_cached': topicsCacheKeys,
        'quiz_questions_cached': questionsCacheKeys,
        'practice_questions_cached': practiceCacheKeys,
        'exam_questions_cached': examCacheKeys,
        'meta_entries': metaKeys,
        'total_quiz_cache_entries': topicsCacheKeys + questionsCacheKeys + practiceCacheKeys + examCacheKeys + metaKeys,
      };
    } catch (e) {
      print('❌ Error getting quiz cache stats: $e');
      return {'error': e.toString()};
    }
  }
  
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
  
  /// Batch cache check for better performance
  Future<Map<String, bool>> checkBatchCacheStatus(String state, String language) async {
    try {
      final topicsValid = await isTopicsCacheValid(state, language);
      final practiceValid = await isPracticeCacheValid(state, language);
      final examValid = await isExamCacheValid(state, language);
      
      return {
        'topics_cache_valid': topicsValid,
        'practice_cache_valid': practiceValid,
        'exam_cache_valid': examValid,
        'any_valid': topicsValid || practiceValid || examValid,
        'all_valid': topicsValid && practiceValid && examValid,
      };
    } catch (e) {
      print('❌ Error checking batch cache status: $e');
      return {
        'topics_cache_valid': false,
        'practice_cache_valid': false,
        'exam_cache_valid': false,
        'any_valid': false,
        'all_valid': false,
      };
    }
  }
}
