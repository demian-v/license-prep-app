import '../../models/user.dart';
import 'firebase_functions_client.dart';
import 'base/auth_api_interface.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, FirebaseAuthException;

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
        // Fallback if function fails - construct basic user
        return User(
          id: userId,
          name: userCredential.user?.displayName ?? email.split('@')[0],
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
      
      // Create user document in Firestore - using try/catch to continue even if this fails
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
      } catch (firestoreError) {
        // If function call fails, log but continue - don't fail signup
        print('Warning: Failed to create user document, but auth account created: $firestoreError');
        // Could create document directly with Firestore SDK here as a fallback
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
      await _functionsClient.callFunction<Map<String, dynamic>>(
        'requestPasswordReset',
        data: {'email': email},
      );
    } catch (e) {
      // Silent catch for security reasons
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
