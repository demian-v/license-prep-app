import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user.dart' as app_models;
import '../services/api/base/auth_api_interface.dart';

/// A service class that directly interacts with Firebase Auth and Firestore
/// without any abstractions or complex mappings
class DirectAuthService implements AuthApiInterface {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign up a new user directly with Firebase
  Future<bool> signUp(String name, String email, String password) async {
    // Step 1: Create the Auth user
    try {
      debugPrint('🔍 [DirectAuthService] Creating auth user for email: $email');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        debugPrint('❌ [DirectAuthService] Auth user creation failed - no user returned');
        return false;
      }
      
      final userId = firebaseUser.uid;
      debugPrint('✅ [DirectAuthService] Auth user created with ID: $userId');
      
      // Check for any initial system-provided values
      debugPrint('🔍 [DirectAuthService] Checking new user properties:');
      debugPrint('    - UID: ${firebaseUser.uid}');
      debugPrint('    - Display Name: ${firebaseUser.displayName}');
      debugPrint('    - Email: ${firebaseUser.email}');
      debugPrint('    - Email Verified: ${firebaseUser.emailVerified}');
      debugPrint('    - Metadata: creation=${firebaseUser.metadata.creationTime}, last sign in=${firebaseUser.metadata.lastSignInTime}');
      
      // Step 2: Update the display name
      try {
        await firebaseUser.updateDisplayName(name);
        debugPrint('✅ [DirectAuthService] Updated display name to: $name');
      } catch (e) {
        debugPrint('⚠️ [DirectAuthService] Error updating display name: $e');
        // Continue even if this fails
      }
      
      // Step 3: Create Firestore user documents immediately and await it
      // to ensure the document is created before proceeding
      await createUserDocuments(userId, name, email);
      
      // Verify the document was created with correct values
      try {
        final docSnapshot = await _firestore.collection('users').doc(userId).get();
        if (docSnapshot.exists) {
          final userData = docSnapshot.data();
          debugPrint('🔍 [DirectAuthService] Verifying created document:');
          debugPrint('    - language: ${userData?['language']}');
          debugPrint('    - state: ${userData?['state']}');
          
          // If document somehow has incorrect default values, fix them immediately
          if (userData?['language'] != 'en' || userData?['state'] != null) {
            debugPrint('⚠️ [DirectAuthService] Detected incorrect default values, fixing now');
            await _firestore.collection('users').doc(userId).update({
              'language': 'en',
              'state': null,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            
            // Verify the fix
            final fixedDoc = await _firestore.collection('users').doc(userId).get();
            final fixedData = fixedDoc.data();
            debugPrint('🔍 [DirectAuthService] Verified fixed values:');
            debugPrint('    - language: ${fixedData?['language']}');
            debugPrint('    - state: ${fixedData?['state']}');
          }
        }
      } catch (verifyError) {
        debugPrint('⚠️ [DirectAuthService] Error verifying document: $verifyError');
      }
      
      // Successfully created Authentication user
      return true;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('DirectAuthService: Firebase Auth Exception: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('DirectAuthService: Unexpected error: $e');
      return false;
    }
  }
  
  /// Create Firestore documents for a new user
  Future<void> createUserDocuments(String userId, String name, String email) async {
    try {
      // Create user document with explicit default values
      final userData = {
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'language': 'en',    // Explicitly set to English 
        'state': null,       // Explicitly set to null
      };
      
      debugPrint('🔄 [DirectAuthService] Creating user document with data:');
      debugPrint('    - User ID: $userId');
      debugPrint('    - Name: $name');
      debugPrint('    - Email: $email');
      debugPrint('    - Language: ${userData['language']}');
      debugPrint('    - State: ${userData['state']}');
      
      await _firestore.collection('users').doc(userId).set(userData);
      debugPrint('✅ [DirectAuthService] Created Firestore user document');
      
      // Create progress document
      await _firestore.collection('progress').doc(userId).set({
        'savedQuestions': [],
        'completeModules': [],
        'topicProgress': {},
        'testScores': {},
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ [DirectAuthService] Created progress document');
    } catch (e) {
      debugPrint('DirectAuthService: Error creating Firestore documents: $e');
      // Continue even if this fails, since the Auth user is already created
    }
  }

  /// Log in a user directly with Firebase
  Future<bool> signIn(String email, String password) async {
    try {
      debugPrint('DirectAuthService: Logging in with email: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        debugPrint('DirectAuthService: Login failed - no user returned');
        return false;
      }
      
      debugPrint('DirectAuthService: Login successful for ID: ${firebaseUser.uid}');
      
      // Update last login time
      try {
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        debugPrint('DirectAuthService: Updated last login time');
      } catch (e) {
        debugPrint('DirectAuthService: Error updating last login: $e');
        // Continue even if this fails
      }
      
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('DirectAuthService: Firebase Auth Exception: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('DirectAuthService: Unexpected error: $e');
      return false;
    }
  }
  
  /// Get the current Firebase user
  User? getFirebaseCurrentUser() {
    return _auth.currentUser;
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  /// Reauthenticate user before sensitive operations
  Future<bool> reauthenticateUser(String password) async {
    try {
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) {
        debugPrint('DirectAuthService: Reauthentication failed: No user is logged in or email is null');
        return false;
      }
      
      // Create credentials
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      
      // Reauthenticate
      await currentUser.reauthenticateWithCredential(credential);
      debugPrint('DirectAuthService: User reauthenticated successfully');
      return true;
    } catch (e) {
      debugPrint('DirectAuthService: Reauthentication failed: $e');
      return false;
    }
  }

  /// Update user email
  Future<void> updateUserEmail(String userId, String email) async {
    try {
      debugPrint('DirectAuthService: Updating email for user: $userId to: $email');
      
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      // Update email in Firebase Auth (use verifyBeforeUpdateEmail for security)
      await currentUser.verifyBeforeUpdateEmail(email);
      debugPrint('DirectAuthService: Firebase Auth email updated successfully');
      
      // Update email in Firestore
      await _firestore.collection('users').doc(userId).update({
        'email': email,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectAuthService: Firestore email updated successfully');
    } catch (e) {
      debugPrint('DirectAuthService: Error updating email: $e');
      throw e;
    }
  }
  
  /// Update user email with reauthentication
  /// 
  /// This method sends a verification email to the new address.
  /// The email in Firebase Auth will only be updated after the user clicks the verification link.
  /// The Firestore database email will be updated automatically by EmailSyncService when:
  /// 1. The app detects the auth state change (if app is running)
  /// 2. Next time the app starts up (if app was closed during verification)
  /// 3. Next time the user logs in (as an additional safety measure)
  Future<void> updateUserEmailSecure(String userId, String email, String password) async {
    try {
      debugPrint('DirectAuthService: Securely updating email for user: $userId to: $email');
      
      // Reauthenticate first
      final reauthSuccess = await reauthenticateUser(password);
      if (!reauthSuccess) {
        throw Exception('Authentication failed. Please check your password and try again.');
      }
      
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      try {
        // Instead of directly updating email, send a verification email first
        await currentUser.verifyBeforeUpdateEmail(email);
        debugPrint('DirectAuthService: Verification email sent to $email. User must verify before email is updated');
        
        // We don't update Firestore here because the email hasn't actually changed yet
        // Firebase will update the email after the user clicks the verification link
        // EmailSyncService will handle synchronizing the email to Firestore after verification
      } catch (e) {
        if (e.toString().contains('requires-recent-login')) {
          throw Exception('Authentication required. Please log out and log back in before changing your email.');
        } else {
          throw Exception('Failed to send verification email: $e');
        }
      }
    } catch (e) {
      debugPrint('DirectAuthService: Error updating email: $e');
      throw e;
    }
  }

  /// Update user profile 
  @override
  Future<app_models.User> updateProfile(String userId, {String? name, String? language, String? state}) async {
    try {
      debugPrint('DirectAuthService: Updating profile for user: $userId');
      
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      // Update fields in Firebase Auth
      if (name != null) {
        await currentUser.updateDisplayName(name);
        debugPrint('DirectAuthService: Firebase Auth display name updated successfully');
      }
      
      // Build update data for Firestore
      Map<String, dynamic> updateData = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (name != null) updateData['name'] = name;
      if (language != null) updateData['language'] = language;
      if (state != null) updateData['state'] = state;
      
      // Update in Firestore
      await _firestore.collection('users').doc(userId).update(updateData);
      
      debugPrint('DirectAuthService: Firestore profile updated successfully');
      
      // Return the updated user
      return getCurrentUser().then((user) => user!);
    } catch (e) {
      debugPrint('DirectAuthService: Error updating profile: $e');
      throw e;
    }
  }
  
  /// Update user language
  @override
  Future<app_models.User> updateUserLanguage(String userId, String language) async {
    try {
      debugPrint('DirectAuthService: Updating language for user: $userId to: $language');
      
      // Update language in Firestore
      await _firestore.collection('users').doc(userId).update({
        'language': language,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectAuthService: Language updated successfully');
      
      // Return the updated user
      return getCurrentUser().then((user) => user!);
    } catch (e) {
      debugPrint('DirectAuthService: Error updating language: $e');
      throw e;
    }
  }
  
  /// Update user state
  @override
  Future<app_models.User> updateUserState(String userId, String? state) async {
    try {
      debugPrint('DirectAuthService: Updating state for user: $userId to: $state');
      
      // Update state in Firestore
      await _firestore.collection('users').doc(userId).update({
        'state': state,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectAuthService: State updated successfully');
      
      // Return the updated user
      return getCurrentUser().then((user) => user!);
    } catch (e) {
      debugPrint('DirectAuthService: Error updating state: $e');
      throw e;
    }
  }
  
  /// Delete user account
  Future<void> deleteAccount(String userId) async {
    try {
      debugPrint('DirectAuthService: Deleting account for user: $userId');
      
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      // Delete user data from Firestore collections
      try {
        // Delete user document
        await _firestore.collection('users').doc(userId).delete();
        
        // Delete user progress
        await _firestore.collection('progress').doc(userId).delete();
        
        // You can add more collections to delete from if needed
        
        debugPrint('DirectAuthService: User data deleted from Firestore');
      } catch (e) {
        debugPrint('DirectAuthService: Error deleting Firestore data: $e');
        // Continue with account deletion even if Firestore delete fails
      }
      
      // Delete the Firebase Auth user
      await currentUser.delete();
      debugPrint('DirectAuthService: Firebase Auth user deleted successfully');
    } catch (e) {
      debugPrint('DirectAuthService: Error deleting account: $e');
      throw e;
    }
  }
  
  /// Get application user from Firebase user
  Future<app_models.User?> getCurrentUser() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        return null;
      }
      
      final userId = firebaseUser.uid;
      
      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return null;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Create app user model
      return app_models.User(
        id: userId,
        name: userData['name'] ?? firebaseUser.displayName ?? '',
        email: userData['email'] ?? firebaseUser.email ?? '',
        language: userData['language'],
        state: userData['state'],
      );
    } catch (e) {
      debugPrint('DirectAuthService: Error getting current user: $e');
      return null;
    }
  }
  
  /// Register a new user
  Future<app_models.User> register(String name, String email, String password) async {
    final success = await signUp(name, email, password);
    if (!success) {
      throw Exception('Failed to create user');
    }
    
    // Get the user details
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw Exception('User creation succeeded but no current user found');
    }
    
    // Return the app user model
    return app_models.User(
      id: firebaseUser.uid,
      name: name,
      email: email,
      language: 'en', // Default language
      state: null,    // Default state is null
    );
  }
  
  /// Login and return user
  Future<app_models.User> login(String email, String password) async {
    final success = await signIn(email, password);
    if (!success) {
      throw Exception('Login failed');
    }
    
    // Get the current user
    final appUser = await getCurrentUser();
    if (appUser == null) {
      throw Exception('Login succeeded but failed to get user details');
    }
    
    return appUser;
  }
  
  /// Logout user
  Future<void> logout() async {
    await signOut();
  }
  
  /// Checks if the user is currently authenticated
  @override
  Future<bool> isAuthenticated() async {
    return _auth.currentUser != null;
  }
  
  /// Creates or updates a user document in Firestore
  @override
  Future<void> createOrUpdateUserDoc(String userId, {
    required String name,
    required String email,
    String language = "en",
    String? state = null,
  }) async {
    try {
      // Create or update the user document
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'language': language,
        'state': state,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('DirectAuthService: User document created or updated successfully');
    } catch (e) {
      debugPrint('DirectAuthService: Error creating/updating user document: $e');
      throw e;
    }
  }
  
  /// Request password reset
  @override
  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('DirectAuthService: Password reset email sent to $email');
    } catch (e) {
      // For security reasons, we don't reveal if the email exists or not
      debugPrint('DirectAuthService: Password reset request handled');
    }
  }
  
  /// Verify password reset code
  @override
  Future<String> verifyPasswordResetCode(String code) async {
    try {
      return await _auth.verifyPasswordResetCode(code);
    } catch (e) {
      debugPrint('DirectAuthService: Error verifying reset code: $e');
      throw 'Invalid or expired reset link. Please request a new one.';
    }
  }

  /// Confirm password reset with new password
  @override
  Future<void> confirmPasswordReset(String code, String newPassword) async {
    try {
      await _auth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      debugPrint('DirectAuthService: Password reset successfully');
    } catch (e) {
      debugPrint('DirectAuthService: Error confirming password reset: $e');
      throw 'Failed to reset password. Please try again.';
    }
  }
}

// Global instance for easy access
final directAuthService = DirectAuthService();
