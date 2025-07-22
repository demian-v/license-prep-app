import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/theory_module.dart';
import '../models/traffic_rule_topic.dart';
import '../services/service_locator.dart';
import '../services/theory_cache_service.dart';

class ContentProvider extends ChangeNotifier {
  bool _isLoading = false;
  List<TrafficRuleTopic> _topics = [];
  List<TheoryModule> _modules = [];
  String _currentLanguage = 'en'; // Default to English
  String? _currentState = null; // Default to null - no state selected
  String _currentLicenseId = 'driver';
  String? _lastError;
  bool _isOffline = false;
  
  // Connectivity instance
  final Connectivity _connectivity = Connectivity();
  
  // Cache service
  final TheoryCacheService _cacheService = serviceLocator.theoryCache;
  
  // Cache timestamps
  DateTime? _lastFetchTime;
  // Different cache durations based on content type
  final Duration _cacheValidityDuration = Duration(hours: 2);
  final Map<String, DateTime> _lastFetchTimes = {};
  
  // In-memory content caches
  final Map<String?, Map<String, List<TrafficRuleTopic>>> _topicCache = {}; // state -> language -> topics
  final Map<String?, Map<String, List<TheoryModule>>> _moduleCache = {}; // state -> language -> modules
  final Map<String, TrafficRuleTopic> _topicDetailCache = {}; // topicId -> topic
  
  // Getters
  bool get isLoading => _isLoading;
  List<TrafficRuleTopic> get topics => _topics;
  List<TheoryModule> get modules => _modules;
  String get currentLanguage => _currentLanguage;
  String? get currentState => _currentState;
  String get currentLicenseId => _currentLicenseId;
  String? get lastError => _lastError;
  bool get isOffline => _isOffline;
  
  // Check if cache is valid (enhanced with type-specific cache times)
  bool get isCacheValid {
    if (_lastFetchTime == null) return false;
    
    final now = DateTime.now();
    return now.difference(_lastFetchTime!) < _cacheValidityDuration;
  }
  
  // Check if a specific cache type is valid
  bool isCacheValidForType(String cacheType) {
    if (!_lastFetchTimes.containsKey(cacheType)) return false;
    
    final now = DateTime.now();
    final lastFetch = _lastFetchTimes[cacheType]!;
    
    // Different cache durations for different content types
    if (cacheType == 'topics') {
      return now.difference(lastFetch) < Duration(hours: 24); // Topics change less frequently
    } else if (cacheType == 'modules') {
      return now.difference(lastFetch) < Duration(hours: 6); // Modules might change more often
    }
    
    return now.difference(lastFetch) < _cacheValidityDuration; // Default
  }
  
  // Check if device is connected
  Future<bool> _isConnected() async {
    final result = await _connectivity.checkConnectivity();
    _isOffline = result == ConnectivityResult.none;
    return !_isOffline;
  }
  
  // Track if content loading has been explicitly requested
  bool _contentRequestedExplicitly = false;
  
  // Get whether content has been explicitly requested
  bool get contentRequestedExplicitly => _contentRequestedExplicitly;
  
  // Set user preferences
  void setPreferences({String? language, String? state, String? licenseId}) {
    bool shouldRefresh = false;
    
    // Store the UI language and use it for both UI and content
    if (language != null && language != _currentLanguage) {
      // Update the language for content
      _currentLanguage = language;
      print('ContentProvider: Language changed to $language for both UI and content');
      shouldRefresh = true; // Refresh content when language changes
    }
    
    // Store the selected state
    if (state != _currentState) {
      _currentState = state;
      print('ContentProvider: State changed to ${state ?? 'null'}');
      shouldRefresh = true; // Refresh content when state changes
    }
    
    if (licenseId != null && licenseId != _currentLicenseId) {
      _currentLicenseId = licenseId;
      shouldRefresh = true;
    }
    
    // IMPORTANT: Only fetch content if user is past the state selection screen
    // This prevents database calls during the language and state selection process
    if (shouldRefresh && _contentRequestedExplicitly) {
      print('ContentProvider: Fetching content due to preference change');
      fetchContent();
    } else {
      print('ContentProvider: Skipping content fetch (explicit request = $_contentRequestedExplicitly)');
      // Just notify listeners about the preference change without fetching content
      notifyListeners();
    }
  }
  
  // Fetch content explicitly after language and state selection
  Future<void> fetchContentAfterSelection({bool forceRefresh = false}) async {
    // Mark content as explicitly requested
    _contentRequestedExplicitly = true;
    
    // Clear any previous caches to ensure fresh content
    if (forceRefresh) {
      _clearRelevantCaches();
    }
    
    print('ContentProvider: fetchContentAfterSelection called with forceRefresh=$forceRefresh');
    print('ContentProvider: Current state=$_currentState, language=$_currentLanguage');
    
    // Now fetch the content
    return fetchContent(forceRefresh: forceRefresh);
  }
  
  // Get content for specific language and state (used only for special cases)
  Future<void> fetchContentForLanguageAndState(String language, String state, {bool forceRefresh = false}) async {
    String originalLanguage = _currentLanguage;
    String? originalState = _currentState;
    
    // Temporarily set the language and state
    _currentLanguage = language;
    _currentState = state;
    
    // Fetch the content
    await fetchContent(forceRefresh: forceRefresh);
    
    // Restore original values
    _currentLanguage = originalLanguage;
    _currentState = originalState;
  }
  
  // Clear caches when language or state changes
  void _clearRelevantCaches() {
    // We don't clear the entire cache, just the timestamp
    // so we force a refresh for the new language/state
    _lastFetchTime = null;
    _lastFetchTimes.remove('topics');
    _lastFetchTimes.remove('modules');
    
    // We keep the caches for other language/state combinations
    // in case user switches back
  }
  
  // Fetch all content
  Future<void> fetchContent({bool forceRefresh = false}) async {
    // 🏗️ NEW CACHING LOGIC - Check persistent cache first
    if (!forceRefresh) {
      final stateValue = _currentState ?? 'ALL';
      
      // Check if we have valid cached theory modules
      final cachedModules = await _cacheService.getCachedTheoryModules(
        stateValue, 
        _currentLanguage, 
        _currentLicenseId
      );
      
      if (cachedModules != null && cachedModules.isNotEmpty) {
        print('✅ Using cached theory modules for ${stateValue}_${_currentLanguage}_${_currentLicenseId}');
        _modules = cachedModules;
        _lastError = null;
        
        // Also check for cached traffic topics if we have a traffic rules module
        final trafficRulesModule = _modules.where((module) => module.type == 'traffic_rules').firstOrNull;
        if (trafficRulesModule != null) {
          final cachedTopics = await _cacheService.getCachedTrafficTopics(stateValue, _currentLanguage);
          if (cachedTopics != null) {
            print('✅ Using cached traffic topics for ${stateValue}_${_currentLanguage}');
            // Convert cached topics back to TrafficRuleTopic objects
            _topics = cachedTopics.map((topicData) {
              final Map<String, dynamic> data = Map<String, dynamic>.from(topicData);
              return TrafficRuleTopic.fromFirestore(data, data['id'] ?? '');
            }).toList();
          }
        }
        
        notifyListeners();
        return; // EXIT HERE - using cached data, no Firebase call needed
      }
    }
    
    // If we reach here, we need to fetch from Firebase (no cache or cache invalid or forced refresh)
    print('🔥 Fetching fresh data from Firebase - cache ${forceRefresh ? 'bypassed' : 'not available/invalid'}');
    
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    
    // Check connectivity
    final isConnected = await _isConnected();
    if (!isConnected) {
      if (_topics.isEmpty) {
        // If no cached data available, load hardcoded fallback
        loadHardcodedTopics();
        _lastError = 'Network connection unavailable. Loading cached content.';
      }
      _isLoading = false;
      notifyListeners();
      return;
    }
    
    try {
      // Get a reference to the service locator to use our interface with nullable state
      final contentService = serviceLocator.content;
      
      // Fetch theory modules using the updated API
      // Require specific state
      if (_currentState == null || _currentState!.isEmpty) {
        _lastError = 'State is required to fetch content';
        _isLoading = false;
        notifyListeners();
        return;
      }
      final stateValue = _currentState!;
      
      print('Fetching theory modules with: licenseId=$_currentLicenseId, language=$_currentLanguage, state=$stateValue');
      
      // Note: Corrected parameter order to match Firebase API
      _modules = await contentService.getTheoryModules(
        _currentLicenseId,  // licenseType should be first
        _currentLanguage,   // language second
        stateValue          // state third
      );
      
      // If no modules found and language isn't English, try English as fallback
      if (_modules.isEmpty && _currentLanguage != 'en') {
        print('No modules found in $_currentLanguage, trying English fallback');
        
        // Also fix the parameter order here
        _modules = await contentService.getTheoryModules(
          _currentLicenseId,  // licenseType should be first
          'en',               // language second
          stateValue          // state third
        );
      }
      
      // 💾 Cache the modules in persistent storage
      await _cacheService.cacheTheoryModules(_modules, stateValue, _currentLanguage, _currentLicenseId);
      
      // Cache the modules in memory too (for existing logic)
      if (!_moduleCache.containsKey(_currentState)) {
        _moduleCache[_currentState] = {};
      }
      _moduleCache[_currentState]![_currentLanguage] = _modules;
      
      // Update modules cache timestamp
      _lastFetchTimes['modules'] = DateTime.now();
      
      // Find traffic rules module
      TheoryModule? trafficRulesModule = _modules
          .where((module) => module.type == 'traffic_rules')
          .firstOrNull;
      
      // If we found the traffic rules module, fetch its topics
      if (trafficRulesModule != null) {
        // Fetch topics using the API with specific state
        print('Fetching traffic rule topics with: language=$_currentLanguage, state=$stateValue');
        
        _topics = await contentService.getTrafficRuleTopics(
          _currentLanguage, 
          stateValue
        );
        
        // If no topics found and language isn't English, try English as fallback
        if (_topics.isEmpty && _currentLanguage != 'en') {
          print('No topics found in $_currentLanguage, trying English fallback');
          
          print('Trying English fallback for topics: language=en, state=$stateValue');
          
          _topics = await contentService.getTrafficRuleTopics(
            'en', 
            stateValue
          );
        }
        
        // 💾 Cache the traffic topics in persistent storage
        await _cacheService.cacheTrafficTopics(
          _topics.map((topic) => topic.toFirestore()).toList(), 
          stateValue, 
          _currentLanguage
        );
        
        // Cache the topics in memory too (for existing logic)
        if (!_topicCache.containsKey(_currentState)) {
          _topicCache[_currentState] = {};
        }
        _topicCache[_currentState]![_currentLanguage] = _topics;
        
        // Update topics cache timestamp
        _lastFetchTimes['topics'] = DateTime.now();
      } else {
        _topics = [];
      }
      
      // Update general cache timestamp
      _lastFetchTime = DateTime.now();
    } catch (e) {
      _lastError = 'Error fetching content: $e';
      print(_lastError);
      
      if (_topics.isEmpty) {
        // If error occurred and no data is available, try loading hardcoded content
        loadHardcodedTopics();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Preload related content
  Future<void> preloadRelatedContent(String topicId) async {
    // Skip if offline
    if (_isOffline) return;
    
    try {
      // Get topic if not already in memory
      TrafficRuleTopic? topic = _topics.firstWhere(
        (t) => t.id == topicId || t.id == topicId.replaceAll('topic_', ''),
        orElse: () => null as TrafficRuleTopic,
      );
      
      if (topic == null) {
        topic = await getTopicById(topicId);
      }
      
      if (topic != null && _topics.isNotEmpty) {
        // Find related topics based on index
        final topicIndex = _topics.indexOf(topic);
        if (topicIndex >= 0 && topicIndex < _topics.length - 1) {
          // Preload next topic
          final nextTopicId = _topics[topicIndex + 1].id;
          getTopicById(nextTopicId);
        }
      }
    } catch (e) {
      print('Error preloading related content: $e');
    }
  }
  
  // Get a specific topic by ID
  Future<TrafficRuleTopic?> getTopicById(String topicId) async {
    print('ContentProvider: Attempting to get topic with ID: $topicId');
    
    if (topicId.isEmpty) {
      print('ContentProvider: Empty topic ID provided');
      return null;
    }
    
    // First check if we have it in cache
    if (_topicDetailCache.containsKey(topicId)) {
      print('ContentProvider: Found topic in cache: $topicId');
      return _topicDetailCache[topicId];
    }
    
    // Try multiple ID formats for matching
    List<String> possibleIds = [
      topicId,
      topicId.replaceAll('topic_', ''),
      'topic_$topicId',
      topicId.toLowerCase(),
      topicId.replaceAll('topic_', '').toLowerCase(),
    ];
    
    // Then check if we already have it in memory using any of the possible IDs
    TrafficRuleTopic? topic;
    
    for (var possibleId in possibleIds) {
      try {
        // First try exact match
        try {
          topic = _topics.firstWhere((t) => t.id == possibleId);
        } catch (_) {
          // If not found, try more flexible matching
          try {
            topic = _topics.firstWhere((t) => 
              t.id.toLowerCase() == possibleId.toLowerCase() ||
              t.id.replaceAll('topic_', '').toLowerCase() == possibleId.replaceAll('topic_', '').toLowerCase()
            );
          } catch (_) {
            // Topic not found with this ID format
          }
        }
        
        if (topic != null) {
          print('ContentProvider: Found topic in memory with ID: ${topic.id} (using match: $possibleId)');
          break;
        }
      } catch (e) {
        print('ContentProvider: Error searching for topic with ID $possibleId: $e');
      }
    }
    
    // If found in memory, cache and return it
    if (topic != null) {
      _topicDetailCache[topicId] = topic;
      return topic;
    }
    
    print('ContentProvider: Topic not found in memory, checking Firestore for ID: $topicId');
    
    // Check connectivity before fetching
    final isConnected = await _isConnected();
    if (!isConnected) {
      _lastError = 'Cannot fetch topic - no network connection';
      return null;
    }
    
    // Otherwise fetch from API
    try {
      // Try each possible ID format with the API
      for (var possibleId in possibleIds) {
        print('ContentProvider: Trying to fetch topic with ID: $possibleId');
        
        // Skip empty IDs
        if (possibleId.isEmpty) continue;
        
        try {
          final fetchedTopic = await serviceLocator.content.getTrafficRuleTopic(possibleId);
          
          if (fetchedTopic != null) {
            print('ContentProvider: Successfully fetched topic: ${fetchedTopic.id}');
            
            // Cache the topic under the original ID
            _topicDetailCache[topicId] = fetchedTopic;
            
            // Also cache under its actual ID
            _topicDetailCache[fetchedTopic.id] = fetchedTopic;
            
            // If this is a new topic not in our list, add it
            if (!_topics.any((t) => t.id == fetchedTopic.id)) {
              _topics.add(fetchedTopic);
              notifyListeners();
            }
            
            return fetchedTopic;
          }
        } catch (fetchError) {
          print('ContentProvider: Error fetching topic with ID $possibleId: $fetchError');
          // Continue to try other IDs
        }
      }
      
      // If we get here, try fetching English version as last resort
      if (_currentLanguage != 'en') {
        print('ContentProvider: Trying English fallback for topic');
        
        // Look for English version - modify the ID if it contains language code
        String englishTopicId = topicId;
        if (topicId.contains('_${_currentLanguage}_')) {
          englishTopicId = topicId.replaceAll('_${_currentLanguage}_', '_en_');
          print('ContentProvider: Generated English topic ID: $englishTopicId');
          
          try {
            final englishTopic = await serviceLocator.content.getTrafficRuleTopic(englishTopicId);
            
            if (englishTopic != null) {
              print('ContentProvider: Found English fallback topic: ${englishTopic.id}');
              
              // Cache the topic under both IDs
              _topicDetailCache[topicId] = englishTopic;
              _topicDetailCache[englishTopicId] = englishTopic;
              
              // If this is a new topic not in our list, add it
              if (!_topics.any((t) => t.id == englishTopic.id)) {
                _topics.add(englishTopic);
                notifyListeners();
              }
              
              return englishTopic;
            }
          } catch (englishError) {
            print('ContentProvider: Error fetching English fallback topic: $englishError');
          }
        }
      }
      
      print('ContentProvider: No topic found after trying all methods for ID: $topicId');
      return null;
    } catch (e) {
      _lastError = 'Error fetching traffic rule topic: $e';
      print('ContentProvider: $_lastError');
      return null;
    }
  }
  
  // Fallback to load hardcoded topics if Firestore fetch fails
  void loadHardcodedTopics() {
    // This is a fallback method that would load static content
    // when network fetch fails
    print('Loading hardcoded topics as fallback');
    
    // For now, just keeping an empty array
    _topics = [];
  }
  
  // Clear cache for current state/language combination
  Future<void> clearSpecificCache() async {
    final stateValue = _currentState ?? 'ALL';
    
    // Clear persistent cache
    await _cacheService.clearCache(stateValue, _currentLanguage, _currentLicenseId);
    await _cacheService.clearTrafficTopicsCache(stateValue, _currentLanguage);
    
    // Clear in-memory cache for current combination
    if (_moduleCache.containsKey(_currentState)) {
      _moduleCache[_currentState]?.remove(_currentLanguage);
    }
    if (_topicCache.containsKey(_currentState)) {
      _topicCache[_currentState]?.remove(_currentLanguage);
    }
    
    print('🗑️ Cleared cache for current settings: ${stateValue}_${_currentLanguage}_${_currentLicenseId}');
  }
  
  // Method to check cache status (for debugging)
  Future<bool> hasCacheForCurrentSettings() async {
    final stateValue = _currentState ?? 'ALL';
    return await _cacheService.isCacheValid(stateValue, _currentLanguage, _currentLicenseId);
  }
  
  // Get cache statistics (for debugging)
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }
  
  // Clear all caches - use this for logout or when you want to force a complete refresh
  Future<void> clearAllCaches() async {
    // Clear persistent cache
    await _cacheService.clearAllCaches();
    
    // Clear in-memory caches
    _lastFetchTime = null;
    _lastFetchTimes.clear();
    _topicCache.clear();
    _moduleCache.clear();
    _topicDetailCache.clear();
    
    print('🗑️ Cleared all caches');
  }
}
