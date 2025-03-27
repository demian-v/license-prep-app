import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Cache timestamps
  DateTime? _lastFetchTime;
  final Duration _cacheValidityDuration = Duration(minutes: 30);
  
  // Getters
  bool get isLoading => _isLoading;
  List<TrafficRuleTopic> get topics => _topics;
  List<TheoryModule> get modules => _modules;
  String get currentLanguage => _currentLanguage;
  String get currentState => _currentState;
  String get currentLicenseId => _currentLicenseId;
  
  // Check if cache is valid
  bool get isCacheValid {
    if (_lastFetchTime == null) return false;
    
    final now = DateTime.now();
    return now.difference(_lastFetchTime!) < _cacheValidityDuration;
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
    notifyListeners();
    
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
      } else {
        _topics = [];
      }
      
      // Update cache timestamp
      _lastFetchTime = DateTime.now();
    } catch (e) {
      print('Error fetching content: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
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
    
    // Otherwise fetch from Firestore
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot docSnapshot = await firestore
          .collection('trafficRuleTopics')
          .doc(topicId)
          .get();
      
      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        return TrafficRuleTopic.fromFirestore(data, docSnapshot.id);
      }
      
      return null;
    } catch (e) {
      print('Error fetching traffic rule topic: $e');
      return null;
    }
  }
  
  // Fallback to load hardcoded topics if Firestore fetch fails
  void loadHardcodedTopics() {
    // We'll use the content from TrafficRulesTopicsScreen
    // This is just a fallback and should be implemented as needed
  }
}
