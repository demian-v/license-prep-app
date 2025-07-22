import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theory_module.dart';

/// Service for caching theory modules locally to reduce Firebase calls
class TheoryCacheService {
  static const String _CACHE_PREFIX = 'theory_modules_';
  static const String _META_PREFIX = 'theory_cache_meta_';
  static const String _TRAFFIC_TOPICS_PREFIX = 'traffic_topics_';
  static const String _TRAFFIC_META_PREFIX = 'traffic_cache_meta_';
  
  // Cache duration - theory content doesn't change often
  static const Duration _CACHE_DURATION = Duration(hours: 24);
  
  /// Generate cache key for theory modules
  String _generateCacheKey(String state, String language, String licenseType) {
    return '${_CACHE_PREFIX}${state}_${language}_${licenseType}';
  }
  
  /// Generate metadata key for theory modules cache
  String _generateMetaKey(String state, String language, String licenseType) {
    return '${_META_PREFIX}${state}_${language}_${licenseType}';
  }
  
  /// Generate cache key for traffic topics
  String _generateTrafficTopicsCacheKey(String state, String language) {
    return '${_TRAFFIC_TOPICS_PREFIX}${state}_${language}';
  }
  
  /// Generate metadata key for traffic topics cache
  String _generateTrafficTopicsMetaKey(String state, String language) {
    return '${_TRAFFIC_META_PREFIX}${state}_${language}';
  }
  
  /// Check if theory modules cache is valid for specific state+language+license
  Future<bool> isCacheValid(String state, String language, String licenseType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaKey = _generateMetaKey(state, language, licenseType);
      
      final metaJson = prefs.getString(metaKey);
      if (metaJson == null) {
        print('📋 No cache metadata found for ${state}_${language}_${licenseType}');
        return false;
      }
      
      final metadata = Map<String, dynamic>.from(jsonDecode(metaJson));
      final cachedTime = DateTime.parse(metadata['timestamp']);
      final now = DateTime.now();
      
      final isValid = now.difference(cachedTime) < _CACHE_DURATION;
      print('📋 Cache for ${state}_${language}_${licenseType}: ${isValid ? 'VALID' : 'EXPIRED'} (age: ${now.difference(cachedTime).inHours}h)');
      
      return isValid;
    } catch (e) {
      print('❌ Error checking cache validity: $e');
      return false;
    }
  }
  
  /// Store theory modules in cache with metadata
  Future<void> cacheTheoryModules(List<TheoryModule> modules, String state, String language, String licenseType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store modules data
      final cacheKey = _generateCacheKey(state, language, licenseType);
      final modulesJson = jsonEncode(modules.map((m) => m.toFirestore()).toList());
      await prefs.setString(cacheKey, modulesJson);
      
      // Store metadata
      final metaKey = _generateMetaKey(state, language, licenseType);
      final metadata = {
        'timestamp': DateTime.now().toIso8601String(),
        'state': state,
        'language': language,
        'licenseType': licenseType,
        'count': modules.length,
      };
      await prefs.setString(metaKey, jsonEncode(metadata));
      
      print('💾 Cached ${modules.length} theory modules for ${state}_${language}_${licenseType}');
    } catch (e) {
      print('❌ Error caching theory modules: $e');
    }
  }
  
  /// Retrieve cached theory modules
  Future<List<TheoryModule>?> getCachedTheoryModules(String state, String language, String licenseType) async {
    try {
      // Check if cache is valid first
      if (!await isCacheValid(state, language, licenseType)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(state, language, licenseType);
      
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        print('📋 No cached modules found for ${state}_${language}_${licenseType}');
        return null;
      }
      
      final List<dynamic> modulesList = jsonDecode(cachedJson);
      final modules = modulesList.map((moduleData) => 
        TheoryModule.fromFirestore(Map<String, dynamic>.from(moduleData), moduleData['id'])
      ).toList();
      
      print('✅ Retrieved ${modules.length} cached theory modules for ${state}_${language}_${licenseType}');
      return modules;
    } catch (e) {
      print('❌ Error retrieving cached theory modules: $e');
      return null;
    }
  }
  
  /// Check if traffic topics cache is valid
  Future<bool> isTrafficTopicsCacheValid(String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final metaKey = _generateTrafficTopicsMetaKey(state, language);
      
      final metaJson = prefs.getString(metaKey);
      if (metaJson == null) {
        print('📋 No traffic topics cache metadata found for ${state}_${language}');
        return false;
      }
      
      final metadata = Map<String, dynamic>.from(jsonDecode(metaJson));
      final cachedTime = DateTime.parse(metadata['timestamp']);
      final now = DateTime.now();
      
      final isValid = now.difference(cachedTime) < _CACHE_DURATION;
      print('📋 Traffic topics cache for ${state}_${language}: ${isValid ? 'VALID' : 'EXPIRED'} (age: ${now.difference(cachedTime).inHours}h)');
      
      return isValid;
    } catch (e) {
      print('❌ Error checking traffic topics cache validity: $e');
      return false;
    }
  }
  
  /// Cache traffic topics (topics are stored as Map<String, dynamic> from TrafficRuleTopic.toFirestore())
  Future<void> cacheTrafficTopics(List<dynamic> topics, String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Store topics data
      final cacheKey = _generateTrafficTopicsCacheKey(state, language);
      final topicsJson = jsonEncode(topics);
      await prefs.setString(cacheKey, topicsJson);
      
      // Store metadata
      final metaKey = _generateTrafficTopicsMetaKey(state, language);
      final metadata = {
        'timestamp': DateTime.now().toIso8601String(),
        'state': state,
        'language': language,
        'count': topics.length,
      };
      await prefs.setString(metaKey, jsonEncode(metadata));
      
      print('💾 Cached ${topics.length} traffic topics for ${state}_${language}');
    } catch (e) {
      print('❌ Error caching traffic topics: $e');
    }
  }
  
  /// Retrieve cached traffic topics
  Future<List<dynamic>?> getCachedTrafficTopics(String state, String language) async {
    try {
      // Check if cache is valid first
      if (!await isTrafficTopicsCacheValid(state, language)) {
        return null;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateTrafficTopicsCacheKey(state, language);
      
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson == null) {
        print('📋 No cached traffic topics found for ${state}_${language}');
        return null;
      }
      
      final List<dynamic> topics = jsonDecode(cachedJson);
      print('✅ Retrieved ${topics.length} cached traffic topics for ${state}_${language}');
      return topics;
    } catch (e) {
      print('❌ Error retrieving cached traffic topics: $e');
      return null;
    }
  }
  
  /// Clear specific theory modules cache entry
  Future<void> clearCache(String state, String language, String licenseType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cacheKey = _generateCacheKey(state, language, licenseType);
      final metaKey = _generateMetaKey(state, language, licenseType);
      
      await prefs.remove(cacheKey);
      await prefs.remove(metaKey);
      
      print('🗑️ Cleared cache for ${state}_${language}_${licenseType}');
    } catch (e) {
      print('❌ Error clearing specific cache: $e');
    }
  }
  
  /// Clear specific traffic topics cache entry
  Future<void> clearTrafficTopicsCache(String state, String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cacheKey = _generateTrafficTopicsCacheKey(state, language);
      final metaKey = _generateTrafficTopicsMetaKey(state, language);
      
      await prefs.remove(cacheKey);
      await prefs.remove(metaKey);
      
      print('🗑️ Cleared traffic topics cache for ${state}_${language}');
    } catch (e) {
      print('❌ Error clearing traffic topics cache: $e');
    }
  }
  
  /// Clear all theory-related caches
  Future<void> clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      // Find all keys that start with our cache prefixes
      final cacheKeys = keys.where((key) => 
        key.startsWith(_CACHE_PREFIX) || 
        key.startsWith(_META_PREFIX) ||
        key.startsWith(_TRAFFIC_TOPICS_PREFIX) ||
        key.startsWith(_TRAFFIC_META_PREFIX)
      ).toList();
      
      // Remove all cache keys
      for (final key in cacheKeys) {
        await prefs.remove(key);
      }
      
      print('🗑️ Cleared all theory caches (${cacheKeys.length} entries)');
    } catch (e) {
      print('❌ Error clearing all caches: $e');
    }
  }
  
  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final theoryCacheKeys = keys.where((key) => key.startsWith(_CACHE_PREFIX)).length;
      final theoryMetaKeys = keys.where((key) => key.startsWith(_META_PREFIX)).length;
      final trafficCacheKeys = keys.where((key) => key.startsWith(_TRAFFIC_TOPICS_PREFIX)).length;
      final trafficMetaKeys = keys.where((key) => key.startsWith(_TRAFFIC_META_PREFIX)).length;
      
      return {
        'theory_modules_cached': theoryCacheKeys,
        'theory_meta_entries': theoryMetaKeys,
        'traffic_topics_cached': trafficCacheKeys,
        'traffic_meta_entries': trafficMetaKeys,
        'total_cache_entries': theoryCacheKeys + theoryMetaKeys + trafficCacheKeys + trafficMetaKeys,
      };
    } catch (e) {
      print('❌ Error getting cache stats: $e');
      return {'error': e.toString()};
    }
  }
}
