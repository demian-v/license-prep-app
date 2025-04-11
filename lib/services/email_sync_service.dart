import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_models;
import 'package:provider/provider.dart';

class EmailSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  
  // Sync emails if there's a mismatch - with improved debugging and forced updates
  // While preserving user state information
  Future<void> syncEmailWithFirestore() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      debugPrint('⚠️ EmailSyncService: No authenticated user or email is null');
      return;
    }
    
    final userId = user.uid;
    final authEmail = user.email!;
    
    debugPrint('🔍 EmailSyncService: Starting email sync for user $userId - Auth email: $authEmail');
    
    try {
      // Get current email from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ EmailSyncService: User document not found in Firestore');
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final firestoreEmail = userData['email'] as String?;
      final state = userData['state']; // Store state information
      final language = userData['language']; // Store language preference
      final name = userData['name']; // Store user name
      
      debugPrint('📧 EmailSyncService: Firestore email: $firestoreEmail, Auth email: $authEmail');
      debugPrint('🌍 EmailSyncService: User state: $state, language: $language');
      
      // Check if emails are different before updating
      if (firestoreEmail != authEmail) {
        debugPrint('🔄 EmailSyncService: Updating Firestore email to match Auth email: $authEmail');
        
        // Update Firestore with the email from Firebase Auth while preserving other fields
        await _firestore.collection('users').doc(userId).update({
          'email': authEmail,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        // Verify the update
        final updatedDoc = await _firestore.collection('users').doc(userId).get();
        final updatedEmail = updatedDoc.data()?['email'] as String?;
        final updatedState = updatedDoc.data()?['state']; // Check if state is preserved
        
        if (updatedEmail == authEmail) {
          debugPrint('✅ EmailSyncService: Firestore email synchronized successfully to: $updatedEmail');
          debugPrint('✅ EmailSyncService: User state preserved: $updatedState');
        } else {
          debugPrint('❌ EmailSyncService: Firestore email sync failed! Still showing: $updatedEmail');
          
          // Try fallback method that explicitly preserves all important fields
          try {
            debugPrint('🔄 EmailSyncService: Trying fallback with explicit state preservation');
            await _firestore.collection('users').doc(userId).set({
              'email': authEmail,
              'state': state,
              'language': language,
              'name': name,
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            
            // Verify the state was preserved
            final fallbackDoc = await _firestore.collection('users').doc(userId).get();
            final fallbackState = fallbackDoc.data()?['state'];
            debugPrint('✅ EmailSyncService: After fallback, state = $fallbackState');
          } catch (fallbackError) {
            debugPrint('❌ EmailSyncService: Fallback with state preservation failed: $fallbackError');
          }
        }
      } else {
        debugPrint('✓ EmailSyncService: Emails already in sync: $authEmail');
      }
    } catch (e) {
      debugPrint('❌ EmailSyncService: Error synchronizing email: $e');
      
      // Even with the updated rules, errors can occasionally happen
      // Let's try a fallback approach with merge option
      try {
        debugPrint('🔄 EmailSyncService: Trying alternative update method with merge...');
        
        // First get current state before trying merge
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final state = userData['state']; // Get state
          final language = userData['language']; // Get language
          final name = userData['name']; // Get name
          
          await _firestore.collection('users').doc(userId).set({
            'email': authEmail,
            'state': state,
            'language': language,
            'name': name,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ EmailSyncService: Alternative update method completed with preserved data');
        } else {
          // Simple fallback if we can't get the user document
          await _firestore.collection('users').doc(userId).set({
            'email': authEmail,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ EmailSyncService: Alternative update method completed (basic)');
        }
      } catch (e2) {
        debugPrint('❌ EmailSyncService: All update methods failed: $e2');
      }
    }
  }
  
  // Update the auth provider's user object with the current auth email
  Future<void> updateAuthProviderEmail(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return;
      
      final authEmail = user.email!;
      
      // Get the auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentAppUser = authProvider.user;
      
      if (currentAppUser != null && currentAppUser.email != authEmail) {
        debugPrint('📱 EmailSyncService: Updating AuthProvider user email from ${currentAppUser.email} to $authEmail');
        
        // Create a new user with the updated email
        final updatedUser = app_models.User(
          id: currentAppUser.id,
          name: currentAppUser.name,
          email: authEmail, // Use the auth email
          language: currentAppUser.language,
          state: currentAppUser.state,
        );
        
        // Update the user in the provider
        authProvider.user = updatedUser;
        
        // Notify listeners
        authProvider.notifyListeners();
        
        debugPrint('✅ EmailSyncService: AuthProvider email updated successfully');
      }
    } catch (e) {
      debugPrint('❌ EmailSyncService: Error updating AuthProvider email: $e');
    }
  }
  
  // Update Firestore with the current auth email while preserving other user information
  Future<void> updateFirestoreEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        debugPrint('⚠️ EmailSyncService: No authenticated user or email is null for update');
        return;
      }
      
      final userId = user.uid;
      final authEmail = user.email!;
      
      debugPrint('🔄 EmailSyncService: Updating Firestore email to: $authEmail');
      
      // Get current user document to preserve other fields
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ EmailSyncService: User document not found for preserving state data');
        return;
      }
      
      // Preserve existing data like state, language, name, etc.
      final userData = userDoc.data() as Map<String, dynamic>;
      final state = userData['state']; // Preserve state information
      final language = userData['language']; // Preserve language preference
      final name = userData['name']; // Preserve user name
      
      debugPrint('🔄 EmailSyncService: Preserving user state: $state, language: $language');
      
      // Now update the document with the new email while preserving other fields
      await _firestore.collection('users').doc(userId).update({
        'email': authEmail,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Verify the update
      final updatedDoc = await _firestore.collection('users').doc(userId).get();
      final updatedEmail = updatedDoc.data()?['email'] as String?;
      final updatedState = updatedDoc.data()?['state']; // Check state was preserved
      
      if (updatedEmail == authEmail) {
        debugPrint('✅ EmailSyncService: VERIFIED - Firestore email now matches Auth: $updatedEmail');
        debugPrint('✅ EmailSyncService: User state preserved: $updatedState');
      } else {
        debugPrint('❌ EmailSyncService: FAILED - Firestore email ($updatedEmail) still doesn\'t match Auth email ($authEmail)');
        
        // Use alternative method if the first approach failed - preserve all fields with merge
        await _firestore.collection('users').doc(userId).set({
          'email': authEmail,
          'state': state,
          'language': language,
          'name': name,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        debugPrint('✅ EmailSyncService: Alternative update method completed with preserved state');
      }
    } catch (e) {
      debugPrint('❌ EmailSyncService: Error updating Firestore email: $e');
    }
  }
  
  // Special method for handling email verification return flow
  // Call this when the user returns to the app after verifying email
  Future<bool> handlePostEmailVerification(BuildContext? context) async {
    debugPrint('🔄 EmailSyncService: Handling post-email verification flow');
    bool emailChanged = false;
    
    try {
      // First reload the user to ensure we have the most current email
      final user = _auth.currentUser;
      if (user != null) {
        // Get the current email before reloading
        final oldEmail = user.email;
        
        try {
          // Force reload user data from Firebase
          await user.reload();
          
          final newEmail = user.email;
          if (newEmail != null && oldEmail != newEmail) {
            debugPrint('📧 EmailSyncService: Email has changed from $oldEmail to $newEmail');
            emailChanged = true;
            
            // Update Firestore with the reloaded email
            await updateFirestoreEmail();
            
            // Update local state
            await _refreshLocalUserData();
            
            // Store state and language data in shared preferences for restoration after login
            final prefs = await SharedPreferences.getInstance();
            final userId = user.uid; // Get userId from user object
            final userDoc = await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              final state = userData['state']; 
              final language = userData['language'];
              
              if (state != null) {
                await prefs.setString('last_user_state', state.toString());
                // Verify it was saved
                final savedState = prefs.getString('last_user_state');
                debugPrint('✅ EmailSyncService: Saved state "$state" to preferences, verified: $savedState');
                
                if (savedState != state.toString()) {
                  debugPrint('⚠️ EmailSyncService: State may not have been saved correctly! Expected: $state, Actual: $savedState');
                  // Try one more time with explicit toString
                  await prefs.setString('last_user_state', '$state');
                  final retryState = prefs.getString('last_user_state');
                  debugPrint('✅ EmailSyncService: Retry saving state: $retryState');
                }
              } else {
                debugPrint('⚠️ EmailSyncService: User state is null, nothing to save for restoration');
              }
              
              if (language != null) {
                await prefs.setString('last_user_language', language.toString());
                // Verify it was saved
                final savedLanguage = prefs.getString('last_user_language');
                debugPrint('✅ EmailSyncService: Saved language "$language" to preferences, verified: $savedLanguage');
                
                if (savedLanguage != language.toString()) {
                  debugPrint('⚠️ EmailSyncService: Language may not have been saved correctly! Expected: $language, Actual: $savedLanguage');
                  // Try one more time with explicit toString
                  await prefs.setString('last_user_language', '$language');
                  final retryLanguage = prefs.getString('last_user_language');
                  debugPrint('✅ EmailSyncService: Retry saving language: $retryLanguage');
                }
              } else {
                debugPrint('⚠️ EmailSyncService: User language is null, nothing to save for restoration');
              }
              
              // Log the complete set of saved preferences for debugging
              debugPrint('📋 EmailSyncService: Saved preferences summary:');
              debugPrint('   - State: ${prefs.getString('last_user_state')}');
              debugPrint('   - Language: ${prefs.getString('last_user_language')}');
            } else {
              debugPrint('⚠️ EmailSyncService: User document does not exist in Firestore, cannot save state/language');
            }
            
            // If we have a context, show a dialog informing the user they need to login with new email
            if (context != null && context.mounted) {
              _showEmailChangedDialog(context, newEmail);
              
              // Log out the user so they can log back in with the new email
              await _auth.signOut();
              debugPrint('✅ EmailSyncService: User logged out after email change');
              return true;
            } else {
              // If no context available, just log the user out silently
              debugPrint('⚠️ EmailSyncService: No context available for dialog, logging out silently');
              await _auth.signOut();
              return true;
            }
          } else if (newEmail != null) {
            debugPrint('📧 EmailSyncService: Email unchanged after verification: $newEmail');
            
            // Update Firestore with the current email to ensure sync
            await updateFirestoreEmail();
          }
        } catch (e) {
          if (e.toString().toLowerCase().contains('user-token-expired') || 
              e.toString().toLowerCase().contains('requires-recent-login')) {
            debugPrint('📧 EmailSyncService: User token expired, email verification likely completed');
            emailChanged = true;
            
            // If we have a context, show a dialog informing the user they need to login again
            if (context != null && context.mounted) {
              _showSessionExpiredDialog(context);
              
              // Log out the user so they can log back in with the new email
              await _auth.signOut();
              return true;
            } else {
              // If no context available, just log the user out silently
              debugPrint('⚠️ EmailSyncService: No context available for dialog, logging out silently');
              await _auth.signOut();
              return true;
            }
          } else {
            debugPrint('⚠️ EmailSyncService: Reload error: $e');
            // Don't rethrow - we should try to finish the operation
          }
        }
      } else {
        debugPrint('⚠️ EmailSyncService: No authenticated user found');
      }
    } catch (e) {
      debugPrint('❌ EmailSyncService: Error handling post-verification: $e');
    }
    
    return emailChanged;
  }
  
  // Show a dialog informing the user about the email change and next steps
  void _showEmailChangedDialog(BuildContext context, String newEmail) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Email Verified Successfully'),
        content: Text(
          'Your email has been changed to $newEmail. You will need to log in again with your new email address.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Show a dialog informing the user about session expiration
  void _showSessionExpiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Session Expired'),
        content: Text(
          'Your session has expired, likely due to email verification. Please log in again with your new email address.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Helper method to refresh local user data
  Future<void> _refreshLocalUserData() async {
    try {
      // Force reload the Firebase Auth user
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
      }
    } catch (e) {
      debugPrint('❌ EmailSyncService: Error refreshing local user data: $e');
    }
  }
}

// Global instance for easy access
final emailSyncService = EmailSyncService();
