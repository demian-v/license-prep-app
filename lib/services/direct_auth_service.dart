import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user.dart' as app_models;

/// A service class that directly interacts with Firebase Auth and Firestore
/// without any abstractions or complex mappings
class DirectAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sign up a new user directly with Firebase
  Future<bool> signUp(String name, String email, String password) async {
    // Step 1: Create the Auth user
    try {
      debugPrint('DirectAuthService: Creating auth user for email: $email');
      
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        debugPrint('DirectAuthService: Auth user creation failed - no user returned');
        return false;
      }
      
      final userId = firebaseUser.uid;
      debugPrint('DirectAuthService: Auth user created with ID: $userId');
      
      // Step 2: Update the display name
      try {
        await firebaseUser.updateDisplayName(name);
        debugPrint('DirectAuthService: Updated display name to: $name');
      } catch (e) {
        debugPrint('DirectAuthService: Error updating display name: $e');
        // Continue even if this fails
      }
      
      // Step 3: Create Firestore user documents after a short delay
      // This helps avoid race conditions and timing issues
      Future.delayed(Duration(milliseconds: 500), () {
        createUserDocuments(userId, name, email);
      });
      
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
      // Create user document
      await _firestore.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'language': 'en',
        'state': null,
      });
      debugPrint('DirectAuthService: Created Firestore user document');
      
      // Create progress document
      await _firestore.collection('progress').doc(userId).set({
        'savedQuestions': [],
        'completeModules': [],
        'topicProgress': {},
        'testScores': {},
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('DirectAuthService: Created progress document');
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
  
  /// Update user email
  Future<void> updateUserEmail(String userId, String email) async {
    try {
      debugPrint('DirectAuthService: Updating email for user: $userId to: $email');
      
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      // Update email in Firebase Auth
      await currentUser.updateEmail(email);
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
  
  /// Update user profile 
  Future<void> updateProfile(String userId, {required String name}) async {
    try {
      debugPrint('DirectAuthService: Updating profile for user: $userId');
      
      // Get the current Firebase user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      // Update name in Firebase Auth
      await currentUser.updateDisplayName(name);
      debugPrint('DirectAuthService: Firebase Auth display name updated successfully');
      
      // Update name in Firestore
      await _firestore.collection('users').doc(userId).update({
        'name': name,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectAuthService: Firestore name updated successfully');
    } catch (e) {
      debugPrint('DirectAuthService: Error updating profile: $e');
      throw e;
    }
  }
  
  /// Update user language
  Future<void> updateUserLanguage(String userId, String language) async {
    try {
      debugPrint('DirectAuthService: Updating language for user: $userId to: $language');
      
      // Update language in Firestore
      await _firestore.collection('users').doc(userId).update({
        'language': language,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectAuthService: Language updated successfully');
    } catch (e) {
      debugPrint('DirectAuthService: Error updating language: $e');
      throw e;
    }
  }
  
  /// Update user state
  Future<void> updateUserState(String userId, String state) async {
    try {
      debugPrint('DirectAuthService: Updating state for user: $userId to: $state');
      
      // Update state in Firestore
      await _firestore.collection('users').doc(userId).update({
        'state': state,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectAuthService: State updated successfully');
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
}

// Global instance for easy access
final directAuthService = DirectAuthService();
