import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'api/auth_api.dart';
import 'api/content_api.dart';
import 'api/progress_api.dart';
import 'api/subscription_api.dart';

/// ServiceLocator provides a centralized way to access all API services
/// It follows the Singleton pattern to ensure only one instance exists
class ServiceLocator {
  // Singleton instance
  static final ServiceLocator _instance = ServiceLocator._internal();
  
  // Factory constructor to return the same instance every time
  factory ServiceLocator() => _instance;
  
  // Private constructor
  ServiceLocator._internal();
  
  // API Services
  late ApiClient _apiClient;
  late AuthApi _authApi;
  late ContentApi _contentApi;
  late ProgressApi _progressApi;
  late SubscriptionApi _subscriptionApi;
  
  bool _isInitialized = false;

  /// Initialize all services
  void initialize() {
    if (_isInitialized) return;
    
    _apiClient = ApiClient();
    _authApi = AuthApi(_apiClient);
    _contentApi = ContentApi(_apiClient);
    _progressApi = ProgressApi(_apiClient);
    _subscriptionApi = SubscriptionApi(_apiClient);
    
    _isInitialized = true;
    debugPrint('ServiceLocator initialized');
  }
  
  /// Getters for accessing services
  ApiClient get apiClient {
    _checkInitialization();
    return _apiClient;
  }
  
  AuthApi get authApi {
    _checkInitialization();
    return _authApi;
  }
  
  ContentApi get contentApi {
    _checkInitialization();
    return _contentApi;
  }
  
  ProgressApi get progressApi {
    _checkInitialization();
    return _progressApi;
  }
  
  SubscriptionApi get subscriptionApi {
    _checkInitialization();
    return _subscriptionApi;
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
