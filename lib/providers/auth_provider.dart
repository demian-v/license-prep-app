import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../services/service_locator.dart';

class AuthProvider extends ChangeNotifier {
  User? user;

  AuthProvider(this.user);

  Future<bool> login(String email, String password) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // Use the API service instead of mock data
        try {
          // First try to use the API
          final loggedInUser = await serviceLocator.authApi.login(email, password);
          user = loggedInUser;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(loggedInUser.toJson()));
          
          notifyListeners();
          return true;
        } catch (apiError) {
          // If API is not available (e.g., during development), fall back to mock data
          debugPrint('API error, using mock data: $apiError');
          
          final mockUser = User(
            id: '123',
            name: email.split('@')[0],
            email: email,
          );
          
          user = mockUser;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(mockUser.toJson()));
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        // Use the API service instead of mock data
        try {
          // First try to use the API
          final registeredUser = await serviceLocator.authApi.register(name, email, password);
          user = registeredUser;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(registeredUser.toJson()));
          
          notifyListeners();
          return true;
        } catch (apiError) {
          // If API is not available (e.g., during development), fall back to mock data
          debugPrint('API error, using mock data: $apiError');
          
          final mockUser = User(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            email: email,
          );
          
          user = mockUser;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(mockUser.toJson()));
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Signup error: $e');
      return false;
    }
  }
  
  Future<void> updateUserLanguage(String language) async {
    if (user != null) {
      try {
        // Try to use the API
        await serviceLocator.authApi.updateUserLanguage(user!.id, language);
        final updatedUser = user!.copyWith(language: language);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('API error, updating locally: $e');
        
        final updatedUser = user!.copyWith(language: language);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      }
    }
  }
  
  Future<void> updateUserState(String state) async {
    if (user != null) {
      try {
        // Try to use the API
        await serviceLocator.authApi.updateUserState(user!.id, state);
        final updatedUser = user!.copyWith(state: state);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('API error, updating locally: $e');
        
        final updatedUser = user!.copyWith(state: state);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      }
    }
  }

  Future<void> updateProfile(String name) async {
    if (user != null) {
      try {
        // Try to use the API
        await serviceLocator.authApi.updateProfile(user!.id, name: name);
        final updatedUser = user!.copyWith(name: name);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('API error, updating locally: $e');
        
        final updatedUser = user!.copyWith(name: name);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    try {
      // Try to use the API
      await serviceLocator.authApi.logout();
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
    } catch (e) {
      // Fallback to local logout if API is not available
      debugPrint('API error, logging out locally: $e');
      
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
    }
  }
}
