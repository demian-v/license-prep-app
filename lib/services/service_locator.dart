import 'package:flutter/material.dart';
import 'analytics_service.dart';
import 'firebase_storage_service.dart';
import 'direct_firestore_service.dart';
import 'api/api_client.dart';
import 'api/api_implementation.dart';
import 'api/auth_api.dart';
import 'api/base/auth_api_interface.dart';
import 'api/base/content_api_interface.dart';
import 'api/base/progress_api_interface.dart';
import 'api/base/subscription_api_interface.dart';
import 'api/content_api.dart';
import 'api/firebase_auth_api.dart';
import 'api/firebase_content_api.dart';
import 'api/firebase_functions_client.dart';
import 'api/firebase_progress_api.dart';
import 'api/firebase_subscription_api.dart';
import 'api/progress_api.dart';
import 'api/subscription_api.dart';
import 'theory_cache_service.dart';
import 'quiz_cache_service.dart';

/// ServiceLocator provides a centralized way to access all API services
/// It follows the Singleton pattern to ensure only one instance exists
class ServiceLocator {
  // Singleton instance
  static final ServiceLocator _instance = ServiceLocator._internal();
  
  // Factory constructor to return the same instance every time
  factory ServiceLocator() => _instance;
  
  // Private constructor
  ServiceLocator._internal();
  
  // Core clients
  late ApiClient _apiClient;
  late FirebaseFunctionsClient _firebaseFunctionsClient;
  
  // API service interfaces
  late AuthApiInterface _authApi;
  late ContentApiInterface _contentApi;
  late ProgressApiInterface _progressApi;
  late SubscriptionApiInterface _subscriptionApi;
  
  // API service implementations - REST
  late AuthApi _restAuthApi;
  late ContentApi _restContentApi;
  late ProgressApi _restProgressApi;
  late SubscriptionApi _restSubscriptionApi;
  
  // API service implementations - Firebase
  late FirebaseAuthApi _firebaseAuthApi;
  late FirebaseContentApi _firebaseContentApi;
  late FirebaseProgressApi _firebaseProgressApi;
  late FirebaseSubscriptionApi _firebaseSubscriptionApi;
  
  // Current implementation
  ApiImplementation _currentImplementation = ApiImplementation.rest;
  
  // Firebase Storage Service
  late FirebaseStorageService _firebaseStorageService;
  
  // Direct Firestore Service
  late DirectFirestoreService _directFirestoreService;
  
  // Analytics Service
  late AnalyticsService _analyticsService;
  
  // Theory Cache Service
  late TheoryCacheService _theoryCacheService;
  
  // Quiz Cache Service
  late QuizCacheService _quizCacheService;
  
  bool _isInitialized = false;

  /// Initialize all services with default implementation (REST)
  void initialize() {
    initializeWithApiImplementation(ApiImplementation.rest);
  }
  
  /// Initialize services with the specified API implementation
  void initializeWithApiImplementation(ApiImplementation implementation) {
    if (_isInitialized) {
      reset(); // Reset if already initialized
    }
    
    // Store current implementation
    _currentImplementation = implementation;
    
    // Always initialize core clients
    _apiClient = ApiClient();
    _firebaseFunctionsClient = FirebaseFunctionsClient();
    _firebaseStorageService = FirebaseStorageService();
    _directFirestoreService = DirectFirestoreService();
    _analyticsService = AnalyticsService();
    _theoryCacheService = TheoryCacheService();
    _quizCacheService = QuizCacheService();
    
    // Initialize REST implementations
    _restAuthApi = AuthApi(_apiClient);
    _restContentApi = ContentApi(_apiClient);
    _restProgressApi = ProgressApi(_apiClient);
    _restSubscriptionApi = SubscriptionApi(_apiClient);
    
    // Initialize Firebase implementations
    _firebaseAuthApi = FirebaseAuthApi(_firebaseFunctionsClient);
    _firebaseContentApi = FirebaseContentApi(_firebaseFunctionsClient);
    _firebaseProgressApi = FirebaseProgressApi(_firebaseFunctionsClient);
    _firebaseSubscriptionApi = FirebaseSubscriptionApi(_firebaseFunctionsClient);
    
    // Set interface references based on selected implementation
    if (implementation == ApiImplementation.firebase) {
      debugPrint('Initializing with Firebase implementation');
      _authApi = _firebaseAuthApi;
      _contentApi = _firebaseContentApi;
      _progressApi = _firebaseProgressApi;
      _subscriptionApi = _firebaseSubscriptionApi;
    } else {
      debugPrint('Initializing with REST implementation');
      _authApi = _restAuthApi;
      _contentApi = _restContentApi;
      _progressApi = _restProgressApi;
      _subscriptionApi = _restSubscriptionApi;
    }
    
    _isInitialized = true;
    debugPrint('ServiceLocator initialized with ${implementation.toString()}');
  }
  
  /// Get current API implementation
  ApiImplementation get currentImplementation => _currentImplementation;
  
  /// Getter for Firebase Storage Service
  FirebaseStorageService get storage {
    _checkInitialization();
    return _firebaseStorageService;
  }
  
  /// Getter for Direct Firestore Service
  DirectFirestoreService get directFirestore {
    _checkInitialization();
    return _directFirestoreService;
  }
  
  /// Getter for Analytics Service
  AnalyticsService get analytics {
    _checkInitialization();
    return _analyticsService;
  }
  
  /// Getter for Theory Cache Service
  TheoryCacheService get theoryCache {
    _checkInitialization();
    return _theoryCacheService;
  }
  
  /// Getter for Quiz Cache Service
  QuizCacheService get quizCache {
    _checkInitialization();
    return _quizCacheService;
  }
  
  /// Getters for accessing interface-based services (recommended)
  AuthApiInterface get auth {
    _checkInitialization();
    return _authApi;
  }
  
  ContentApiInterface get content {
    _checkInitialization();
    return _contentApi;
  }
  
  ProgressApiInterface get progress {
    _checkInitialization();
    return _progressApi;
  }
  
  SubscriptionApiInterface get subscription {
    _checkInitialization();
    return _subscriptionApi;
  }
  
  /// Getters for accessing core clients
  ApiClient get apiClient {
    _checkInitialization();
    return _apiClient;
  }
  
  FirebaseFunctionsClient get firebaseFunctionsClient {
    _checkInitialization();
    return _firebaseFunctionsClient;
  }
  
  /// Legacy getters for older code - REST implementations
  /// Will return current implementation if it's REST, otherwise returns REST implementation directly
  AuthApi get authApi {
    _checkInitialization();
    if (_currentImplementation == ApiImplementation.rest) {
      return _authApi as AuthApi;
    }
    return _restAuthApi;
  }
  
  ContentApi get contentApi {
    _checkInitialization();
    if (_currentImplementation == ApiImplementation.rest) {
      return _contentApi as ContentApi;
    }
    return _restContentApi;
  }
  
  ProgressApi get progressApi {
    _checkInitialization();
    if (_currentImplementation == ApiImplementation.rest) {
      return _progressApi as ProgressApi;
    }
    return _restProgressApi;
  }
  
  SubscriptionApi get subscriptionApi {
    _checkInitialization();
    if (_currentImplementation == ApiImplementation.rest) {
      return _subscriptionApi as SubscriptionApi;
    }
    return _restSubscriptionApi;
  }
  
  /// Firebase-specific getters
  FirebaseAuthApi get firebaseAuthApi {
    _checkInitialization();
    return _firebaseAuthApi;
  }
  
  FirebaseContentApi get firebaseContentApi {
    _checkInitialization();
    return _firebaseContentApi;
  }
  
  FirebaseProgressApi get firebaseProgressApi {
    _checkInitialization();
    return _firebaseProgressApi;
  }
  
  FirebaseSubscriptionApi get firebaseSubscriptionApi {
    _checkInitialization();
    return _firebaseSubscriptionApi;
  }
  
  void _checkInitialization() {
    if (!_isInitialized) {
      throw Exception('ServiceLocator not initialized. Call initialize() first.');
    }
  }
  
  /// Reset services (useful for testing)
  void reset() {
    _isInitialized = false;
    debugPrint('ServiceLocator reset');
  }
}

/// Global instance for easy access throughout the app
final serviceLocator = ServiceLocator();
