import 'package:dio/dio.dart';
import '../../models/user.dart';
import 'api_client.dart';
import 'base/auth_api_interface.dart';
import 'package:flutter/material.dart';

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
  @override
  Future<User> updateUserState(String userId, String? state) async {
    return updateProfile(userId, state: state);
  }
  
  /// Request password reset
  @override
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
  
  /// Verify password reset code
  @override
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      final response = await _apiClient.post(
        '/auth/verify-reset-code',
        data: {
          'code': code,
        },
      );
      
      // Return the email associated with the code
      return response.data['email'] as String;
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw 'Invalid or expired reset code';
      } else {
        throw 'Failed to verify reset code: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred while verifying the reset code';
    }
  }

  /// Confirm password reset with new password
  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      await _apiClient.post(
        '/auth/confirm-reset-password',
        data: {
          'code': code,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw 'Invalid or expired reset code';
      } else {
        throw 'Failed to reset password: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred while resetting the password';
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
  
  /// Reauthenticates the user with their password before sensitive operations
  @override
  Future<bool> reauthenticateUser(String password) async {
    try {
      // Call a reauthentication endpoint
      final response = await _apiClient.post(
        '/auth/reauthenticate',
        data: {
          'password': password,
        },
      );
      
      // Return true if authentication was successful
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('Reauthentication failed: Invalid password');
        return false;
      } else {
        debugPrint('Reauthentication failed: ${e.message}');
        return false;
      }
    } catch (e) {
      debugPrint('Unexpected error during reauthentication: $e');
      return false;
    }
  }
  
  /// Updates user email address with reauthentication
  @override
  Future<void> updateUserEmailSecure(String userId, String newEmail, String password) async {
    try {
      // First reauthenticate
      final reauthSuccess = await reauthenticateUser(password);
      if (!reauthSuccess) {
        throw 'Authentication failed. Please check your password and try again.';
      }
      
      // Then update email
      await updateUserEmail(userId, newEmail);
    } catch (e) {
      throw 'Secure email update failed: $e';
    }
  }
  
  /// Updates user email address
  @override
  Future<void> updateUserEmail(String userId, String email) async {
    try {
      await _apiClient.put(
        '/users/$userId/email',
        data: {
          'email': email,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Authentication required';
      } else if (e.response?.statusCode == 403) {
        throw 'Not authorized to update this email';
      } else if (e.response?.statusCode == 409) {
        throw 'Email already in use';
      } else {
        throw 'Email update failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred during email update';
    }
  }
  
  /// Deletes user account
  @override
  Future<void> deleteAccount(String userId) async {
    try {
      await _apiClient.delete('/users/$userId');
      // Also clear auth token since account is deleted
      await _apiClient.clearAuthToken();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'Authentication required';
      } else if (e.response?.statusCode == 403) {
        throw 'Not authorized to delete this account';
      } else {
        throw 'Account deletion failed: ${e.message}';
      }
    } catch (e) {
      throw 'An unexpected error occurred during account deletion';
    }
  }

  /// Creates or updates a user document in Firestore
  Future<void> createOrUpdateUserDoc(String userId, {
    required String name,
    required String email,
    String language = "en",
    String? state = null,
  }) async {
    try {
      // Try to use Cloud Function to create/update user directly
      await _apiClient.post(
        '/users/createOrUpdate',
        data: {
          'userId': userId,
          'name': name,
          'email': email,
          'language': language,
          'state': state,
        },
      );
    } catch (e) {
      // Fall back to direct Firestore access if possible
      // In a real app, you might use Firestore SDK directly here
      throw 'Failed to create user document: ${e.toString()}';
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
