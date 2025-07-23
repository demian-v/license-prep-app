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
  
  // Track what was actually requested vs what was found (for empty state messaging)
  String _requestedLanguage = 'en';
  String? _requestedState = null;
  bool _isUsingLanguageFallback = false;
  bool _isUsingStateFallback = false;
  
  // Cache performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _firestoreQueries = 0;
  
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
  // Multi-dimensional detail cache: state -> language -> topicId -> topic
  final Map<String, Map<String, Map<String, TrafficRuleTopic>>> _topicDetailCache = {};
  
  // Getters
  bool get isLoading => _isLoading;
  List<TrafficRuleTopic> get topics => _topics;
  List<TheoryModule> get modules => _modules;
  String get currentLanguage => _currentLanguage;
  String? get currentState => _currentState;
  String get currentLicenseId => _currentLicenseId;
  String? get lastError => _lastError;
  bool get isOffline => _isOffline;
  
  // New getters for empty state detection
  String get requestedLanguage => _requestedLanguage;
  String? get requestedState => _requestedState;
  bool get isUsingLanguageFallback => _isUsingLanguageFallback;
  bool get isUsingStateFallback => _isUsingStateFallback;
  
  // Check if we have content in the originally requested language/state
  bool get hasRequestedContent {
    // If modules are empty, we definitely don't have requested content
    if (_modules.isEmpty) return false;
    
    // Check if we got content in the requested language and state
    return _requestedLanguage == _currentLanguage && 
           _requestedState == _currentState &&
           !_isUsingLanguageFallback &&
           !_isUsingStateFallback;
  }
  
  // Get reason why content wasn't found (for empty state messaging)
  String get contentNotFoundReason {
    if (_requestedState != _currentState || _isUsingStateFallback) {
      if (_requestedLanguage != _currentLanguage || _isUsingLanguageFallback) {
        return 'language_and_state';
      }
      return 'state';
    }
    if (_requestedLanguage != _currentLanguage || _isUsingLanguageFallback) {
      return 'language';
    }
    return 'unknown';
  }
  
  // Cache performance getters
  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;
  int get firestoreQueries => _firestoreQueries;
  double get cacheHitRatio => (_cacheHits + _cacheMisses) > 0 ? _cacheHits / (_cacheHits + _cacheMisses) : 0.0;
  
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
    
    // Enhanced logging
    print('🎯 ContentProvider.setPreferences called:');
    print('   - Current state: $_currentState → ${state ?? "null"}');
    print('   - Current language: $_currentLanguage → ${language ?? _currentLanguage}');
    print('   - Current license: $_currentLicenseId → ${licenseId ?? _currentLicenseId}');
    
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
      print('ContentProvider: State changed to ${state ?? "null"}');
      shouldRefresh = true; // Refresh content when state changes
    }
    
    if (licenseId != null && licenseId != _currentLicenseId) {
      _currentLicenseId = licenseId;
      shouldRefresh = true;
    }
    
    print('🎯 ContentProvider.setPreferences result:');
    print('   - Final state: $_currentState');
    print('   - Final language: $_currentLanguage');
    print('   - Should refresh: $shouldRefresh');
    print('   - Content requested explicitly: $_contentRequestedExplicitly');
    
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
    // Track what user actually requested (for empty state messaging)
    _requestedLanguage = _currentLanguage;
    _requestedState = _currentState;
    _isUsingLanguageFallback = false;
    _isUsingStateFallback = false;
    
    print('📋 ContentProvider: Tracking request - language: $_requestedLanguage, state: $_requestedState');
    
    // 🏗️ ENHANCED CACHING LOGIC - Check both modules AND topics cache
    if (!forceRefresh) {
      final stateValue = _currentState ?? 'ALL';
      
      print('🔍 Checking batch cache for ${stateValue}_${_currentLanguage}_${_currentLicenseId}');
      print('🔍 ContentProvider current state: $_currentState (type: ${_currentState.runtimeType})');
      print('🔍 Cache key will be: ${stateValue}_${_currentLanguage}_${_currentLicenseId}');
      
      // Check if we have BOTH cached theory modules AND traffic topics
      final cachedModules = await _cacheService.getCachedTheoryModules(
        stateValue, 
        _currentLanguage, 
        _currentLicenseId
      );
      
      final cachedTopics = await _cacheService.getCachedTrafficTopics(stateValue, _currentLanguage);
      
      // Only use cache if we have BOTH modules and topics (or no traffic rules module exists)
      if (cachedModules != null && cachedModules.isNotEmpty) {
        final hasTrafficRulesModule = cachedModules.any((module) => module.type == 'traffic_rules');
        
        // If there's a traffic rules module, we need both modules AND topics cached
        // If no traffic rules module, we only need modules cached
        bool canUseCachedData = !hasTrafficRulesModule || (cachedTopics != null && cachedTopics.isNotEmpty);
        
        if (canUseCachedData) {
          print('✅ Using FULL cached data - ${cachedModules.length} modules, ${cachedTopics?.length ?? 0} topics');
          _modules = cachedModules;
          _lastError = null;
          
          if (cachedTopics != null) {
            // Convert cached topics back to TrafficRuleTopic objects
            _topics = cachedTopics.map((topicData) {
              final Map<String, dynamic> data = Map<String, dynamic>.from(topicData);
              return TrafficRuleTopic.fromFirestore(data, data['id'] ?? '');
            }).toList();
            
            // ENHANCEMENT: Pre-populate detail cache for faster individual lookups with ALL possible variations
            print('💾 Pre-populating detail cache with all topic ID variations...');
            int totalVariations = 0;
            
            for (var topic in _topics) {
              // Store under original ID
              _storeInDetailCache(topic.id, topic);
              totalVariations++;
              
              // Generate and store ALL possible search variations
              final variations = _generateTopicIdVariations(topic.id);
              for (var variation in variations) {
                if (variation != topic.id && variation.isNotEmpty) {
                  _storeInDetailCache(variation, topic);
                  totalVariations++;
                  print('💾 Detail cache [${_getDetailCacheStateKey()}][${_currentLanguage}]: "$variation" → "${topic.id}"');
                }
              }
              
              // Also store reverse mappings (topic_X_en_IL format)
              if (_currentState != null && _currentLanguage.isNotEmpty) {
                final complexId = 'topic_${topic.id}_${_currentLanguage}_${_currentState}';
                _storeInDetailCache(complexId, topic);
                totalVariations++;
                print('💾 Detail cache [${_getDetailCacheStateKey()}][${_currentLanguage}]: "$complexId" → "${topic.id}"');
              }
            }
            
            print('💾 Pre-populated detail cache: ${_topics.length} topics → $totalVariations total cache entries');
          } else {
            _topics = [];
          }
          
          // Update in-memory caches
          if (!_moduleCache.containsKey(_currentState)) {
            _moduleCache[_currentState] = {};
          }
          _moduleCache[_currentState]![_currentLanguage] = _modules;
          
          if (!_topicCache.containsKey(_currentState)) {
            _topicCache[_currentState] = {};
          }
          _topicCache[_currentState]![_currentLanguage] = _topics;
          
          notifyListeners();
          return; // EXIT HERE - using cached data, no Firebase call needed
        } else {
          print('⚠️  Partial cache found (modules: ${cachedModules.length}, topics: ${cachedTopics?.length ?? 0}) - need to fetch topics');
        }
      } else {
        print('⚠️  No cached modules found - need to fetch both modules and topics');
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
      
      // Require specific state
      if (_currentState == null || _currentState!.isEmpty) {
        _lastError = 'State is required to fetch content';
        _isLoading = false;
        notifyListeners();
        return;
      }
      final stateValue = _currentState!;
      
      print('🚀 Starting parallel fetch: theory modules AND traffic topics for ${stateValue}_${_currentLanguage}_${_currentLicenseId}');
      
      // 🎯 ENHANCED: Parallel fetching of BOTH modules and topics
      try {
        final results = await Future.wait([
          // Fetch theory modules
          contentService.getTheoryModules(
            _currentLicenseId,  // licenseType should be first
            _currentLanguage,   // language second  
            stateValue          // state third
          ),
          // Fetch traffic topics simultaneously
          contentService.getTrafficRuleTopics(
            _currentLanguage, 
            stateValue
          ),
        ]);
        
        _modules = results[0] as List<TheoryModule>;
        _topics = results[1] as List<TrafficRuleTopic>;
        
        print('✅ Parallel fetch completed: ${_modules.length} modules, ${_topics.length} topics');
        
      } catch (parallelError) {
        print('⚠️  Parallel fetching failed, trying sequential fallback: $parallelError');
        
        // Sequential fallback - fetch modules first
        print('Fetching theory modules with: licenseId=$_currentLicenseId, language=$_currentLanguage, state=$stateValue');
        
        _modules = await contentService.getTheoryModules(
          _currentLicenseId,  // licenseType should be first
          _currentLanguage,   // language second
          stateValue          // state third
        );
        
        // Then fetch topics if we have a traffic rules module
        final trafficRulesModule = _modules.where((module) => module.type == 'traffic_rules').firstOrNull;
        
        if (trafficRulesModule != null) {
          print('Fetching traffic rule topics with: language=$_currentLanguage, state=$stateValue');
          
          _topics = await contentService.getTrafficRuleTopics(
            _currentLanguage, 
            stateValue
          );
        } else {
          _topics = [];
          print('No traffic rules module found, skipping topic fetch');
        }
        
        print('✅ Sequential fallback completed: ${_modules.length} modules, ${_topics.length} topics');
      }
      
      // REMOVED: Silent English fallback for consistent behavior
      // Now when no content exists in requested language, app will show empty state
      // This makes language behavior consistent with state behavior
      
      print('📋 ContentProvider: Fetch completed - ${_modules.length} modules, ${_topics.length} topics in $_requestedLanguage');
      
      // Check if we got content in the requested language/state combination
      if (_modules.isEmpty) {
        print('⚠️ No content found for language: $_requestedLanguage, state: $_requestedState');
        // Let the UI show empty state with proper messaging
      }
      
      // 💾 Batch cache both results
      print('💾 Caching both modules and topics...');
      await Future.wait([
        _cacheService.cacheTheoryModules(_modules, stateValue, _currentLanguage, _currentLicenseId),
        _cacheService.cacheTrafficTopics(
          _topics.map((topic) => topic.toFirestore()).toList(), 
          stateValue, 
          _currentLanguage
        ),
      ]);

      // NEW: Verify what was actually cached
      print('🔍 Verifying cache after population:');
      final cacheInspection = await _cacheService.inspectCacheKey(stateValue, _currentLanguage);
      print('📋 Cache contents: $cacheInspection');

      // NEW: List first few topic IDs for verification
      if (_topics.isNotEmpty) {
        final firstFewIds = _topics.take(3).map((t) => t.id).toList();
        print('📋 First few topic IDs cached: $firstFewIds');
      }
      
      // Update in-memory caches
      if (!_moduleCache.containsKey(_currentState)) {
        _moduleCache[_currentState] = {};
      }
      _moduleCache[_currentState]![_currentLanguage] = _modules;
      
      if (!_topicCache.containsKey(_currentState)) {
        _topicCache[_currentState] = {};
      }
      _topicCache[_currentState]![_currentLanguage] = _topics;
      
      // Update cache timestamps
      final now = DateTime.now();
      _lastFetchTimes['modules'] = now;
      _lastFetchTimes['topics'] = now;
      _lastFetchTime = now;
      
      print('✅ Caching completed successfully');
      
    } catch (e) {
      _lastError = 'Error fetching content: $e';
      print('❌ $_lastError');
      
      if (_topics.isEmpty && _modules.isEmpty) {
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
  
  // Get a specific topic by ID with cache-first approach
  Future<TrafficRuleTopic?> getTopicById(String topicId) async {
    print('📋 ContentProvider: Getting topic with ID: $topicId');
    
    if (topicId.isEmpty) {
      print('❌ Empty topic ID provided');
      return null;
    }
    
    try {
      // STEP 1: Check detail cache first (fastest - 1-5ms)
      final cachedTopic = _getFromDetailCache(topicId);
      if (cachedTopic != null) {
        print('⚡ Found topic in detail cache: $topicId (state: ${_getDetailCacheStateKey()}, language: $_currentLanguage)');
        _cacheHits++;
        return cachedTopic;
      }
      
      // STEP 2: Check in-memory topics array (5-20ms)
      TrafficRuleTopic? topic = _findTopicInMemory(topicId);
      if (topic != null) {
        print('💾 Found topic in memory: ${topic.id}');
        _storeInDetailCache(topicId, topic); // Cache for future use
        _cacheHits++;
        return topic;
      }
      
      // STEP 3: Check persistent cache before going to Firestore (20-100ms)
      topic = await _findTopicInPersistentCache(topicId);
      if (topic != null) {
        print('💽 Found topic in persistent cache: ${topic.id}');
        
        // Add to in-memory caches for future use
        _storeInDetailCache(topicId, topic);
        
        // Also add to topics array if not already there
        if (!_topics.any((t) => t.id == topic!.id)) {
          _topics.add(topic);
          notifyListeners();
        }
        
        _cacheHits++;
        return topic;
      }
      
      // If we reach here, topic not in any cache
      _cacheMisses++;
      
    } catch (cacheError) {
      // Log cache errors but continue to Firestore fallback
      print('⚠️ Cache system error for topic $topicId: $cacheError');
      _cacheMisses++;
    }
    
    // STEP 4: Fallback to Firestore (500-2000ms) - GUARANTEED RELIABILITY
    print('🌐 Topic not in cache, fetching from Firestore: $topicId');
    return await _fetchTopicFromFirestore(topicId);
  }
  
  // Fallback to load hardcoded topics if Firestore fetch fails
  void loadHardcodedTopics() {
    // This is a fallback method that would load static content
    // when network fetch fails
    print('Loading hardcoded topics as fallback');
    
    // For now, just keeping an empty array
    _topics = [];
  }
  
  /// Reset cache performance statistics
  void resetCacheStats() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _firestoreQueries = 0;
  }

  /// Helper method to get detail cache state key
  String _getDetailCacheStateKey() {
    return _currentState ?? 'ALL';
  }

  /// Helper method to ensure detail cache structure exists
  void _ensureDetailCacheStructure() {
    final stateKey = _getDetailCacheStateKey();
    
    if (!_topicDetailCache.containsKey(stateKey)) {
      _topicDetailCache[stateKey] = {};
    }
    
    if (!_topicDetailCache[stateKey]!.containsKey(_currentLanguage)) {
      _topicDetailCache[stateKey]![_currentLanguage] = {};
    }
  }

  /// Helper method to get topic from detail cache
  TrafficRuleTopic? _getFromDetailCache(String topicId) {
    final stateKey = _getDetailCacheStateKey();
    return _topicDetailCache[stateKey]?[_currentLanguage]?[topicId];
  }

  /// Helper method to store topic in detail cache
  void _storeInDetailCache(String topicId, TrafficRuleTopic topic) {
    _ensureDetailCacheStructure();
    final stateKey = _getDetailCacheStateKey();
    _topicDetailCache[stateKey]![_currentLanguage]![topicId] = topic;
  }

  /// Get comprehensive cache performance statistics
  Map<String, dynamic> getCachePerformanceStats() {
    // Calculate total topics across all state/language combinations
    int totalDetailCacheEntries = 0;
    for (var stateCache in _topicDetailCache.values) {
      for (var languageCache in stateCache.values) {
        totalDetailCacheEntries += languageCache.length;
      }
    }
    
    return {
      'cacheHits': _cacheHits,
      'cacheMisses': _cacheMisses,
      'firestoreQueries': _firestoreQueries,
      'cacheHitRatio': cacheHitRatio,
      'topicsInMemory': _topics.length,
      'topicsInDetailCache': totalDetailCacheEntries,
      'detailCacheStates': _topicDetailCache.keys.toList(),
      'currentStateLanguage': '${_getDetailCacheStateKey()}_${_currentLanguage}',
    };
  }


  /// Enhanced topic ID variations with PRIORITY for simple numeric IDs
  List<String> _generateTopicIdVariations(String topicId) {
    // PRIORITY 1: Extract simple numeric ID first (this is what's actually in cache!)
    final numericId = topicId
        .replaceAll('topic_', '')
        .replaceAll(RegExp(r'_[a-zA-Z]{2}_[A-Z]{2,3}$'), '') // Remove _en_IL suffix
        .replaceAll(RegExp(r'_[a-zA-Z]{2}$'), '') // Remove _en suffix
        .replaceAll(RegExp(r'_ALL$'), ''); // Remove _ALL suffix
    
    // Start with highest priority variations (simple IDs that are actually cached)
    final priorityVariations = <String>[
      numericId,                         // "1" ⭐ HIGHEST PRIORITY - this is what's in cache!
      topicId.replaceAll('topic_', ''),  // "1_en_IL" 
      topicId,                           // "topic_1_en_IL" - original search term
    ];
    
    // PRIORITY 2: Add other common variations
    final commonVariations = <String>{
      'topic_$numericId',                // "topic_1"
      topicId.toLowerCase(),             // "topic_1_en_il"
      numericId.toLowerCase(),           // "1" (but lowercase, just in case)
    };
    
    // PRIORITY 3: Add state/language specific variations
    final complexVariations = <String>{};
    if (_currentState != null && _currentLanguage.isNotEmpty) {
      complexVariations.addAll([
        '${topicId}_${_currentLanguage}_${_currentState}',
        topicId.replaceAll('_${_currentLanguage}_', '_en_'), // English fallback
        '${topicId}_${_currentLanguage}_ALL',
        topicId.replaceAll('_${_currentState}_', '_ALL_'),
        '${_currentLanguage}_${_currentState}_$topicId',
        '${_currentLanguage}_ALL_$topicId',
      ]);
    }
    
    // Return prioritized list: simple numeric IDs FIRST!
    final allVariations = [
      ...priorityVariations,
      ...commonVariations,
      ...complexVariations,
    ].where((id) => id.isNotEmpty && id != topicId).toList();
    
    // Remove duplicates while preserving order
    final uniqueVariations = <String>[];
    final seen = <String>{};
    for (final variation in allVariations) {
      if (!seen.contains(variation)) {
        seen.add(variation);
        uniqueVariations.add(variation);
      }
    }
    
    print('🔧 Generated variations for "$topicId": $uniqueVariations');
    
    return uniqueVariations;
  }

  /// Helper method to search in-memory topics with flexible ID matching
  TrafficRuleTopic? _findTopicInMemory(String topicId) {
    final possibleIds = _generateTopicIdVariations(topicId);
    
    for (var possibleId in possibleIds) {
      try {
        final topic = _topics.firstWhere((t) => 
          t.id == possibleId ||
          t.id.toLowerCase() == possibleId.toLowerCase()
        );
        print('💾 Found topic in memory: ${topic.id} (matched with: $possibleId)');
        return topic;
      } catch (_) {
        // Continue searching
      }
    }
    
    return null;
  }

  /// Helper method to search persistent cache with enhanced debugging
  Future<TrafficRuleTopic?> _findTopicInPersistentCache(String topicId) async {
    try {
      final stateValue = _currentState ?? 'ALL';
      final variations = _generateTopicIdVariations(topicId);
      
      print('🔍 PERSISTENT CACHE SEARCH for: "$topicId"');
      print('🔍 STATE: $stateValue, LANGUAGE: $_currentLanguage');
      print('🔍 VARIATIONS TO TRY (${variations.length}): $variations');
      
      // First, let's see what's actually in the cache
      final cacheInspection = await _cacheService.inspectCacheKey(stateValue, _currentLanguage);
      print('🔍 CACHE CONTENTS: $cacheInspection');
      
      // Try each variation with detailed logging
      for (int i = 0; i < variations.length; i++) {
        final variation = variations[i];
        print('🔍 [${i+1}/${variations.length}] Trying variation: "$variation"');
        
        final result = await _cacheService.findCachedTopicByIdWithFallback(variation, stateValue, _currentLanguage);
        if (result != null) {
          print('✅ FOUND with variation: "$variation" → result ID: "${result['id']}"');
          return TrafficRuleTopic.fromFirestore(result, result['id'] ?? variation);
        }
        print('❌ Not found with: "$variation"');
      }
      
      // If we still haven't found it, try the simple approach directly
      print('🔍 FALLBACK: Trying simple direct cache lookup...');
      
      // Check if simple numeric ID is in cache
      final simpleNumericId = topicId
          .replaceAll('topic_', '')
          .replaceAll(RegExp(r'_[a-zA-Z]{2}_[A-Z]{2,3}$'), '')
          .replaceAll(RegExp(r'_[a-zA-Z]{2}$'), '');
      
      if (simpleNumericId.isNotEmpty && simpleNumericId != topicId) {
        print('🔍 TRYING SIMPLE ID: "$simpleNumericId" (extracted from "$topicId")');
        final simpleResult = await _cacheService.findCachedTopicByIdWithFallback(simpleNumericId, stateValue, _currentLanguage);
        if (simpleResult != null) {
          print('✅ FOUND with simple ID: "$simpleNumericId"');
          return TrafficRuleTopic.fromFirestore(simpleResult, simpleResult['id'] ?? simpleNumericId);
        }
      }
      
      print('❌ TOPIC NOT FOUND after trying ${variations.length} variations + simple ID');
      print('🔍 DEBUG: Inspecting what\'s actually in cache...');
      await _debugCacheContents(stateValue);
      
      return null;
    } catch (cacheError) {
      // Log cache error but don't fail the request
      print('⚠️ Cache lookup failed for $topicId: $cacheError');
      return null;
    }
  }

  /// Helper method for Firestore fetching (preserves existing logic)
  Future<TrafficRuleTopic?> _fetchTopicFromFirestore(String topicId) async {
    print('🌐 ContentProvider: Topic not found in cache, checking Firestore for ID: $topicId');
    
    // Check connectivity before fetching
    final isConnected = await _isConnected();
    if (!isConnected) {
      _lastError = 'Cannot fetch topic - no network connection';
      return null;
    }
    
    // Otherwise fetch from API
    try {
      // Try each possible ID format with the API
      final possibleIds = _generateTopicIdVariations(topicId);
      
      for (var possibleId in possibleIds) {
        print('ContentProvider: Trying to fetch topic with ID: $possibleId');
        
        // Skip empty IDs
        if (possibleId.isEmpty) continue;
        
        try {
          final fetchedTopic = await serviceLocator.content.getTrafficRuleTopic(possibleId);
          
          if (fetchedTopic != null) {
            print('ContentProvider: Successfully fetched topic: ${fetchedTopic.id}');
            
            // Cache the topic under the original ID
            _storeInDetailCache(topicId, fetchedTopic);
            
            // Also cache under its actual ID
            _storeInDetailCache(fetchedTopic.id, fetchedTopic);
            
            // If this is a new topic not in our list, add it
            if (!_topics.any((t) => t.id == fetchedTopic.id)) {
              _topics.add(fetchedTopic);
              notifyListeners();
            }
            
            // NEW: Repair cache for future lookups
            await _repairCache(topicId, fetchedTopic);
            
            _firestoreQueries++; // Track Firestore usage
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
              _storeInDetailCache(topicId, englishTopic);
              _storeInDetailCache(englishTopicId, englishTopic);
              
              // If this is a new topic not in our list, add it
              if (!_topics.any((t) => t.id == englishTopic.id)) {
                _topics.add(englishTopic);
                notifyListeners();
              }
              
              _firestoreQueries++; // Track Firestore usage
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
      _firestoreQueries++; // Track failed Firestore attempts
      return null;
    }
  }

  /// Debug method to check cache status for a specific topic
  Future<Map<String, dynamic>> debugTopicCacheStatus(String topicId) async {
    final stateValue = _currentState ?? 'ALL';
    
    return {
      'topicId': topicId,
      'inDetailCache': _topicDetailCache.containsKey(topicId),
      'inMemoryTopics': _topics.any((t) => t.id == topicId),
      'availableCachedTopicIds': await _cacheService.getCachedTopicIds(stateValue, _currentLanguage),
      'currentState': stateValue,
      'currentLanguage': _currentLanguage,
      'totalTopicsInMemory': _topics.length,
      'totalTopicsInDetailCache': _topicDetailCache.length,
      'cachePerformance': getCachePerformanceStats(),
    };
  }

  /// Method to pre-warm cache for a specific module
  Future<void> preWarmTopicsForModule(TheoryModule module) async {
    if (module.topics.isEmpty) return;
    
    print('🔥 Pre-warming topics for module: ${module.title}');
    
    int preWarmed = 0;
    for (var topicId in module.topics) {
      if (!_topicDetailCache.containsKey(topicId)) {
        // Try to load from persistent cache without going to Firestore
        final topic = await _findTopicInPersistentCache(topicId);
        if (topic != null) {
          _storeInDetailCache(topicId, topic);
          preWarmed++;
        }
      }
    }
    
    print('✅ Pre-warmed $preWarmed/${module.topics.length} topics for module: ${module.title}');
  }
  
  /// Debug method to inspect cache contents when lookup fails
  Future<void> _debugCacheContents(String currentState) async {
    try {
      // Check all available cache keys
      final allKeys = await _cacheService.getAllCacheKeys();
      print('🗂️ All traffic cache keys: $allKeys');
      
      // Inspect current state cache
      final currentStateCache = await _cacheService.inspectCacheKey(currentState, _currentLanguage);
      print('🔍 Current state cache ($currentState, $_currentLanguage): $currentStateCache');
      
      // Inspect ALL state cache
      final allStateCache = await _cacheService.inspectCacheKey('ALL', _currentLanguage);
      print('🔍 ALL state cache (ALL, $_currentLanguage): $allStateCache');
      
      // If current language is not English, check English cache too
      if (_currentLanguage != 'en') {
        final englishCache = await _cacheService.inspectCacheKey(currentState, 'en');
        print('🔍 English cache ($currentState, en): $englishCache');
      }
    } catch (e) {
      print('❌ Error debugging cache contents: $e');
    }
  }
  
  /// Smart cache repair - if topic found via Firestore, improve cache for next time
  Future<void> _repairCache(String topicId, TrafficRuleTopic fetchedTopic) async {
    try {
      // After successful Firestore fetch, check if we can improve cache
      final stateValue = _currentState ?? 'ALL';
      
      // Get current cached topics
      final cachedTopics = await _cacheService.getCachedTrafficTopics(stateValue, _currentLanguage);
      
      if (cachedTopics != null) {
        // Check if the fetched topic should be added to cache
        final existingIds = cachedTopics.map((t) => t['id']).toSet();
        
        if (!existingIds.contains(fetchedTopic.id)) {
          print('🔧 Repairing cache by adding missing topic: ${fetchedTopic.id}');
          
          // Add the fetched topic to cached topics
          final updatedTopics = List<dynamic>.from(cachedTopics);
          updatedTopics.add(fetchedTopic.toFirestore());
          
          // Re-cache with updated list
          await _cacheService.cacheTrafficTopics(updatedTopics, stateValue, _currentLanguage);
          
          print('✅ Cache repaired successfully');
        }
      }
    } catch (e) {
      print('⚠️ Cache repair failed: $e');
    }
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
    
    // Clear detail cache for current state/language
    clearDetailCacheForCurrentState();
    
    print('🗑️ Cleared cache for current settings: ${stateValue}_${_currentLanguage}_${_currentLicenseId}');
  }
  
  /// Clear detail cache for current state/language combination
  void clearDetailCacheForCurrentState() {
    final stateKey = _getDetailCacheStateKey();
    
    if (_topicDetailCache.containsKey(stateKey)) {
      _topicDetailCache[stateKey]?.remove(_currentLanguage);
      
      // If no languages left for this state, remove state entirely
      if (_topicDetailCache[stateKey]?.isEmpty == true) {
        _topicDetailCache.remove(stateKey);
      }
    }
    
    print('🗑️ Cleared detail cache for state: $stateKey, language: $_currentLanguage');
  }
  
  /// Debug method for multi-dimensional cache inspection
  Future<void> debugMultiDimensionalCache() async {
    print('\n🔍 === MULTI-DIMENSIONAL DETAIL CACHE DEBUG ===');
    
    for (var stateKey in _topicDetailCache.keys) {
      final stateCache = _topicDetailCache[stateKey]!;
      print('State: $stateKey');
      
      for (var langKey in stateCache.keys) {
        final langCache = stateCache[langKey]!;
        final topicIds = langCache.keys.take(5).join(', ');
        print('  └── Language: $langKey → ${langCache.length} topics (${topicIds}${langCache.length > 5 ? '...' : ''})');
      }
    }
    
    final currentStateKey = _getDetailCacheStateKey();
    final currentLangCache = _topicDetailCache[currentStateKey]?[_currentLanguage];
    print('\nCurrent active cache: [$currentStateKey][$_currentLanguage] → ${currentLangCache?.length ?? 0} topics');
    
    print('=== END MULTI-DIMENSIONAL DEBUG ===\n');
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
  
  /// Print comprehensive cache status (for debugging)
  Future<void> printCacheStatus([String? specificTopicId]) async {
    print('\n🔍 === CACHE STATUS DEBUG ===');
    
    final stats = getCachePerformanceStats();
    print('📊 Performance: ${stats['cacheHits']} hits, ${stats['cacheMisses']} misses, ${stats['firestoreQueries']} Firestore queries');
    print('📈 Cache hit ratio: ${(stats['cacheHitRatio'] * 100).toStringAsFixed(1)}%');
    print('💾 In memory: ${stats['topicsInMemory']} topics, ${stats['topicsInDetailCache']} in detail cache');
    
    if (specificTopicId != null) {
      final debug = await debugTopicCacheStatus(specificTopicId);
      print('🎯 Topic "$specificTopicId": $debug');
    }
    
    final stateValue = _currentState ?? 'ALL';
    final cachedIds = await _cacheService.getCachedTopicIds(stateValue, _currentLanguage);
    print('🗂️ Available cached topic IDs (${cachedIds.length}): ${cachedIds.take(5).join(', ')}${cachedIds.length > 5 ? '...' : ''}');
    
    print('=== END CACHE STATUS ===\n');
  }
  
  /// Comprehensive cache debugging for troubleshooting
  Future<void> debugFullCacheStatus(String topicId) async {
    print('\n🔍 === COMPREHENSIVE CACHE DEBUG ===');
    print('Looking for topic: $topicId');
    print('Current state: $_currentState, language: $_currentLanguage');
    
    // Check all cache keys
    final allKeys = await _cacheService.getAllCacheKeys();
    print('Available cache keys: $allKeys');
    
    // Check multiple state combinations
    final statesToCheck = ['$_currentState', 'ALL'];
    final languagesToCheck = ['$_currentLanguage', 'en'];
    
    for (var state in statesToCheck) {
      for (var language in languagesToCheck) {
        final inspection = await _cacheService.inspectCacheKey(state, language);
        print('Cache[$state][$language]: ${inspection}');
      }
    }
    
    // Check if topic exists in detail cache
    print('In detail cache: ${_topicDetailCache.containsKey(topicId)}');
    print('In memory topics: ${_topics.any((t) => t.id == topicId)}');
    
    // Check all topic ID variations
    final variations = _generateTopicIdVariations(topicId);
    print('Topic ID variations to try: $variations');
    
    print('=== END CACHE DEBUG ===\n');
  }
}
