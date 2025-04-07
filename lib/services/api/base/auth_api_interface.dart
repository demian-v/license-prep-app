import '../../../models/user.dart';

/// Base interface for authentication API
abstract class AuthApiInterface {
  /// Logs in a user with email and password
  Future<User> login(String email, String password);
  
  /// Registers a new user
  Future<User> register(String name, String email, String password);
  
  /// Updates user profile information
  Future<User> updateProfile(String userId, {String? name, String? language, String? state});
  
  /// Updates user language preference
  Future<User> updateUserLanguage(String userId, String language);
  
  /// Updates user state/region preference
  Future<User> updateUserState(String userId, String? state);
  
  /// Updates user email address
  Future<void> updateUserEmail(String userId, String email);
  
  /// Deletes user account
  Future<void> deleteAccount(String userId);
  
  /// Request password reset
  Future<void> requestPasswordReset(String email);
  
  /// Logs the user out
  Future<void> logout();
  
  /// Creates or updates a user document in Firestore
  Future<void> createOrUpdateUserDoc(String userId, {
    required String name,
    required String email,
    String language,
    String? state,
  });
  
  /// Checks if the user is currently authenticated
  Future<bool> isAuthenticated();
  
  /// Retrieves the current user profile
  Future<User?> getCurrentUser();
}
