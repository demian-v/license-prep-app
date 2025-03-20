import '../../models/user.dart';
import 'firebase_functions_client.dart';
import 'base/auth_api_interface.dart';

class FirebaseAuthApi implements AuthApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  
  FirebaseAuthApi(this._functionsClient);
  
  /// Login using Firebase Auth
  @override
  Future<User> login(String email, String password) async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'loginUser',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      // Store token if provided
      if (response['token'] != null) {
        await _functionsClient.setAuthToken(response['token']);
      }
      
      return User.fromJson(response['user']);
    } catch (e) {
      throw 'Login failed: $e';
    }
  }
  
  /// Register a new user
  @override
  Future<User> register(String name, String email, String password) async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'registerUser',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );
      
      // Store token if provided
      if (response['token'] != null) {
        await _functionsClient.setAuthToken(response['token']);
      }
      
      return User.fromJson(response['user']);
    } catch (e) {
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
    await _functionsClient.clearAuthToken();
  }
  
  /// Creates or updates a user document in Firestore
  @override
  Future<void> createOrUpdateUserDoc(String userId, {
    required String name,
    required String email,
    String language = "ua",
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
