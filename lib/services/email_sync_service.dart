import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart' as app_models;
import '../data/state_data.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class EmailSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  
  // Debouncing and tracking properties
  DateTime? _lastSyncTime;
  bool _syncInProgress = false;
  Timer? _periodicTimer;
  String? _lastKnownAuthEmail;
  String? _lastKnownFirestoreEmail;
  DateTime? _lastStatusCheck;
  
  // Sync intervals
  static const Duration _minSyncInterval = Duration(minutes: 2);
  static const Duration _periodicSyncInterval = Duration(minutes: 10);
  
  // Smart sync with debouncing - simplified without verification checks
  Future<void> smartSync({bool force = false}) async {
    // Skip if sync in progress
    if (_syncInProgress && !force) {
      debugPrint('⏭️ EmailSyncService: Skipping sync - sync already in progress');
      return;
    }
    
    // Skip if synced recently (unless forced)
    if (!force && _lastSyncTime != null && 
        DateTime.now().difference(_lastSyncTime!) < _minSyncInterval) {
      debugPrint('⏭️ EmailSyncService: Skipping sync - synced ${DateTime.now().difference(_lastSyncTime!).inSeconds}s ago');
      return;
    }
    
    // Check if sync is actually needed
    if (!force && !_needsSync()) {
      debugPrint('⏭️ EmailSyncService: Skipping sync - emails already in sync');
      return;
    }
    
    _syncInProgress = true;
    _lastSyncTime = DateTime.now();
    
    try {
      debugPrint('🚀 EmailSyncService: Starting simplified smart sync (force: $force)');
      await syncEmailWithFirestore();
      _logSyncStats();
    } finally {
      _syncInProgress = false;
    }
  }
  
  // Quick email status check without Firestore read
  bool _needsSync() {
    final user = _auth.currentUser;
    if (user?.email == null) return false;
    
    final currentAuthEmail = user!.email!;
    
    // If auth email changed, definitely need sync
    if (_lastKnownAuthEmail != currentAuthEmail) {
      debugPrint('📧 EmailSyncService: Auth email changed: $_lastKnownAuthEmail → $currentAuthEmail');
      _lastKnownAuthEmail = currentAuthEmail;
      return true;
    }
    
    // If we haven't checked Firestore recently, need to check
    if (_lastStatusCheck == null || 
        DateTime.now().difference(_lastStatusCheck!) > Duration(minutes: 5)) {
      debugPrint('🔍 EmailSyncService: Status check needed - last check: $_lastStatusCheck');
      return true;
    }
    
    return false;
  }
  
  // Start periodic sync with proper timer management
  void startPeriodicSync() {
    stopPeriodicSync(); // Ensure no duplicate timers
    
    debugPrint('⏰ EmailSyncService: Starting periodic sync timer (every ${_periodicSyncInterval.inMinutes} minutes)');
    _periodicTimer = Timer.periodic(_periodicSyncInterval, (timer) async {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        debugPrint('⏰ EmailSyncService: Running periodic sync check');
        await smartSync();
      } else {
        debugPrint('⏰ EmailSyncService: Skipping periodic sync - no authenticated user');
      }
    });
  }
  
  // Stop periodic sync
  void stopPeriodicSync() {
    if (_periodicTimer != null) {
      debugPrint('🛑 EmailSyncService: Stopping periodic sync timer');
      _periodicTimer!.cancel();
      _periodicTimer = null;
    }
  }
  
  // Log sync statistics for debugging
  void _logSyncStats() {
    debugPrint('📊 EmailSyncService Stats:');
    debugPrint('   Last sync: ${_lastSyncTime?.toString() ?? 'Never'}');
    debugPrint('   Sync in progress: $_syncInProgress');
    debugPrint('   Active periodic timer: ${_periodicTimer?.isActive ?? false}');
    debugPrint('   Last known auth email: $_lastKnownAuthEmail');
    debugPrint('   Last status check: $_lastStatusCheck');
  }
  
  // Dispose method for cleanup
  void dispose() {
    debugPrint('🧹 EmailSyncService: Disposing and cleaning up resources');
    stopPeriodicSync();
    _syncInProgress = false;
    _lastSyncTime = null;
    _lastKnownAuthEmail = null;
    _lastKnownFirestoreEmail = null;
    _lastStatusCheck = null;
  }
  
  // Simplified sync emails between Firebase Auth and Firestore
  Future<void> syncEmailWithFirestore() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      debugPrint('⚠️ EmailSyncService: No authenticated user or email is null');
      return;
    }
    
    final userId = user.uid;
    final authEmail = user.email!;
    
    debugPrint('🔍 EmailSyncService: Starting simplified email sync for user $userId - Auth email: $authEmail');
    
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
      
      // Update status tracking
      _lastStatusCheck = DateTime.now();
      _lastKnownFirestoreEmail = firestoreEmail;
      
      // For new users, we should NOT set any default values
      // The language and state selection will be handled by the proper onboarding flow
      // We will only fix values if they are in obviously incorrect formats
      
      bool needsDefaultValueFix = false;
      Map<String, dynamic> fixedValues = {};
      
      // Only fix format issues, not set defaults
      
      // Handle case where state is "null" as string
      if (state is String && state == "null") {
        debugPrint('⚠️ EmailSyncService: Found "null" as string for state, converting to actual null');
        fixedValues['state'] = null;
        needsDefaultValueFix = true;
      }
      
      // Handle case where state is a full state name instead of ID
      else if (state is String && state.length > 2 && state != "null") {
        debugPrint('⚠️ EmailSyncService: State value is a full name instead of ID: $state');
        try {
          // Try to import StateData
          final stateInfo = StateData.getStateByName(state);
          if (stateInfo != null) {
            debugPrint('🔄 EmailSyncService: Converting state name "$state" to ID: "${stateInfo.id}"');
            fixedValues['state'] = stateInfo.id;
            needsDefaultValueFix = true;
          }
        } catch (e) {
          debugPrint('⚠️ EmailSyncService: Error converting state name to ID: $e');
          // Do NOT set to null - leave as is
        }
      }
      
      // DO NOT add default values for language or state
      // This should be handled by the onboarding flow
      
      // Fix incorrect default values if needed
      if (needsDefaultValueFix) {
        debugPrint('🔄 EmailSyncService: Fixing incorrect default values: $fixedValues');
        
        try {
          await _firestore.collection('users').doc(userId).update(fixedValues);
          debugPrint('✅ EmailSyncService: Fixed incorrect default values');
          
          // Verify the fix
          final verifyDoc = await _firestore.collection('users').doc(userId).get();
          final verifyData = verifyDoc.data() as Map<String, dynamic>;
          debugPrint('🔍 EmailSyncService: Verified fixed values:');
          debugPrint('    - language: ${verifyData['language']}');
          debugPrint('    - state: ${verifyData['state']}');
        } catch (fixError) {
          debugPrint('❌ EmailSyncService: Error fixing default values: $fixError');
        }
      }
      
      // Check if emails are different before updating
      if (firestoreEmail != authEmail) {
        debugPrint('🔄 EmailSyncService: Updating Firestore email to match Auth email: $authEmail');
        
        // Update Firestore with the email from Firebase Auth while preserving other fields
        // Make sure not to replace the name from Firebase as it might be derived from email
        if (name != null && name.isNotEmpty) {
          debugPrint('👤 EmailSyncService: Preserving user name: $name during email sync');
          await _firestore.collection('users').doc(userId).update({
            'email': authEmail,
            'name': name, // Explicitly preserve the name from Firestore
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          await _firestore.collection('users').doc(userId).update({
            'email': authEmail,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
        
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
          
          // Only include fields that actually exist in the document
          Map<String, dynamic> updateData = {
            'email': authEmail,
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          
          if (name != null) updateData['name'] = name;
          if (state != null) updateData['state'] = state;
          if (language != null) updateData['language'] = language;
          
          await _firestore.collection('users').doc(userId).set(updateData, SetOptions(merge: true));
          debugPrint('✅ EmailSyncService: Alternative update method completed with preserved data');
        } else {
          // Simple fallback if we can't get the user document - only update email
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
      // Explicitly include the name to ensure it's preserved
      if (name != null && name.isNotEmpty) {
        debugPrint('👤 EmailSyncService: Preserving user name "$name" during updateFirestoreEmail');
        await _firestore.collection('users').doc(userId).update({
          'email': authEmail,
          'name': name, // Explicitly preserve the name
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('users').doc(userId).update({
          'email': authEmail,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      
      // Verify the update
      final updatedDoc = await _firestore.collection('users').doc(userId).get();
      final updatedEmail = updatedDoc.data()?['email'] as String?;
      final updatedState = updatedDoc.data()?['state']; // Check state was preserved
      
      if (updatedEmail == authEmail) {
        debugPrint('✅ EmailSyncService: VERIFIED - Firestore email now matches Auth: $updatedEmail');
        debugPrint('✅ EmailSyncService: User state preserved: $updatedState');
      } else {
        debugPrint('❌ EmailSyncService: FAILED - Firestore email ($updatedEmail) still doesn\'t match Auth email ($authEmail)');
        
          // Use alternative method if the first approach failed - only include fields that exist
          Map<String, dynamic> updateData = {
            'email': authEmail,
            'lastUpdated': FieldValue.serverTimestamp(),
          };
          
          if (name != null) updateData['name'] = name;
          if (state != null) updateData['state'] = state;
          if (language != null) updateData['language'] = language;
          
          await _firestore.collection('users').doc(userId).set(updateData, SetOptions(merge: true));
        
        debugPrint('✅ EmailSyncService: Alternative update method completed with preserved state');
      }
    } catch (e) {
      debugPrint('❌ EmailSyncService: Error updating Firestore email: $e');
    }
  }
  
  // Get basic email sync status for debugging - simplified
  Map<String, dynamic> getSyncStatus() {
    return {
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'syncInProgress': _syncInProgress,
      'lastKnownAuthEmail': _lastKnownAuthEmail,
      'lastKnownFirestoreEmail': _lastKnownFirestoreEmail,
      'lastStatusCheck': _lastStatusCheck?.toIso8601String(),
      'periodicTimerActive': _periodicTimer?.isActive ?? false,
    };
  }
}

// Global instance for easy access
final emailSyncService = EmailSyncService();
