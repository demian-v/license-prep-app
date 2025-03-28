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
          language: 'uk', // ISO code for Ukrainian
          state: 'IL',
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
            'language': 'uk', // Default language (ISO code for Ukrainian)
            'state': 'IL',    // Default state
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
        language: 'uk', // ISO code for Ukrainian (not 'ua')
        state: 'IL',
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
      
      return User.fromJson(response);
    } catch (e) {
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
      await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateUserLanguage',
        data: {'language': language},
      );
      
      // Fetch and return the updated user
      final User? user = await getCurrentUser();
      if (user == null) {
        throw 'Failed to retrieve updated user profile';
      }
      return user;
    } catch (e) {
      throw 'Failed to update language: $e';
    }
  }
  
  /// Updates user state/region preference
  @override
  Future<User> updateUserState(String userId, String state) async {
    try {
      await _functionsClient.callFunction<Map<String, dynamic>>(
        'updateUserState',
        data: {'state': state},
      );
      
      // Fetch and return the updated user
      final User? user = await getCurrentUser();
      if (user == null) {
        throw 'Failed to retrieve updated user profile';
      }
      return user;
    } catch (e) {
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
    String language = "uk", // ISO code for Ukrainian
    String state = "IL",
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
}
