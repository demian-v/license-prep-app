import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:convert';
import '../models/user.dart';
import '../services/service_locator.dart';
import '../services/email_sync_service.dart';
import '../data/state_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'language_provider.dart';

class AuthProvider extends ChangeNotifier {
  User? user;
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LanguageProvider? _languageProvider;

  AuthProvider(this.user);

  // Set the language provider for synchronization
  void setLanguageProvider(LanguageProvider languageProvider) {
    _languageProvider = languageProvider;
  }

  Future<bool> login(String email, String password) async {
    try {
      debugPrint('AuthProvider: Logging in with email: $email');
      
      if (email.isNotEmpty && password.isNotEmpty) {
        // Use API to log in
        final loggedInUser = await serviceLocator.auth.login(email, password);
        
        // Check if we have saved state/language/name preferences (from email change)
        final prefs = await SharedPreferences.getInstance();
        String? savedState = prefs.getString('last_user_state');
        String? savedLanguage = prefs.getString('last_user_language');
        String? savedName = prefs.getString('last_user_name');
        
        // If we have saved preferences, use them to create updated user
        if (savedState != null || savedLanguage != null || savedName != null) {
          debugPrint('🔄 AuthProvider: Found saved preferences - name: $savedName, state: $savedState, language: $savedLanguage');
          
          // Check if current name appears to be from email
          bool nameIsFromEmail = false;
          if (loggedInUser.name.isNotEmpty) {
            final emailPrefix = email.split('@').first.toLowerCase();
            
            // More comprehensive check for email-derived names
            // Check for exact match, with/without dots, and for shortened versions like 'ma3'
            if (emailPrefix.isNotEmpty && (
                loggedInUser.name.toLowerCase() == emailPrefix.toLowerCase() || 
                loggedInUser.name.toLowerCase() == emailPrefix.toLowerCase().replaceAll('.', ' ') ||
                (emailPrefix.length > 2 && 
                 loggedInUser.name.toLowerCase() == emailPrefix.substring(0, emailPrefix.length).toLowerCase()) ||
                (loggedInUser.name.length <= 4 && emailPrefix.startsWith(loggedInUser.name.toLowerCase()))
            )) {
              debugPrint('⚠️ AuthProvider: Current user name appears to be derived from email: ${loggedInUser.name}, emailPrefix: $emailPrefix');
              nameIsFromEmail = true;
            }
          }
          
          // Create user with preserved preferences, prioritizing saved name especially if current name is email-derived
          final updatedUser = User(
            id: loggedInUser.id,
            name: (savedName != null && savedName.isNotEmpty && (loggedInUser.name.isEmpty || nameIsFromEmail)) 
                ? savedName 
                : loggedInUser.name,
            email: loggedInUser.email,
            language: savedLanguage ?? loggedInUser.language,
            state: savedState ?? loggedInUser.state,
          );
          
          // Store the updated user
          user = updatedUser;
          debugPrint('✅ AuthProvider: Login successful with restored preferences for user: ${updatedUser.name}');
          
          // IMPORTANT: Also update Firestore with the restored values to ensure consistency
          try {
            Map<String, dynamic> updateData = {};
            
            // Only include fields that have saved values
            if (savedName != null) updateData['name'] = savedName;
            if (savedState != null) updateData['state'] = savedState;
            if (savedLanguage != null) updateData['language'] = savedLanguage;
            
            // Add timestamp
            updateData['lastUpdated'] = FieldValue.serverTimestamp();
            
            // Update Firestore
            await _firestore.collection('users').doc(updatedUser.id).update(updateData);
            debugPrint('✅ AuthProvider: Updated Firestore with restored preferences: ${updateData.keys.join(", ")}');
          } catch (e) {
            debugPrint('⚠️ AuthProvider: Error updating Firestore with restored values: $e');
          }
          
          // Clean up saved preferences
          await prefs.remove('last_user_state');
          await prefs.remove('last_user_language');
          await prefs.remove('last_user_name');
        } else {
          // Use the user as-is if no saved preferences
          user = loggedInUser;
          debugPrint('AuthProvider: Login successful for user: ${loggedInUser.name}');
        }
        
        // Sync emails between Auth and Firestore
        await emailSyncService.syncEmailWithFirestore();
        
        // Sync user's language preference to LanguageProvider
        await _syncUserLanguageToProvider();
        
        // Persist to shared preferences
        await prefs.setString('user', jsonEncode(user!.toJson()));
        
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
      debugPrint('🔍 [AuthProvider] Creating user with name: $name, email: $email');
      
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        // Use API to register new user
        final registeredUser = await serviceLocator.auth.register(name, email, password);
        
        // Verify and enforce correct default values
        if (registeredUser.language != 'en' || registeredUser.state != null) {
          debugPrint('⚠️ [AuthProvider] User was created with incorrect default values');
          debugPrint('    - Current language: ${registeredUser.language}');
          debugPrint('    - Current state: ${registeredUser.state}');
          
          // Create a corrected user with proper defaults
          final correctedUser = User(
            id: registeredUser.id,
            name: registeredUser.name,
            email: registeredUser.email,
            language: 'en',    // Explicitly set to English
            state: null,       // Explicitly set to null
          );
          
          // Store the corrected user
          user = correctedUser;
          debugPrint('✅ [AuthProvider] Corrected user default values locally');
          
          // Try to update the backend as well
          try {
            // Update Firestore directly
            await _firestore.collection('users').doc(registeredUser.id).update({
              'language': 'en',
              'state': null,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ [AuthProvider] Updated user defaults in Firestore');
          } catch (e) {
            debugPrint('⚠️ [AuthProvider] Failed to update defaults in Firestore: $e');
          }
        } else {
          // Store the user as is since default values are correct
          user = registeredUser;
          debugPrint('✅ [AuthProvider] User created with correct default values');
        }
        
        // Run email sync immediately to ensure consistency and fix any potential issues
        debugPrint('🔄 [AuthProvider] Running email sync to ensure data consistency');
        await emailSyncService.syncEmailWithFirestore();
        
        // Save user to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(user!.toJson()));
        
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
        debugPrint('🗺️ [AuthProvider] Updating user state to: ${state ?? "null"}');
        
        // Ensure we're using the state ID and not a full state name or "null" string
        String? stateId = state;
        
        // If state is a full state name (longer than 2 chars), try to convert it to state ID
        if (state != null && state.length > 2) {
          final stateInfo = StateData.getStateByName(state);
          if (stateInfo != null) {
            stateId = stateInfo.id;
            debugPrint('🔄 [AuthProvider] Converted state name "$state" to ID: "$stateId"');
          } else {
            debugPrint('⚠️ [AuthProvider] Could not convert state name to ID: $state');
          }
        }
        
        // Handle special case where "null" might be passed as a string
        if (state == "null") {
          stateId = null;
          debugPrint('🔄 [AuthProvider] Converted "null" string to actual null value');
        }
        
        if (stateId != null) {
          // Try to use the API only if state is not null
          await serviceLocator.auth.updateUserState(user!.id, stateId);
          
          // Get the updated user from the API
          try {
            final updatedUserFromApi = await serviceLocator.auth.getCurrentUser();
            if (updatedUserFromApi != null) {
              debugPrint('✅ [AuthProvider] Successfully updated user state to $stateId via API');
              user = updatedUserFromApi;
            } else {
              debugPrint('⚠️ [AuthProvider] API returned null user, using local update');
              user = user!.copyWith(state: stateId);
            }
          } catch (getUserError) {
            debugPrint('⚠️ [AuthProvider] Error getting updated user: $getUserError');
            // Use local update as fallback
            user = user!.copyWith(state: stateId);
          }
        } else {
          // Just update the local user with null state
          user = user!.copyWith(clearState: true);
          debugPrint('✅ [AuthProvider] Updated user state to null locally');
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

  // This method handles updating the local app state with the verified email
  // It works even when Firestore permissions prevent direct database updates
  Future<void> applyVerifiedEmail() async {
    try {
      if (user == null) {
        debugPrint('⚠️ AuthProvider: Cannot apply verified email - user is null');
        return;
      }
      
      // Reload the Firebase Auth user to get the latest email
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        debugPrint('⚠️ AuthProvider: No Firebase Auth user found');
        return;
      }
      
      // Force reload to get latest data from Firebase Auth
      await firebaseUser.reload();
      final verifiedEmail = firebaseUser.email;
      
      if (verifiedEmail == null) {
        debugPrint('⚠️ AuthProvider: Firebase Auth user has no email');
        return;
      }
      
      debugPrint('📧 AuthProvider: Found verified email in Firebase Auth: $verifiedEmail');
      
      if (verifiedEmail != user!.email) {
        debugPrint('🔄 AuthProvider: Updating app state with verified email: ${user!.email} → $verifiedEmail');
        
        // Create a new user object with updated email
        final updatedUser = User(
          id: user!.id,
          name: user!.name,
          email: verifiedEmail, // Use the verified email from Firebase Auth
          language: user!.language,
          state: user!.state,
        );
        
        // Update the provider's user object
        user = updatedUser;
        
        // Save to SharedPreferences so it persists even if app is restarted
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(updatedUser.toJson()));
        
        // Try one more time to update Firestore, but don't worry if it fails
        // This is just an attempt since we've seen permission issues
        try {
          await _firestore.collection('users').doc(user!.id).update({
            'email': verifiedEmail,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ AuthProvider: Successfully updated Firestore with verified email');
        } catch (e) {
          // This is expected to fail due to permission issues
          debugPrint('⚠️ AuthProvider: Could not update Firestore (expected): $e');
        }
        
        // Notify listeners to update the UI
        notifyListeners();
        debugPrint('✅ AuthProvider: Successfully applied verified email in app state');
      } else {
        debugPrint('ℹ️ AuthProvider: Email already matches verified email, no update needed');
      }
    } catch (e) {
      debugPrint('❌ AuthProvider: Error applying verified email: $e');
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
        // Check if this is an authentication error
        String errorMessage = e.toString();
        if (errorMessage.contains('INVALID_LOGIN_CREDENTIALS') || 
            errorMessage.contains('wrong-password') ||
            errorMessage.contains('Authentication failed') ||
            errorMessage.contains('auth/invalid-credential') ||
            errorMessage.contains('Reauthentication failed')) {
          // This is an authentication error - do NOT update locally
          debugPrint('❌ AuthProvider: Authentication error, NOT updating email: $e');
          // Re-throw the error so it can be handled by the UI
          throw e;
        } else {
          // Only for network errors or API unavailability, fall back to local update
          debugPrint('⚠️ AuthProvider: Non-auth API error, updating email locally: $e');
          
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
      
      // Reset language to English when user logs out
      await _resetLanguageToEnglish();
      
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
      
      // Reset language to English when user logs out
      await _resetLanguageToEnglish();
      
      user = null;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      
      notifyListeners();
      debugPrint('🚪 AuthProvider: User logged out locally due to API error');
    }
  }

  // Private method to sync user's language preference to LanguageProvider
  Future<void> _syncUserLanguageToProvider() async {
    if (_languageProvider != null && user != null && user!.language != null && user!.language!.isNotEmpty) {
      try {
        await _languageProvider!.setLanguage(user!.language!);
        debugPrint('🔄 AuthProvider: Synced user language ${user!.language} to LanguageProvider');
      } catch (e) {
        debugPrint('⚠️ AuthProvider: Error syncing language to provider: $e');
      }
    }
  }

  // Private method to reset language to English (for logout)
  Future<void> _resetLanguageToEnglish() async {
    if (_languageProvider != null) {
      try {
        await _languageProvider!.setLanguage('en');
        debugPrint('🔄 AuthProvider: Reset LanguageProvider to English on logout');
      } catch (e) {
        debugPrint('⚠️ AuthProvider: Error resetting language to English: $e');
      }
    }
  }
  
  /// Sends a password reset email to the specified email address
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('🔑 AuthProvider: Sending password reset email to: $email');
      // Use Firebase Auth directly for better reliability
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      debugPrint('✅ AuthProvider: Password reset email sent successfully');
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Password reset email error: $e');
      // For security reasons, we don't expose if the email exists or not
    }
  }
  
  /// Verifies a password reset code
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      debugPrint('🔑 AuthProvider: Verifying password reset code');
      // Use Firebase Auth directly for better reliability
      final email = await firebase_auth.FirebaseAuth.instance.verifyPasswordResetCode(code);
      debugPrint('✅ AuthProvider: Reset code verified for email: $email');
      return email;
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Password reset code verification error: $e');
      throw e;
    }
  }
  
  /// Completes the password reset process with a new password
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      debugPrint('🔑 AuthProvider: Confirming password reset');
      // Use Firebase Auth directly for better reliability
      await firebase_auth.FirebaseAuth.instance.confirmPasswordReset(
        code: code, 
        newPassword: newPassword
      );
      debugPrint('✅ AuthProvider: Password reset confirmed successfully');
    } catch (e) {
      debugPrint('⚠️ AuthProvider: Password reset confirmation error: $e');
      throw e;
    }
  }
}
