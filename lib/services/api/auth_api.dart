import 'package:dio/dio.dart';
import '../../models/user.dart';
import 'api_client.dart';
import 'base/auth_api_interface.dart';

class AuthApi implements AuthApiInterface {
  final ApiClient _apiClient;
  
  AuthApi(this._apiClient);
  
  /// Logs in a user with email and password
  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      // Store JWT token
      await _apiClient.setAuthToken(response.data['token']);
      
      // Return user object
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Invalid email or password';
      } else if (e.response?.statusCode == 404) {
        throw 'User not found';
      } else {
        throw 'Login failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred during login';
    }
  }
  
  /// Registers a new user
  Future<User> register(String name, String email, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
        },
      );
      
      // Store JWT token
      await _apiClient.setAuthToken(response.data['token']);
      
      // Return user object
      return User.fromJson(response.data['user']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw 'Email already in use';
      } else {
        throw 'Registration failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred during registration';
    }
  }
  
  /// Updates user profile information
  Future<User> updateProfile(String userId, {String? name, String? language, String? state}) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (language != null) data['language'] = language;
      if (state != null) data['state'] = state;
      
      final response = await _apiClient.put(
        '/users/$userId',
        data: data,
      );
      
      // Return updated user object
      return User.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Authentication required';
      } else if (e.response?.statusCode == 403) {
        throw 'Not authorized to update this profile';
      } else {
        throw 'Profile update failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred during profile update';
    }
  }
  
  /// Updates user language preference
  Future<User> updateUserLanguage(String userId, String language) async {
    return updateProfile(userId, language: language);
  }
  
  /// Updates user state/region preference
  Future<User> updateUserState(String userId, String state) async {
    return updateProfile(userId, state: state);
  }
  
  /// Request password reset
  Future<void> requestPasswordReset(String email) async {
    try {
      await _apiClient.post(
        '/auth/reset-password',
        data: {
          'email': email,
        },
      );
    } catch (e) {
      // We don't want to reveal if the email exists or not for security reasons
      // So we just let this silently succeed even if it fails
    }
  }
  
  /// Logs the user out
  Future<void> logout() async {
    try {
      // Call logout endpoint to invalidate token on server
      await _apiClient.post('/auth/logout');
    } catch (e) {
      // Even if the server call fails, we still want to clear the local token
    } finally {
      // Clear token from secure storage
      await _apiClient.clearAuthToken();
    }
  }
  
  /// Checks if the user is currently authenticated
  Future<bool> isAuthenticated() async {
    final token = await _apiClient.getAuthToken();
    return token != null;
  }
  
  /// Retrieves the current user profile
  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiClient.get('/auth/me');
      return User.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }
}
