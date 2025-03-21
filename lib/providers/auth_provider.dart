import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:convert';
import '../models/user.dart';
import '../services/service_locator.dart';

class AuthProvider extends ChangeNotifier {
  User? user;
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  AuthProvider(this.user);

  Future<bool> login(String email, String password) async {
    try {
      debugPrint('AuthProvider: Logging in with email: $email');
      
      if (email.isNotEmpty && password.isNotEmpty) {
        // Use API to log in
        final loggedInUser = await serviceLocator.auth.login(email, password);
        
        // Store the user
        user = loggedInUser;
        debugPrint('AuthProvider: Login successful for user: ${loggedInUser.name}');
        
        // Persist to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(loggedInUser.toJson()));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // Handle login errors
      debugPrint('AuthProvider: Login error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      debugPrint('AuthProvider: Creating user with name: $name, email: $email');
      
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        // Use API to register new user
        final registeredUser = await serviceLocator.auth.register(name, email, password);
        
        // Store the user
        user = registeredUser;
        debugPrint('AuthProvider: User created successfully: ${registeredUser.name}');
        
        // Save user to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(registeredUser.toJson()));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('AuthProvider: Signup error: $e');
      return false;
    }
  }
  
  Future<void> updateUserLanguage(String language) async {
    if (user != null) {
      try {
        // Try to use the API
        await serviceLocator.auth.updateUserLanguage(user!.id, language);
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
        await serviceLocator.auth.updateUserState(user!.id, state);
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
        await serviceLocator.auth.updateProfile(user!.id, name: name);
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
      // Sign out using the API
      await serviceLocator.auth.logout();
      
      // Clear local user data
      user = null;
      
      // Remove from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: Logout error: $e');
      // Still clear local data even if API logout fails
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
    }
  }
}
