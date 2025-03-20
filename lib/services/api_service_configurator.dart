import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api_implementation.dart';
import 'service_locator.dart';

/// Class responsible for configuring which API implementation to use
class ApiServiceConfigurator {
  static const String _apiImplementationKey = 'api_implementation';
  
  /// Current API implementation that's being used
  ApiImplementation _currentImplementation = ApiImplementation.rest;
  
  /// Get the current API implementation
  ApiImplementation get currentImplementation => _currentImplementation;
  
  /// Initialize the API configurator by loading the last used implementation
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedValue = prefs.getString(_apiImplementationKey);
      
      if (storedValue != null) {
        if (storedValue == 'firebase') {
          _currentImplementation = ApiImplementation.firebase;
        } else {
          _currentImplementation = ApiImplementation.rest;
        }
      }
      
      // Initialize service locator with the current implementation
      await configureServices(_currentImplementation);
      
    } catch (e) {
      debugPrint('Error initializing API configuration: $e');
      // Default to REST API in case of error
      _currentImplementation = ApiImplementation.rest;
      await configureServices(_currentImplementation);
    }
  }
  
  /// Switch to a different API implementation
  Future<void> switchImplementation(ApiImplementation implementation) async {
    if (_currentImplementation == implementation) {
      // No change needed
      return;
    }
    
    _currentImplementation = implementation;
    
    // Save the new implementation preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _apiImplementationKey, 
      implementation == ApiImplementation.firebase ? 'firebase' : 'rest'
    );
    
    // Reconfigure services to use the new implementation
    await configureServices(implementation);
  }
  
  /// Configure the service locator to use the specified implementation
  Future<void> configureServices(ApiImplementation implementation) async {
    // Reset existing service locator
    serviceLocator.reset();
    
    // Re-initialize with the chosen implementation
    serviceLocator.initializeWithApiImplementation(implementation);
  }
}

/// Global instance for easy access throughout the app
final apiServiceConfigurator = ApiServiceConfigurator();
