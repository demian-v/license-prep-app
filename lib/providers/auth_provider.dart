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
      if (email.isNotEmpty && password.isNotEmpty) {
        // Sign in with Firebase Auth
        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        final firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          // Create our app User model from the Firebase user
          final loggedInUser = User(
            id: firebaseUser.uid,
            name: firebaseUser.displayName ?? email.split('@')[0],
            email: firebaseUser.email ?? email,
          );
          
          user = loggedInUser;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(loggedInUser.toJson()));
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase login error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        // Create user with Firebase Auth
        final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        final firebaseUser = userCredential.user;
        if (firebaseUser != null) {
          // Set the display name
          await firebaseUser.updateDisplayName(name);
          
          // Create our app User model
          final registeredUser = User(
            id: firebaseUser.uid,
            name: name,
            email: email,
          );
          
          user = registeredUser;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(registeredUser.toJson()));
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('Firebase signup error: ${e.code} - ${e.message}');
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
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      // Still clear local data even if Firebase logout fails
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
    }
  }
}
