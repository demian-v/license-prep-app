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
  
  /// Convenience method to check both theory modules AND traffic topics cache together
  /// Returns a map with both cache statuses for easier batch checking
  Future<Map<String, dynamic>> getBatchCacheStatus(String state, String language, String licenseType) async {
    try {
      final modulesValid = await isCacheValid(state, language, licenseType);
      final topicsValid = await isTrafficTopicsCacheValid(state, language);
      
      return {
        'modules_cache_valid': modulesValid,
        'topics_cache_valid': topicsValid,
        'both_valid': modulesValid && topicsValid,
        'state': state,
        'language': language,
        'license_type': licenseType,
      };
    } catch (e) {
      print('❌ Error checking batch cache status: $e');
      return {
        'error': e.toString(),
        'modules_cache_valid': false,
        'topics_cache_valid': false,
        'both_valid': false,
      };
    }
  }
  
  /// Search for a specific topic in cached data with PRIORITIZED ID variations
  Future<Map<String, dynamic>?> findCachedTopicById(String topicId, String state, String language) async {
    try {
      final cacheKey = _generateTrafficTopicsCacheKey(state, language);
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      
      print('🔧 CACHE SEARCH: topicId="$topicId", cacheKey="$cacheKey"');
      
      if (cachedData != null) {
        final List<dynamic> topics = jsonDecode(cachedData);
        print('🔧 Cache exists: ${topics.length} topics in $cacheKey');
        print('🔧 Topic IDs in cache: ${topics.map((t) => t['id']).toList()}');
        
        // PRIORITY 1: Extract simple numeric ID first (this is what's actually in cache!)
        final numericId = topicId
            .replaceAll('topic_', '')
            .replaceAll(RegExp(r'_[a-zA-Z]{2}_[A-Z]{2,3}$'), '') // Remove _en_IL suffix
            .replaceAll(RegExp(r'_[a-zA-Z]{2}$'), '') // Remove _en suffix
            .replaceAll(RegExp(r'_ALL$'), ''); // Remove _ALL suffix
        
        // Search for topic with PRIORITIZED ID variations
        final possibleIds = [
          numericId,                         // "1" ⭐ HIGHEST PRIORITY - this is what's in cache!
          topicId.replaceAll('topic_', ''),  // "1_en_IL" 
          topicId,                           // "topic_1_en_IL" - original search term
          'topic_$numericId',                // "topic_1"
          topicId.toLowerCase(),             // "topic_1_en_il"
          numericId.toLowerCase(),           // "1" (but lowercase, just in case)
        ];
        
        print('🔧 Trying ID variations: $possibleIds');
        
        // Search for exact match
        for (var topicData in topics) {
          if (topicData is Map<String, dynamic>) {
            final cachedId = topicData['id']?.toString() ?? '';
            print('🔧 Comparing against cached ID: "$cachedId"');
            
            for (int i = 0; i < possibleIds.length; i++) {
              final possibleId = possibleIds[i];
              print('🔧 [${i+1}/${possibleIds.length}] Comparing: "$possibleId" == "$cachedId"');
              
              if (cachedId == possibleId) {
                print('✅ EXACT MATCH FOUND: $cachedId (using variation: $possibleId)');
                return topicData;
              }
            }
          }
        }
        
        print('❌ No exact match found for any variation');
      } else {
        print('🔧 No cache data for: $cacheKey');
      }
      
      print('❌ Topic $topicId not found in persistent cache');
      return null;
    } catch (e) {
      print('❌ Error searching for cached topic: $e');
      return null;
    }
  }

  /// Get topic IDs that are available in cache (for debugging)
  Future<List<String>> getCachedTopicIds(String state, String language) async {
    try {
      final cachedTopics = await getCachedTrafficTopics(state, language);
      if (cachedTopics != null) {
        return cachedTopics
            .map((topic) => topic['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ Error getting cached topic IDs: $e');
      return [];
    }
  }

  /// Check if specific topic exists in cache
  Future<bool> hasTopicInCache(String topicId, String state, String language) async {
    final topicData = await findCachedTopicById(topicId, state, language);
    return topicData != null;
  }
  
  /// Helper method to get the traffic topics cache key (expose for direct access)
  String _getTrafficTopicsCacheKey(String state, String language) {
    return _generateTrafficTopicsCacheKey(state, language);
  }
  
  /// Enhanced search with state fallback - tries multiple state variations
  Future<Map<String, dynamic>?> findCachedTopicByIdWithFallback(String topicId, String state, String language) async {
    // State variations to try (in priority order)
    final stateVariations = [
      state,           // Current state (e.g., 'IL')
      'ALL',          // Universal fallback
      state.toUpperCase(), // Ensure uppercase
      state.toLowerCase(), // Try lowercase
    ].where((s) => s.isNotEmpty).toSet().toList(); // Remove duplicates and empty

    for (var stateVariation in stateVariations) {
      print('🔍 Trying cache lookup: state=$stateVariation, language=$language, topicId=$topicId');
      
      final result = await findCachedTopicById(topicId, stateVariation, language);
      if (result != null) {
        print('✅ Found topic in cache with state variation: $stateVariation');
        return result;
      }
    }
    
    print('❌ Topic not found in cache after trying all state variations: $stateVariations');
    return null;
  }
  
  /// Debug method to list all available cache keys
  Future<List<String>> getAllCacheKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final trafficCacheKeys = keys
          .where((key) => key.startsWith(_TRAFFIC_TOPICS_PREFIX))
          .toList();
      
      print('🗂️ Available traffic cache keys: $trafficCacheKeys');
      return trafficCacheKeys;
    } catch (e) {
      print('❌ Error getting cache keys: $e');
      return [];
    }
  }

  /// Debug method to inspect specific cache key contents
  Future<Map<String, dynamic>> inspectCacheKey(String state, String language) async {
    try {
      final cacheKey = _generateTrafficTopicsCacheKey(state, language);
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        final List<dynamic> topics = jsonDecode(cachedData);
        final topicIds = topics
            .map((topic) => topic['id']?.toString() ?? 'no-id')
            .toList();
        
        return {
          'cacheKey': cacheKey,
          'exists': true,
          'topicCount': topics.length,
          'topicIds': topicIds,
        };
      } else {
        return {
          'cacheKey': cacheKey,
          'exists': false,
          'topicCount': 0,
          'topicIds': [],
        };
      }
    } catch (e) {
      return {
        'error': e.toString(),
        'cacheKey': _generateTrafficTopicsCacheKey(state, language),
        'exists': false,
      };
    }
  }
}
