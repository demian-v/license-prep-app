import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'firebase_functions_client.dart';
import 'base/auth_api_interface.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException, EmailAuthProvider, ActionCodeSettings;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, FieldValue, SetOptions;
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import '../../data/state_data.dart';
import '../session_manager.dart';

class FirebaseAuthApi implements AuthApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  FirebaseAuthApi(this._functionsClient);
  
  /// Login using Firebase Auth
  @override
  Future<User> login(String email, String password) async {
    try {
      // Use Firebase Auth directly for login
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Get user data from Firestore
      final userId = userCredential.user!.uid;
      final firebaseDisplayName = userCredential.user?.displayName;
      
      debugPrint('🔍 [FirebaseAuthApi] Login successful, Firebase Auth display name: $firebaseDisplayName');
      
      try {
        // Try to get from Firestore via function
        final userData = await _functionsClient.callFunction<Map<String, dynamic>>(
          'getUserData',
        );
        
        // Check if name is derived from email before returning
        if (userData['name'] != null) {
          final emailPrefix = email.split('@').first.toLowerCase();
          final currentName = userData['name'] as String;
          
          // Check if name is exactly the email prefix or very similar to it
          if (currentName.toLowerCase() == emailPrefix.toLowerCase() || 
              currentName.toLowerCase() == emailPrefix.toLowerCase().replaceAll('.', ' ')) {
            
            debugPrint('⚠️ [FirebaseAuthApi] Detected email-derived name in Firestore: $currentName');
            
            // If Firebase Auth has a non-empty display name that's different, use it instead
            if (firebaseDisplayName != null && firebaseDisplayName.isNotEmpty && 
                firebaseDisplayName.toLowerCase() != emailPrefix.toLowerCase()) {
              
              debugPrint('✅ [FirebaseAuthApi] Using Firebase Auth display name: $firebaseDisplayName instead of email-derived name');
              userData['name'] = firebaseDisplayName;
              
              // Update Firestore with the correct name
              try {
                await _firestore.collection('users').doc(userId).update({
                  'name': firebaseDisplayName,
                  'lastUpdated': FieldValue.serverTimestamp(),
                });
                debugPrint('✅ [FirebaseAuthApi] Updated Firestore with correct name: $firebaseDisplayName');
              } catch (e) {
                debugPrint('⚠️ [FirebaseAuthApi] Failed to update Firestore with correct name: $e');
              }
            }
          }
        }
        
        // Create User object from userData
        final user = User.fromJson(userData);
        
        // Add session management
        try {
          debugPrint('🔐 FirebaseAuthApi: Creating session for user: ${userId}');
          final sessionId = await sessionManager.createSession(userId);
          
          // Start session monitoring
          await sessionManager.startSessionMonitoring(userId);
          
          debugPrint('✅ FirebaseAuthApi: Session created and monitoring started');
          
          // Return user with session ID
          return user.copyWith(currentSessionId: sessionId);
        } catch (sessionError) {
          debugPrint('⚠️ FirebaseAuthApi: Session creation failed: $sessionError');
          // Still return user even if session creation fails
          return user;
        }
      } catch (firestoreError) {
        debugPrint('Warning: Failed to get user data from function: $firestoreError');
        
        // Attempt to get data directly from Firestore
        try {
          final firestore = FirebaseFirestore.instance;
          final docSnapshot = await firestore.collection('users').doc(userId).get();
          
          if (docSnapshot.exists && docSnapshot.data()?['name'] != null) {
            debugPrint('Retrieved user data directly from Firestore');
            return User(
              id: userId,
              name: userCredential.user?.displayName ?? email.split('@')[0],
              email: email,
              language: 'en',
              state: null,
              createdAt: DateTime.now(),
            );
          }
        } catch (directFirestoreError) {
          debugPrint('Warning: Failed to get user data directly from Firestore: $directFirestoreError');
        }
        
        // Final fallback if all methods fail - construct basic user
        // When creating a fallback user, prioritize any available displayName from auth
        // This ensures that if the user set their name during signup, it's maintained
        String userName = userCredential.user?.displayName ?? "";
        
        // Only use email as fallback if we have no display name at all
        if (userName.isEmpty) {
          // This is just a last resort fallback - we should have a name from signup
          userName = "User";
        }
        
        return User(
          id: userId,
          name: userName, // Use display name instead of email
          email: email,
          language: 'en', // Updated to English
          state: null,    // No default state
          createdAt: DateTime.now(),
        );
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          throw 'Login failed: No user found with this email.';
        } else if (e.code == 'wrong-password') {
          throw 'Login failed: Wrong password.';
        } else {
          throw 'Login failed: ${e.message}';
        }
      }
      throw 'Login failed: $e';
    }
  }
  
  /// Register a new user
  @override
  Future<User> register(String name, String email, String password) async {
    try {
      debugPrint('🔍 [FirebaseAuthApi] Starting registration for email: $email with name: $name');
      
      // First use Firebase Auth directly to create the user
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Risk #12 — send the verification email. sendEmailVerification() was
      // never called anywhere in the app, so `emailVerified` stayed false for
      // every account forever, and the EmailVerificationScreen deep-link flow
      // wired up in main.dart was unreachable dead code.
      //
      // Deliberately non-fatal: a mail failure must not cost the user the
      // account they have just created.
      try {
        await userCredential.user!.sendEmailVerification();
        debugPrint('📧 [FirebaseAuthApi] Verification email sent to: $email');
      } catch (e) {
        debugPrint('⚠️ [FirebaseAuthApi] Could not send verification email: $e');
      }

      // Update display name
      await userCredential.user!.updateDisplayName(name);
      debugPrint('✅ [FirebaseAuthApi] Display name set to: $name');
      
      // Need to reload user to ensure the display name is available
      await userCredential.user!.reload();
      
      // Verify the display name was set correctly
      final createdUser = auth.currentUser;
      if (createdUser != null) {
        if (createdUser.displayName == null || createdUser.displayName != name) {
          // Force update display name again if it didn't take
          await createdUser.updateDisplayName(name);
          await createdUser.reload();
          debugPrint('⚠️ [FirebaseAuthApi] Display name was not set correctly, fixed it to: $name');
        }
      }
      
      // Explicitly check for any default values that might be coming from the system
      final newUser = auth.currentUser;
      if (newUser != null) {
        // Check for any metadata that might have incorrect default values
        debugPrint('🔍 [FirebaseAuthApi] New user properties:');
        debugPrint('    - UID: ${newUser.uid}');
        debugPrint('    - Display Name: ${newUser.displayName}');
        debugPrint('    - Email: ${newUser.email}');
        debugPrint('    - Email Verified: ${newUser.emailVerified}');
        debugPrint('    - Phone Number: ${newUser.phoneNumber}');
        // Try to get metadata or additional attributes
        debugPrint('    - Metadata: creation=${newUser.metadata.creationTime}, last sign in=${newUser.metadata.lastSignInTime}');
      }
      
      // Create user document in Firestore and ensure it's created successfully
      try {
        // Explicitly set correct default values - language "en" and state null
        // Note: Don't send FieldValue objects to Firebase Functions - let server handle timestamps
        final userData = {
          'userId': userCredential.user!.uid,
          'name': name,
          'email': email,
          'language': 'en', // Explicitly set to English
          'state': null,     // Explicitly set to null
        };
        
        debugPrint('🔄 [FirebaseAuthApi] Creating user document with data:');
        debugPrint('    - language: ${userData['language']}');
        debugPrint('    - state: ${userData['state']}');
        
        await _functionsClient.callFunction<Map<String, dynamic>>(
          'createOrUpdateUserDocument',
          data: userData,
        );
        debugPrint('✅ [FirebaseAuthApi] User document created successfully with name: $name');
      } catch (firestoreError) {
        debugPrint('⚠️ [FirebaseAuthApi] Warning: Failed to create user document: $firestoreError');
        
        // Implement fallback using Firestore SDK directly
        try {
          final firestore = FirebaseFirestore.instance;
          
          // Explicitly set default values
          final firestoreData = {
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'language': 'en',    // Explicitly set to English
            'state': null,       // Explicitly set to null
          };
          
          debugPrint('🔄 [FirebaseAuthApi] Creating user document with fallback method:');
          debugPrint('    - language: ${firestoreData['language']}');
          debugPrint('    - state: ${firestoreData['state']}');
          
          await firestore.collection('users').doc(userCredential.user!.uid).set(firestoreData);
          debugPrint('✅ [FirebaseAuthApi] User document created with fallback method');
          
          // Verify document was created with correct values
          final docSnapshot = await firestore.collection('users').doc(userCredential.user!.uid).get();
          if (docSnapshot.exists) {
            final data = docSnapshot.data();
            debugPrint('🔍 [FirebaseAuthApi] Verifying created document:');
            debugPrint('    - language: ${data?['language']}');
            debugPrint('    - state: ${data?['state']}');
          }
        } catch (directFirestoreError) {
          debugPrint('❌ [FirebaseAuthApi] Failed to create user document with fallback: $directFirestoreError');
          // Continue with signup but warn about potential issues
        }
      }
      
      // Return user data with explicitly defined defaults
      return User(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        language: 'en', // Explicitly set to English
        state: null,    // Explicitly set to null
        createdAt: DateTime.now(),
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        if (e.code == 'email-already-in-use') {
          throw 'Registration failed: The email address is already in use.';
        } else if (e.code == 'weak-password') {
          throw 'Registration failed: The password is too weak.';
        } else {
          throw 'Registration failed: ${e.message}';
        }
      }
      throw 'Registration failed: $e';
    }
  }
  
  /// Gets the current user's data from Firestore
  @override
  Future<User?> getCurrentUser() async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getUserData',
      );
      
      // Add safeguards against null or invalid data
      if (response == null) {
        debugPrint('Warning: getUserData returned null response');
        return null;
      }
      
      // Ensure all required fields exist
      if (!response.containsKey('id') && response.containsKey('uid')) {
        // Fix common issue where Firebase returns uid instead of id
        response['id'] = response['uid'];
      }
      
      // Check if any required fields are null or missing
      if (response['id'] == null || 
          response['name'] == null || 
          response['email'] == null) {
        debugPrint('Warning: User data is missing required fields: $response');
        return null;
      }
      
      // Safe to create the user now
      return User.fromJson(response);
    } catch (e) {
      debugPrint('Error in getCurrentUser: $e');
      throw 'Failed to get user data: $e';
    }
  }
  
  /// Updates a user's profile information
  @override
  Future<User> updateProfile(String userId, {String? name, String? language, String? state}) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (language != null) data['language'] = language;
      
      // Handle state conversion if needed
      if (state != null) {
        // Convert to state ID if it's a full name
        if (state.length > 2) {
          final stateInfo = StateData.getStateByName(state);
          if (stateInfo != null) {
            debugPrint('🔄 [API] Converting state name "$state" to ID: "${stateInfo.id}"');
            data['state'] = stateInfo.id;
          } else {
            data['state'] = state;
          }
        } else {
          data['state'] = state;
        }
      }
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateProfile',
        data: data,
      );
      
      return User.fromJson(response);
    } catch (e) {
      throw 'Profile update failed: $e';
    }
  }
  
  /// Helper method to create user object with updated language
  /// Tries to preserve current state when updating language
  User _createUserWithLanguage(String userId, String language) {
    final currentAuth = FirebaseAuth.instance.currentUser;
    if (currentAuth != null) {
      // Try to get current state from Firestore to preserve it
      String? currentState;
      
      // We can't await here since this is not an async method, 
      // so we'll just return a basic user for now and let the calling method handle state preservation
      return User(
        id: userId,
        name: currentAuth.displayName ?? "User",
        email: currentAuth.email ?? "",
        language: language,
        state: null, // State will be handled separately by the calling methods
        createdAt: DateTime.now(),
      );
    }
    throw 'No authenticated user found';
  }

  /// Helper method to create user object with updated state
  /// Tries to preserve current language when updating state
  User _createUserWithState(String userId, String? stateId) {
    final currentAuth = FirebaseAuth.instance.currentUser;
    if (currentAuth != null) {
      return User(
        id: userId,
        name: currentAuth.displayName ?? "User",
        email: currentAuth.email ?? "",
        language: 'en', // Default language - will be preserved by calling method
        state: stateId,
        createdAt: DateTime.now(),
      );
    }
    throw 'No authenticated user found';
  }

  /// Updates user language preference
  @override
  Future<User> updateUserLanguage(String userId, String language) async {
    try {
      // STEP 1: Try Firebase Functions (PRIMARY METHOD)
      debugPrint('🔤 [API] Updating user language to $language via Firebase function');
      
      try {
        final result = await _functionsClient.callFunction<Map<String, dynamic>>(
          'updateUserLanguage',
          data: {'language': language},
        );
        
        // Check if we got a proper success response
        if (result != null && result['success'] == true) {
          debugPrint('✅ [API] Language updated successfully via Firebase function');
          return _createUserWithLanguage(userId, language);
        }
      } catch (functionError) {
        debugPrint('❌ [API] Firebase function failed: $functionError, trying direct Firestore fallback...');
      }
      
      // STEP 2: Fallback to direct Firestore update
      debugPrint('🔄 [API] Using direct Firestore fallback for language update');
      
      await _firestore.collection('users').doc(userId).update({
        'language': language,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ [API] Language updated successfully via direct Firestore');
      
      // Verify the update was successful
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final updatedLanguage = userData['language'];
        debugPrint('✅ [API] Verified language update in Firestore: $updatedLanguage');
        
        if (updatedLanguage == language) {
          debugPrint('✅ [API] Firestore language update confirmed');
          return _createUserWithLanguage(userId, language);
        } else {
          debugPrint('⚠️ [API] Language verification mismatch - expected: $language, actual: $updatedLanguage');
        }
      }
      
      return _createUserWithLanguage(userId, language);
      
    } catch (e) {
      debugPrint('❌ [API] All language update methods failed: $e');
      throw 'Failed to update language: $e';
    }
  }
  
  /// Updates user state/region preference
  @override
  Future<User> updateUserState(String userId, String? state) async {
    try {
      // Ensure we're using the state ID and not a full state name or "null" string
      String? stateId = state;
      
      // If state is "null" as a string, convert to actual null
      if (state == "null") {
        debugPrint('⚠️ [API] "null" string detected, converting to actual null');
        stateId = null;
      }
      // If state is a full state name (longer than 2 chars), try to convert it to state ID
      else if (state != null && state.length > 2) {
        try {
          final stateInfo = StateData.getStateByName(state);
          if (stateInfo != null) {
            stateId = stateInfo.id;
            debugPrint('🔄 [API] Converted state name "$state" to ID: "$stateId"');
          } else {
            debugPrint('⚠️ [API] Could not convert state name to ID: $state');
          }
        } catch (e) {
          debugPrint('⚠️ [API] Error converting state name to ID: $e');
        }
      }
      
      // STEP 1: Try Firebase Functions (PRIMARY METHOD)
      debugPrint('🗺️ [API] Updating user state to ${stateId ?? "null"} via Firebase function');
      
      try {
        final result = await _functionsClient.callFunction<Map<String, dynamic>>(
          'updateUserState',
          data: {'state': stateId},
        );
        
        // Check if we got a proper success response
        if (result != null && result['success'] == true) {
          debugPrint('✅ [API] State updated successfully via Firebase function');
          
          // Try to get current language to preserve it
          String currentLanguage = 'en'; // Default to English
          try {
            final currentUser = await getCurrentUser();
            if (currentUser != null && currentUser.language != null) {
              currentLanguage = currentUser.language ?? 'en';
            }
          } catch (e) {
            debugPrint('⚠️ Could not get current language, using default');
          }
          
          // Create user with preserved language and new state
          final currentAuth = FirebaseAuth.instance.currentUser;
          if (currentAuth != null) {
            return User(
              id: userId,
              name: currentAuth.displayName ?? "User",
              email: currentAuth.email ?? "",
              language: currentLanguage,
              state: stateId,
              createdAt: DateTime.now(),
            );
          }
          return _createUserWithState(userId, stateId);
        }
      } catch (functionError) {
        debugPrint('❌ [API] Firebase function failed: $functionError, trying direct Firestore fallback...');
      }
      
      // STEP 2: Fallback to direct Firestore update
      debugPrint('🔄 [API] Using direct Firestore fallback for state update');
      
      await _firestore.collection('users').doc(userId).update({
        'state': stateId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ [API] State updated successfully via direct Firestore');
      
      // Verify the update was successful
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final updatedState = userData['state'];
        debugPrint('✅ [API] Verified state update in Firestore: $updatedState');
        
        if (updatedState == stateId) {
          debugPrint('✅ [API] Firestore state update confirmed');
        } else {
          debugPrint('⚠️ [API] State verification mismatch - expected: $stateId, actual: $updatedState');
        }
        
        // Get current language to preserve it
        final currentLanguage = userData['language'] ?? 'en';
        
        // Create user with preserved language and new state
        final currentAuth = FirebaseAuth.instance.currentUser;
        if (currentAuth != null) {
          return User(
            id: userId,
            name: currentAuth.displayName ?? "User",
            email: currentAuth.email ?? "",
            language: currentLanguage,
            state: stateId,
            createdAt: DateTime.now(),
          );
        }
      }
      
      return _createUserWithState(userId, stateId);
      
    } catch (e) {
      debugPrint('❌ [API] All state update methods failed: $e');
      throw 'Failed to update state: $e';
    }
  }
  
  /// Request password reset
  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      // Define ActionCodeSettings to ensure proper redirection
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://licenseprepapp.web.app/password-reset.html',
        handleCodeInApp: true,
        androidPackageName: 'com.license.prep.app',
        androidInstallApp: true,
        androidMinimumVersion: '12',
        iOSBundleId: 'com.license.prep.app',
      );
      
      // First try to use Firebase Auth directly for more control over redirects
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: actionCodeSettings,
        );
        debugPrint('✅ [API] Password reset email sent directly via Firebase Auth');
        return;
      } catch (directAuthError) {
        debugPrint('⚠️ [API] Error sending reset email directly: $directAuthError, falling back to function');
        // Fall back to cloud function if direct method fails
        await _functionsClient.callFunction<Map<String, dynamic>>(
          'requestPasswordReset',
          data: {
            'email': email,
            'redirectUrl': 'https://licenseprepapp.web.app/password-reset.html',
          },
        );
      }
    } catch (e) {
      debugPrint('❌ [API] Error in password reset: $e');
      // Silent catch for security reasons - don't expose whether email exists
    }
  }
  
  /// Verify password reset code
  @override
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      final auth = FirebaseAuth.instance;
      return await auth.verifyPasswordResetCode(code);
    } catch (e) {
      debugPrint('❌ [API] Error verifying password reset code: $e');
      throw 'Invalid or expired password reset link. Please request a new link.';
    }
  }

  /// Confirm password reset with new password
  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      final auth = FirebaseAuth.instance;
      await auth.confirmPasswordReset(
        code: code, 
        newPassword: newPassword
      );
      debugPrint('✅ [API] Password reset successfully confirmed');
    } catch (e) {
      debugPrint('❌ [API] Error confirming password reset: $e');
      throw 'Failed to reset password. Please try again.';
    }
  }
  
  /// Checks if the user is currently authenticated
  @override
  Future<bool> isAuthenticated() async {
    final token = await _functionsClient.getAuthToken();
    return token != null;
  }
  
  /// Logs the user out (clears the token)
  @override
  Future<void> logout() async {
    try {
      // Get current user for session cleanup
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('🚪 FirebaseAuthApi: Invalidating session for user: ${currentUser.uid}');
        try {
          await sessionManager.invalidateSession(currentUser.uid);
        } catch (sessionError) {
          debugPrint('⚠️ FirebaseAuthApi: Session invalidation error: $sessionError');
        }
      }
      
      // Sign out from Firebase Auth first
      await FirebaseAuth.instance.signOut();
      
      // Then clear any stored tokens
      await _functionsClient.clearAuthToken();
    } catch (e) {
      // Even if Firebase logout fails, try to clear tokens
      await _functionsClient.clearAuthToken();
      rethrow;
    }
  }
  
  /// Creates or updates a user document in Firestore
  @override
  Future<void> createOrUpdateUserDoc(String userId, {
    required String name,
    required String email,
    String language = "en",   // Changed to English default
    String? state,            // Changed to null for no default state
  }) async {
    try {
      await _functionsClient.callFunction<Map<String, dynamic>>(
        'createOrUpdateUserDocument',
        data: {
          'userId': userId,
          'name': name,
          'email': email,
          'language': language,
          'state': state,
        },
      );
    } catch (e) {
      throw 'Failed to create user document: $e';
    }
  }
  
  /// Reauthenticates the user with their password before sensitive operations
  @override
  Future<bool> reauthenticateUser(String password) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        debugPrint('❌ [API] Reauthentication failed: No user is logged in or email is null');
        return false;
      }
      
      // Create a credential with the current email and provided password
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      
      // Reauthenticate
      await currentUser.reauthenticateWithCredential(credential);
      debugPrint('✅ [API] User reauthenticated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [API] Reauthentication failed: $e');
      return false;
    }
  }
  
  /// Updates user email address
  @override
  Future<void> updateUserEmail(String userId, String email) async {
    try {
      debugPrint('📧 [API] Updating user email to $email via Firebase function');
      
      // Update email in Firebase Auth first
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth == null) {
        throw 'No authenticated user found';
      }
      
      // Update email in Firebase Auth (use verifyBeforeUpdateEmail for security)
      await currentAuth.verifyBeforeUpdateEmail(email);
      
      // Then update in Firestore via function
      final result = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateUserEmail',
        data: {'email': email},
      );
      
      if (result == null || result['success'] != true) {
        throw 'Failed to update email in database';
      }
      
      debugPrint('✅ [API] Email updated successfully');
    } catch (e) {
      debugPrint('❌ [API] Error updating email: $e');
      throw 'Failed to update email: $e';
    }
  }
  
  /// Updates user email address with reauthentication
  /// 
  /// This method sends a verification email to the new address.
  /// The email in Firebase Auth will only be updated after the user clicks the verification link.
  /// The Firestore database email will be updated automatically by EmailSyncService when:
  /// 1. The app detects the auth state change (if app is running)
  /// 2. Next time the app starts up (if app was closed during verification)
  /// 3. Next time the user logs in (as an additional safety measure)
  @override
  Future<void> updateUserEmailSecure(String userId, String newEmail, String password) async {
    try {
      debugPrint('📧 [API] Updating email securely to $newEmail');
      
      // First reauthenticate the user
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth == null || currentAuth.email == null) {
        throw 'No authenticated user found or email is null';
      }
      
      // Create a credential with the current email and provided password
      final credential = EmailAuthProvider.credential(
        email: currentAuth.email!,
        password: password,
      );
      
      // Reauthenticate
      await currentAuth.reauthenticateWithCredential(credential);
      debugPrint('✅ [API] User reauthenticated successfully');
      
      // Instead of directly updating email, send a verification email to the new address
      await currentAuth.verifyBeforeUpdateEmail(newEmail);
      
      debugPrint('✅ [API] Verification email sent to $newEmail. User must verify before email is updated');
      
      // We don't update Firestore here because the email hasn't actually changed yet
      // Firebase will update the email after the user clicks the verification link
      // EmailSyncService will handle synchronizing the email to Firestore after verification
    } catch (e) {
      if (e.toString().contains('auth/requires-recent-login')) {
        throw 'Authentication required. Please log out and log back in before changing your email.';
      } else if (e.toString().contains('auth/invalid-credential') || 
                e.toString().contains('auth/wrong-password') ||
                e.toString().contains('auth/user-mismatch')) {
        throw 'Authentication failed. Incorrect password.';
      } else {
        debugPrint('❌ [API] Error during secure email update: $e');
        throw 'Failed to update email: $e';
      }
    }
  }
  
  /// Deletes user account with backup mechanism
  @override
  Future<void> deleteAccount(String userId) async {
    try {
      // STEP 1: Try Firebase Functions (PRIMARY METHOD)
      debugPrint('🗑️ [API] Deleting user account via Firebase function');
      
      try {
        final result = await _functionsClient.callFunction<Map<String, dynamic>>(
          'deleteUserAccount',
          data: {'userId': userId},
        );
        
        // Check if we got a proper success response
        if (result != null && result['success'] == true) {
          debugPrint('✅ [API] Account deleted successfully via Firebase function');
          
          // Function succeeded and already deleted everything including Firebase Auth user
          // Just clear tokens - no need to delete Firebase Auth user again
          await _functionsClient.clearAuthToken();
          debugPrint('✅ [API] Account deletion completed via Firebase function');
          return;
        }
      } on FirebaseFunctionsException catch (functionError) {
        // Risks #13 and #14 — the client fallback below used to run on ANY
        // failure. It deleted only users/{uid}, leaving seven other locations
        // of personal data behind while reporting the account "deleted", and
        // it bypassed the server's recent-login requirement entirely.
        //
        // A deliberate refusal from the server is an answer, not an outage:
        // surface it so the user can sign in again and retry. Falling back
        // here would have silently defeated the reauthentication gate.
        if (functionError.code == 'failed-precondition'
            || functionError.code == 'permission-denied'
            || functionError.code == 'unauthenticated') {
          debugPrint('🚫 [API] Server refused deletion (${functionError.code}); not falling back');
          rethrow;
        }
        debugPrint('❌ [API] Firebase function unavailable: $functionError, trying direct fallback...');
      } catch (functionError) {
        debugPrint('❌ [API] Firebase function failed: $functionError, trying direct fallback...');
      }

      // STEP 2: Fallback for genuine unavailability only. This is a PARTIAL
      // deletion — it removes the user document and the Auth account, but not
      // the other personal data the callable handles. It exists so a user is
      // not trapped while Functions is down; the callable remains the complete
      // path, and the server-side data is cleaned up when it next succeeds.
      debugPrint('🔄 [API] Using direct Firebase fallback for account deletion (PARTIAL)');

      // Delete user document from Firestore directly
      try {
        await _firestore.collection('users').doc(userId).delete();
        debugPrint('✅ [API] User document deleted from Firestore via fallback');
      } catch (firestoreError) {
        debugPrint('⚠️ [API] Failed to delete user document from Firestore: $firestoreError');
        // Continue with auth deletion even if Firestore fails
      }
      
      // Delete Firebase Auth user
      await _deleteFirebaseAuthUser();
      
      // Clear tokens
      await _functionsClient.clearAuthToken();
      
      debugPrint('✅ [API] Account deletion completed via direct fallback');
      
    } catch (e) {
      debugPrint('❌ [API] Error deleting account: $e');
      
      // Try to clear tokens even if account deletion failed
      try {
        await _functionsClient.clearAuthToken();
      } catch (tokenError) {
        debugPrint('⚠️ [API] Failed to clear tokens: $tokenError');
      }
      
      throw 'Failed to delete account: $e';
    }
  }

  /// Helper method to delete Firebase Auth user with proper error handling
  Future<void> _deleteFirebaseAuthUser() async {
    try {
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth == null) {
        debugPrint('⚠️ [API] No Firebase Auth user found to delete');
        return;
      }
      
      await currentAuth.delete();
      debugPrint('✅ [API] Firebase Auth user deleted successfully');
    } catch (authError) {
      debugPrint('❌ [API] Error deleting Firebase Auth user: $authError');
      
      // Check for specific auth errors that might require reauthentication
      if (authError.toString().contains('requires-recent-login')) {
        throw 'Account deletion requires recent authentication. Please log out and log back in, then try again.';
      } else {
        throw 'Failed to delete Firebase Auth user: $authError';
      }
    }
  }
}
