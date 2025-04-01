import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  Future<bool> login(String email, String password) async {
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
  
  /// Get the current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Global instance for easy access
final directAuthService = DirectAuthService();
