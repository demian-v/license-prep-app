import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/theory_module.dart';
import '../models/traffic_rule_topic.dart';
import '../services/service_locator.dart';

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
    }
  }
  
  // Fetch content explicitly after language and state selection
  Future<void> fetchContentAfterSelection({bool forceRefresh = false}) async {
    // Mark content as explicitly requested
    _contentRequestedExplicitly = true;
    
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
    // Check if we have cached content for this specific language and state
    final String cacheKey = '${_currentState ?? "null"}:$_currentLanguage';
    
    // If cache is valid and we're not forcing a refresh, use cached content if available
    if (isCacheValid && !forceRefresh) {
      // Check if we have topics in cache
      if (_topicCache.containsKey(_currentState) && 
          _topicCache[_currentState]!.containsKey(_currentLanguage) &&
          _topicCache[_currentState]![_currentLanguage]!.isNotEmpty) {
        
        _topics = _topicCache[_currentState]![_currentLanguage]!;
        
        // Check if we have modules in cache
        if (_moduleCache.containsKey(_currentState) && 
            _moduleCache[_currentState]!.containsKey(_currentLanguage) &&
            _moduleCache[_currentState]![_currentLanguage]!.isNotEmpty) {
          
          _modules = _moduleCache[_currentState]![_currentLanguage]!;
          return; // Use cached content and skip Firestore fetch
        }
      }
    }
    
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
      // Use 'ALL' as default if state is null
      final stateValue = _currentState ?? 'ALL';
      
      _modules = await contentService.getTheoryModules(
        _currentLanguage, 
        stateValue, 
        _currentLicenseId
      );
      
      // If no modules found and language isn't English, try English as fallback
      if (_modules.isEmpty && _currentLanguage != 'en') {
        print('No modules found in $_currentLanguage, trying English fallback');
        final stateValue = _currentState ?? 'ALL';
        
        _modules = await contentService.getTheoryModules(
          'en', 
          stateValue, 
          _currentLicenseId
        );
      }
      
      // Cache the modules
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
        // Fetch topics using the API
        // Use 'ALL' as default if state is null
        final stateValue = _currentState ?? 'ALL';
        
        _topics = await contentService.getTrafficRuleTopics(
          _currentLanguage, 
          stateValue, 
          _currentLicenseId
        );
        
        // If no topics found and language isn't English, try English as fallback
        if (_topics.isEmpty && _currentLanguage != 'en') {
          print('No topics found in $_currentLanguage, trying English fallback');
          final stateValue = _currentState ?? 'ALL';
          
          _topics = await contentService.getTrafficRuleTopics(
            'en', 
            stateValue, 
            _currentLicenseId
          );
        }
        
        // Cache the topics
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
    // First check if we have it in cache
    if (_topicDetailCache.containsKey(topicId)) {
      return _topicDetailCache[topicId];
    }
    
    // Then check if we already have it in memory
    TrafficRuleTopic? topic = _topics.where(
      (t) => t.id == topicId || t.id == topicId.replaceAll('topic_', '')
    ).firstOrNull;
    
    // If found in memory, cache and return it
    if (topic != null) {
      _topicDetailCache[topicId] = topic;
      return topic;
    }
    
    // Check connectivity before fetching
    final isConnected = await _isConnected();
    if (!isConnected) {
      _lastError = 'Cannot fetch topic - no network connection';
      return null;
    }
    
    // Otherwise fetch from API
    try {
      final topic = await serviceLocator.content.getTrafficRuleTopic(topicId);
      
      if (topic != null) {
        // Cache the topic
        _topicDetailCache[topicId] = topic;
        
        // If this is a new topic not in our list, add it
        if (!_topics.any((t) => t.id == topic.id)) {
          _topics.add(topic);
          notifyListeners();
        }
        
        return topic;
      }
      
      // Try fetching English version if needed
      if (_currentLanguage != 'en') {
        // Look for English version - modify the ID if it contains language code
        String englishTopicId = topicId;
        if (topicId.contains('_${_currentLanguage}_')) {
          englishTopicId = topicId.replaceAll('_${_currentLanguage}_', '_en_');
        }
        
        final englishTopic = await serviceLocator.content.getTrafficRuleTopic(englishTopicId);
        
        if (englishTopic != null) {
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
      }
      
      return null;
    } catch (e) {
      _lastError = 'Error fetching traffic rule topic: $e';
      print(_lastError);
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
  
  // Clear all caches - use this for logout or when you want to force a complete refresh
  void clearAllCaches() {
    _lastFetchTime = null;
    _lastFetchTimes.clear();
    _topicCache.clear();
    _moduleCache.clear();
    _topicDetailCache.clear();
  }
}
