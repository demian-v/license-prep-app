import '../../models/user.dart';
import 'firebase_functions_client.dart';
import 'base/auth_api_interface.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException, EmailAuthProvider, ActionCodeSettings;
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, FieldValue, SetOptions;

class FirebaseAuthApi implements AuthApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  
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
      
      try {
        // Try to get from Firestore via function
        final userData = await _functionsClient.callFunction<Map<String, dynamic>>(
          'getUserData',
        );
        
        return User.fromJson(userData);
      } catch (firestoreError) {
        print('Warning: Failed to get user data from function: $firestoreError');
        
        // Attempt to get data directly from Firestore
        try {
          final firestore = FirebaseFirestore.instance;
          final docSnapshot = await firestore.collection('users').doc(userId).get();
          
          if (docSnapshot.exists && docSnapshot.data()?['name'] != null) {
            print('Retrieved user data directly from Firestore');
            return User(
              id: userId,
              name: docSnapshot.data()?['name'],
              email: email,
              language: docSnapshot.data()?['language'] ?? 'en',
              state: docSnapshot.data()?['state'],
            );
          }
        } catch (directFirestoreError) {
          print('Warning: Failed to get user data directly from Firestore: $directFirestoreError');
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
      // First use Firebase Auth directly to create the user
      final auth = FirebaseAuth.instance;
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user!.updateDisplayName(name);
      
      // Need to reload user to ensure the display name is available
      await userCredential.user!.reload();
      
      // Create user document in Firestore and ensure it's created successfully
      try {
        await _functionsClient.callFunction<Map<String, dynamic>>(
          'createOrUpdateUserDocument',
          data: {
            'userId': userCredential.user!.uid,
            'name': name,
            'email': email,
            'language': 'en', // Default language (English)
            'state': null,    // No default state - user will select explicitly
          },
        );
        print('✅ User document created successfully with name: $name');
      } catch (firestoreError) {
        print('⚠️ Warning: Failed to create user document: $firestoreError');
        
        // Implement fallback using Firestore SDK directly
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(userCredential.user!.uid).set({
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
            'language': 'en',
            'state': null,
          });
          print('✅ User document created with fallback method');
        } catch (directFirestoreError) {
          print('❌ Failed to create user document with fallback: $directFirestoreError');
          // Continue with signup but warn about potential issues
        }
      }
      
      // Return user data
      return User(
        id: userCredential.user!.uid,
        name: name,
        email: email,
        language: 'en', // Default language (English)
        state: null,    // No default state
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
        print('Warning: getUserData returned null response');
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
        print('Warning: User data is missing required fields: $response');
        return null;
      }
      
      // Safe to create the user now
      return User.fromJson(response);
    } catch (e) {
      print('Error in getCurrentUser: $e');
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
      if (state != null) data['state'] = state;
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateProfile',
        data: data,
      );
      
      return User.fromJson(response);
    } catch (e) {
      throw 'Profile update failed: $e';
    }
  }
  
  /// Updates user language preference
  @override
  Future<User> updateUserLanguage(String userId, String language) async {
    try {
      print('🔤 [API] Updating user language to $language via Firebase function');
      final result = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateUserLanguage',
        data: {'language': language},
      );
      
      // Check if we got a proper success response
      if (result != null && result['success'] == true) {
        // Create a locally updated user with the new language
        // This prevents issues with the getUserData function
        final currentAuth = FirebaseAuth.instance.currentUser;
        if (currentAuth != null) {
          print('✅ [API] Language updated successfully, creating local user object');
          return User(
            id: userId,
            name: currentAuth.displayName ?? "User",
            email: currentAuth.email ?? "",
            language: language,
            state: null, // We don't know the state, leave it null
          );
        }
      }
      
      // Try to fetch the updated user as a fallback
      print('🔍 [API] Getting updated user data after language change');
      final User? user = await getCurrentUser();
      if (user == null) {
        print('❌ [API] Failed to get updated user after language change');
        // Fallback to returning a basic user with the updated language
        final currentAuth = FirebaseAuth.instance.currentUser;
        if (currentAuth != null) {
          return User(
            id: userId,
            name: currentAuth.displayName ?? "User",
            email: currentAuth.email ?? "",
            language: language,
            state: null, // We don't know the state, leave it null
          );
        }
        throw 'Failed to retrieve updated user profile';
      }
      
      print('✅ [API] Successfully updated language, user language is now: ${user.language}');
      return user;
    } catch (e) {
      print('❌ [API] Error updating language: $e');
      // Fallback to returning a user with the requested language
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth != null) {
        print('⚠️ Using fallback user creation with updated language');
        return User(
          id: userId,
          name: currentAuth.displayName ?? "User",
          email: currentAuth.email ?? "",
          language: language,
          state: null, // We don't know the state, leave it null
        );
      }
      throw 'Failed to update language: $e';
    }
  }
  
  /// Updates user state/region preference
  @override
  Future<User> updateUserState(String userId, String? state) async {
    try {
      print('🗺️ [API] Updating user state to ${state ?? "null"} via Firebase function');
      final result = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateUserState',
        data: {'state': state},
      );
      
      // Check if we got a proper success response
      if (result != null && result['success'] == true) {
        // Try to get the current language
        final currentAuth = FirebaseAuth.instance.currentUser;
        String? currentLanguage = 'en'; // Default to English
        
        try {
          // Try to get current language from stored user data
          final currentUser = await getCurrentUser();
          if (currentUser != null && currentUser.language != null) {
            currentLanguage = currentUser.language;
          }
        } catch (e) {
          // Ignore error, we'll use the default
          print('⚠️ Could not get current language, using default');
        }
        
        // Create a locally updated user with the new state
        if (currentAuth != null) {
          print('✅ [API] State updated successfully, creating local user object');
          return User(
            id: userId,
            name: currentAuth.displayName ?? "User",
            email: currentAuth.email ?? "",
            language: currentLanguage,
            state: state,
          );
        }
      }
      
      // Try to fetch the updated user as a fallback
      print('🔍 [API] Getting updated user data after state change');
      final User? user = await getCurrentUser();
      if (user == null) {
        print('❌ [API] Failed to get updated user after state change');
        // Fallback to returning a basic user with the updated state
        final currentAuth = FirebaseAuth.instance.currentUser;
        if (currentAuth != null) {
          return User(
            id: userId,
            name: currentAuth.displayName ?? "User",
            email: currentAuth.email ?? "",
            language: 'en', // Default to English
            state: state,
          );
        }
        throw 'Failed to retrieve updated user profile';
      }
      
      print('✅ [API] Successfully updated state, user state is now: ${user.state}');
      return user;
    } catch (e) {
      print('❌ [API] Error updating state: $e');
      // Fallback to returning a user with the requested state
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth != null) {
        print('⚠️ Using fallback user creation with updated state');
        return User(
          id: userId,
          name: currentAuth.displayName ?? "User",
          email: currentAuth.email ?? "",
          language: 'en', // Default to English
          state: state,
        );
      }
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
        print('✅ [API] Password reset email sent directly via Firebase Auth');
        return;
      } catch (directAuthError) {
        print('⚠️ [API] Error sending reset email directly: $directAuthError, falling back to function');
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
      print('❌ [API] Error in password reset: $e');
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
      print('❌ [API] Error verifying password reset code: $e');
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
      print('✅ [API] Password reset successfully confirmed');
    } catch (e) {
      print('❌ [API] Error confirming password reset: $e');
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
    String? state = null,    // Changed to null for no default state
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
        print('❌ [API] Reauthentication failed: No user is logged in or email is null');
        return false;
      }
      
      // Create a credential with the current email and provided password
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      
      // Reauthenticate
      await currentUser.reauthenticateWithCredential(credential);
      print('✅ [API] User reauthenticated successfully');
      return true;
    } catch (e) {
      print('❌ [API] Reauthentication failed: $e');
      return false;
    }
  }
  
  /// Updates user email address
  @override
  Future<void> updateUserEmail(String userId, String email) async {
    try {
      print('📧 [API] Updating user email to $email via Firebase function');
      
      // Update email in Firebase Auth first
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth == null) {
        throw 'No authenticated user found';
      }
      
      // Update email in Firebase Auth
      await currentAuth.updateEmail(email);
      
      // Then update in Firestore via function
      final result = await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateUserEmail',
        data: {'email': email},
      );
      
      if (result == null || result['success'] != true) {
        throw 'Failed to update email in database';
      }
      
      print('✅ [API] Email updated successfully');
    } catch (e) {
      print('❌ [API] Error updating email: $e');
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
      print('📧 [API] Updating user email with reauthentication');
      
      // First reauthenticate
      final reauthSuccess = await reauthenticateUser(password);
      if (!reauthSuccess) {
        throw 'Authentication failed. Please check your password and try again.';
      }
      
      // Get current user
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth == null) {
        throw 'No authenticated user found';
      }
      
      try {
        // Instead of directly updating email, send a verification email to the new address
        await currentAuth.verifyBeforeUpdateEmail(newEmail);
        
        print('✅ [API] Verification email sent to $newEmail. User must verify before email is updated');
        
        // We don't update Firestore here because the email hasn't actually changed yet
        // Firebase will update the email after the user clicks the verification link
        // EmailSyncService will handle synchronizing the email to Firestore after verification
        
        return;
      } catch (e) {
        if (e.toString().contains('auth/requires-recent-login')) {
          throw 'Authentication required. Please log out and log back in before changing your email.';
        } else {
          throw 'Failed to send verification email: $e';
        }
      }
    } catch (e) {
      print('❌ [API] Error updating email: $e');
      throw 'Failed to update email: $e';
    }
  }
  
  /// Deletes user account
  @override
  Future<void> deleteAccount(String userId) async {
    try {
      print('🗑️ [API] Deleting user account via Firebase function');
      
      // Delete account in Firestore first via function
      final result = await _functionsClient.callFunction<Map<String, dynamic>>(
        'deleteUserAccount',
        data: {'userId': userId},
      );
      
      // Then delete the Firebase Auth user
      final currentAuth = FirebaseAuth.instance.currentUser;
      if (currentAuth == null) {
        throw 'No authenticated user found';
      }
      
      await currentAuth.delete();
      
      // Clear any stored tokens
      await _functionsClient.clearAuthToken();
      
      print('✅ [API] Account deleted successfully');
    } catch (e) {
      print('❌ [API] Error deleting account: $e');
      
      // Try to clear tokens even if account deletion failed
      await _functionsClient.clearAuthToken();
      
      throw 'Failed to delete account: $e';
    }
  }
}
