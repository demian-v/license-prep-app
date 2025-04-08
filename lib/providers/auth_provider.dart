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
        debugPrint('🔤 AuthProvider: Updating user language to: $language');
        
        // Try to use the API
        await serviceLocator.auth.updateUserLanguage(user!.id, language);
        
        // Get the updated user from the API
        try {
          final updatedUserFromApi = await serviceLocator.auth.getCurrentUser();
          if (updatedUserFromApi != null) {
            debugPrint('✅ AuthProvider: Successfully updated user language to $language via API');
            user = updatedUserFromApi;
          } else {
            debugPrint('⚠️ AuthProvider: API returned null user, using local update');
            user = user!.copyWith(language: language);
          }
        } catch (getUserError) {
          debugPrint('⚠️ AuthProvider: Error getting updated user: $getUserError');
          // Use local update as fallback
          user = user!.copyWith(language: language);
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
        
        notifyListeners();
        debugPrint('🔤 AuthProvider: Language set to: ${user!.language}');
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('⚠️ AuthProvider: API error, updating locally: $e');
        
        final updatedUser = user!.copyWith(language: language);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
        debugPrint('🔤 AuthProvider: Language set locally to: ${user!.language}');
      }
    } else {
      debugPrint('⚠️ AuthProvider: Cannot update language - user is null');
    }
  }
  
  Future<void> updateUserState(String? state) async {
    if (user != null) {
      try {
        debugPrint('🗺️ AuthProvider: Updating user state to: ${state ?? "null"}');
        
        if (state != null) {
          // Try to use the API only if state is not null
          await serviceLocator.auth.updateUserState(user!.id, state);
          
          // Get the updated user from the API
          try {
            final updatedUserFromApi = await serviceLocator.auth.getCurrentUser();
            if (updatedUserFromApi != null) {
              debugPrint('✅ AuthProvider: Successfully updated user state to $state via API');
              user = updatedUserFromApi;
            } else {
              debugPrint('⚠️ AuthProvider: API returned null user, using local update');
              user = user!.copyWith(state: state);
            }
          } catch (getUserError) {
            debugPrint('⚠️ AuthProvider: Error getting updated user: $getUserError');
            // Use local update as fallback
            user = user!.copyWith(state: state);
          }
        } else {
          // Just update the local user with null state
          user = user!.copyWith(clearState: true);
          debugPrint('✅ AuthProvider: Updated user state to null locally');
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
        
        notifyListeners();
        debugPrint('🗺️ AuthProvider: State set to: ${user!.state ?? "null"}');
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('⚠️ AuthProvider: API error, updating locally: $e');
        
        final updatedUser = user!.copyWith(state: state);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
        debugPrint('🗺️ AuthProvider: State set locally to: ${user!.state ?? "null"}');
      }
    } else {
      debugPrint('⚠️ AuthProvider: Cannot update state - user is null');
    }
  }

  Future<void> updateProfile(String name) async {
    if (user != null) {
      try {
        debugPrint('👤 AuthProvider: Updating user profile name to: $name');
        
        // Try to use the API
        await serviceLocator.auth.updateProfile(user!.id, name: name);
        
        // Get the updated user from the API
        try {
          final updatedUserFromApi = await serviceLocator.auth.getCurrentUser();
          if (updatedUserFromApi != null) {
            debugPrint('✅ AuthProvider: Successfully updated user name to $name via API');
            user = updatedUserFromApi;
          } else {
            debugPrint('⚠️ AuthProvider: API returned null user, using local update');
            user = user!.copyWith(name: name);
          }
        } catch (getUserError) {
          debugPrint('⚠️ AuthProvider: Error getting updated user: $getUserError');
          // Use local update as fallback
          user = user!.copyWith(name: name);
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
        
        notifyListeners();
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('⚠️ AuthProvider: API error, updating name locally: $e');
        
        final updatedUser = user!.copyWith(name: name);
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      }
    } else {
      debugPrint('⚠️ AuthProvider: Cannot update profile - user is null');
    }
  }

  Future<void> updateUserEmail(String email, {String? password}) async {
    if (user != null) {
      try {
        debugPrint('📧 AuthProvider: Updating user email to: $email');
        
        // Use secure method if password is provided
        if (password != null) {
          debugPrint('🔐 AuthProvider: Using secure email update with authentication');
          await serviceLocator.auth.updateUserEmailSecure(user!.id, email, password);
        } else {
          // Try legacy method (this will likely fail on Firebase)
          debugPrint('⚠️ AuthProvider: Using non-secure email update (may fail)');
          await serviceLocator.auth.updateUserEmail(user!.id, email);
        }
        
        // Get the updated user from the API
        try {
          final updatedUserFromApi = await serviceLocator.auth.getCurrentUser();
          if (updatedUserFromApi != null) {
            debugPrint('✅ AuthProvider: Successfully updated user email to $email via API');
            user = updatedUserFromApi;
          } else {
            debugPrint('⚠️ AuthProvider: API returned null user, using local update');
            // Create a new user object with updated email
            // We can't use copyWith here because it doesn't allow email changes
            user = User(
              id: user!.id,
              name: user!.name,
              email: email, // Update the email
              language: user!.language,
              state: user!.state,
            );
          }
        } catch (getUserError) {
          debugPrint('⚠️ AuthProvider: Error getting updated user: $getUserError');
          // Use local update as fallback
          user = User(
            id: user!.id,
            name: user!.name,
            email: email, // Update the email
            language: user!.language,
            state: user!.state,
          );
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
        
        notifyListeners();
      } catch (e) {
        // Fallback to local update if API is not available
        debugPrint('⚠️ AuthProvider: API error, updating email locally: $e');
        
        // Create a new user object with updated email
        final updatedUser = User(
          id: user!.id,
          name: user!.name,
          email: email, // Update the email
          language: user!.language,
          state: user!.state,
        );
        user = updatedUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        notifyListeners();
      }
    } else {
      debugPrint('⚠️ AuthProvider: Cannot update email - user is null');
    }
  }

  Future<void> deleteAccount() async {
    if (user != null) {
      try {
        debugPrint('🗑️ AuthProvider: Deleting user account for ID: ${user!.id}');
        
        // Try to use the API to delete the account
        await serviceLocator.auth.deleteAccount(user!.id);
        
        // Clear local data after successful API deletion
        user = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
        
        notifyListeners();
        debugPrint('✅ AuthProvider: User account deleted successfully');
      } catch (e) {
        debugPrint('⚠️ AuthProvider: Account deletion error: $e');
        // Still clear local data even if API deletion fails
        user = null;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user');
        
        notifyListeners();
        debugPrint('🗑️ AuthProvider: User account deleted locally due to API error');
      }
    } else {
      debugPrint('⚠️ AuthProvider: Cannot delete account - user is null');
    }
  }

  Future<void> logout() async {
    try {
      debugPrint('🚪 AuthProvider: Logging out user');
      
      // Sign out using the API
      await serviceLocator.auth.logout();
      
      // Clear local user data
      user = null;
      
      // Remove from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
      debugPrint('✅ AuthProvider: User logged out successfully');
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Logout error: $e');
      // Still clear local data even if API logout fails
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
      debugPrint('🚪 AuthProvider: User logged out locally due to API error');
    }
  }
}
