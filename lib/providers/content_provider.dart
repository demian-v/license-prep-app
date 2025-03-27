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
  String _currentLanguage = 'uk';
  String _currentState = 'IL';
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
  
  // Getters
  bool get isLoading => _isLoading;
  List<TrafficRuleTopic> get topics => _topics;
  List<TheoryModule> get modules => _modules;
  String get currentLanguage => _currentLanguage;
  String get currentState => _currentState;
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
  
  // Set user preferences
  void setPreferences({String? language, String? state, String? licenseId}) {
    bool shouldRefresh = false;
    
    if (language != null && language != _currentLanguage) {
      _currentLanguage = language;
      shouldRefresh = true;
    }
    
    if (state != null && state != _currentState) {
      _currentState = state;
      shouldRefresh = true;
    }
    
    if (licenseId != null && licenseId != _currentLicenseId) {
      _currentLicenseId = licenseId;
      shouldRefresh = true;
    }
    
    if (shouldRefresh) {
      fetchContent();
    }
  }
  
  // Fetch all content
  Future<void> fetchContent({bool forceRefresh = false}) async {
    // If cache is valid and we're not forcing a refresh, skip the fetch
    if (isCacheValid && !forceRefresh && _topics.isNotEmpty) {
      return;
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
      // Fetch theory modules from Firestore
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Query for theory modules that match current language, state, and licenseId
      QuerySnapshot moduleSnapshot = await firestore
          .collection('theoryModules')
          .where('language', isEqualTo: _currentLanguage)
          .where('state', whereIn: [_currentState, 'ALL'])
          .where('licenseId', isEqualTo: _currentLicenseId)
          .orderBy('order')
          .get();
      
      // Process results
      _modules = moduleSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return TheoryModule.fromFirestore(data, doc.id);
      }).toList();
      
      // Update modules cache timestamp
      _lastFetchTimes['modules'] = DateTime.now();
      
      // Find traffic rules module
      TheoryModule? trafficRulesModule = _modules
          .where((module) => module.type == 'traffic_rules')
          .firstOrNull;
      
      // If we found the traffic rules module, fetch its topics
      if (trafficRulesModule != null) {
        // Query for topics that match current language, state, and licenseId
        QuerySnapshot topicSnapshot = await firestore
            .collection('trafficRuleTopics')
            .where('language', isEqualTo: _currentLanguage)
            .where('state', whereIn: [_currentState, 'ALL'])
            .where('licenseId', isEqualTo: _currentLicenseId)
            .orderBy('order')
            .get();
        
        // Process results
        _topics = topicSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          return TrafficRuleTopic.fromFirestore(data, doc.id);
        }).toList();
        
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
    // First check if we already have it in memory
    TrafficRuleTopic? topic = _topics.where(
      (t) => t.id == topicId || t.id == topicId.replaceAll('topic_', '')
    ).firstOrNull;
    
    // If found in memory, return it
    if (topic != null) {
      return topic;
    }
    
    // Check connectivity before fetching
    final isConnected = await _isConnected();
    if (!isConnected) {
      _lastError = 'Cannot fetch topic - no network connection';
      return null;
    }
    
    // Otherwise fetch from Firestore
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot docSnapshot = await firestore
          .collection('trafficRuleTopics')
          .doc(topicId)
          .get();
      
      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        final fetchedTopic = TrafficRuleTopic.fromFirestore(data, docSnapshot.id);
        
        // If this is a new topic not in our list, add it
        if (!_topics.any((t) => t.id == fetchedTopic.id)) {
          _topics.add(fetchedTopic);
          notifyListeners();
        }
        
        return fetchedTopic;
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
    // We'll use the content from TrafficRulesTopicsScreen
    // This is just a fallback and should be implemented as needed
  }
}
