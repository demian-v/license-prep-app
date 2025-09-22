import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../models/user_session.dart';
import '../models/user_subscription.dart';
import '../providers/subscription_provider.dart';
import '../main.dart';
import 'service_locator.dart';
import 'subscription_management_service.dart';

/// SessionManager handles single-device session management
/// Only one device can be logged in at a time per user account
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  static SessionManager get instance => _instance;

  // Core properties
  String? _currentSessionId;
  StreamSubscription<DocumentSnapshot>? _sessionListener;
  Timer? _heartbeatTimer;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  // Local session state tracking (for fast validation without database calls)
  bool _isSessionValid = true;
  String? _lastValidatedSessionId;

  // Callback for when session becomes invalid (another device logs in)
  void Function()? onSessionConflict;

  // NEW: Subscription status checking properties
  DateTime? _lastSubscriptionCheck;
  final SubscriptionManagementService _subscriptionService = SubscriptionManagementService();

  /// Check if current session is valid (LOCAL CHECK ONLY - no database call)
  bool get isCurrentSessionValid => _isSessionValid;

  // Session configuration
  static const Duration _heartbeatInterval = Duration(minutes: 10);
  static const Duration _maxSessionAge = Duration(hours: 24); // Optional max age
  static const String _sessionIdKey = 'current_session_id';
  
  // NEW: Subscription checking configuration
  static const int SUBSCRIPTION_CHECK_INTERVAL_MINUTES = 30;

  /// Generate a new unique session ID
  String _generateSessionId() {
    return _uuid.v4();
  }

  /// Get current session ID from local storage
  Future<String?> get currentSessionId async {
    if (_currentSessionId != null) return _currentSessionId;
    
    final prefs = await SharedPreferences.getInstance();
    _currentSessionId = prefs.getString(_sessionIdKey);
    return _currentSessionId;
  }

  /// Store session ID locally
  Future<void> _storeSessionIdLocally(String sessionId) async {
    _currentSessionId = sessionId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdKey, sessionId);
  }

  /// Clear local session ID
  Future<void> _clearLocalSessionId() async {
    _currentSessionId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdKey);
  }

  /// Get app version for session tracking
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      debugPrint('SessionManager: Error getting app version: $e');
      return '1.0.0+1';
    }
  }

  /// Create a new session for the user
  /// This will invalidate any existing sessions (single device login)
  Future<String> createSession(String userId) async {
    try {
      debugPrint('🔐 SessionManager: Creating new session for user: $userId');
      
      // Generate new session ID
      final sessionId = _generateSessionId();
      final appVersion = await _getAppVersion();
      
      // Create session object with enhanced device fingerprinting
      final session = await UserSession.create(
        sessionId: sessionId,
        appVersion: appVersion,
      );
      
      debugPrint('📱 SessionManager: Created session: ${session.toString()}');
      
      // Store session in Firestore (this will overwrite any existing session)
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc('active')
          .set(session.toJson());
      
      // Store session ID locally
      await _storeSessionIdLocally(sessionId);
      
      debugPrint('✅ SessionManager: Session created and stored successfully');
      return sessionId;
      
    } catch (e) {
      debugPrint('❌ SessionManager: Error creating session: $e');
      throw Exception('Failed to create session: $e');
    }
  }

  /// Start monitoring the active session for conflicts
  Future<void> startSessionMonitoring(String userId) async {
    try {
      debugPrint('👁️ SessionManager: Starting session monitoring for user: $userId');
      
      // Stop any existing monitoring
      stopSessionMonitoring();
      
      final localSessionId = await currentSessionId;
      if (localSessionId == null) {
        debugPrint('⚠️ SessionManager: No local session ID found, cannot monitor');
        return;
      }
      
      // Set up real-time listener on the active session document
      _sessionListener = _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc('active')
          .snapshots()
          .listen(
            (snapshot) => _handleSessionSnapshot(snapshot, localSessionId, userId: userId),
            onError: (error) {
              debugPrint('❌ SessionManager: Session listener error: $error');
              // On error, we might want to trigger a validation check
              _validateSessionAfterDelay(userId, localSessionId);
            },
          );
      
      // Start heartbeat to keep session alive
      _startHeartbeat(userId);
      
      debugPrint('✅ SessionManager: Session monitoring started successfully');
      
    } catch (e) {
      debugPrint('❌ SessionManager: Error starting session monitoring: $e');
    }
  }

  /// Handle session document changes with enhanced conflict detection
  void _handleSessionSnapshot(DocumentSnapshot snapshot, String localSessionId, {String? userId}) async {
    try {
      if (!snapshot.exists) {
        debugPrint('⚠️ SessionManager: Session document deleted - conflict detected');
        _triggerSessionConflict();
        return;
      }
      
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        debugPrint('⚠️ SessionManager: Session document has no data - conflict detected');
        _triggerSessionConflict();
        return;
      }
      
      final session = UserSession.fromJson(data);
      debugPrint('📡 SessionManager: Received session update: ${session.sessionId.substring(0, 8)}...');
      
      // PRIMARY CHECK: Session ID comparison  
      if (session.sessionId != localSessionId) {
        debugPrint('🚨 SessionManager: Session ID conflict detected!');
        debugPrint('   Local Session: ${localSessionId.substring(0, 8)}...');
        debugPrint('   Remote Session: ${session.sessionId.substring(0, 8)}...');
        debugPrint('   Remote Device: ${session.deviceInfo}');
        debugPrint('   Remote Device ID: ${session.deviceId.substring(0, 8)}...');
        _logSessionDetails(session, 'CONFLICT');
        
        // CRITICAL: Update local session state immediately
        _isSessionValid = false;
        _lastValidatedSessionId = null;
        
        _triggerSessionConflict();
        return;
      }
      
      // SECONDARY CHECK: Device ID validation (extra safety)
      try {
        final localDeviceId = await _getLocalDeviceId();
        if (localDeviceId != 'unknown' && session.deviceId != localDeviceId) {
          debugPrint('🚨 SessionManager: Device ID mismatch - possible session hijacking!');
          debugPrint('   Local Device: ${localDeviceId.substring(0, 8)}...');
          debugPrint('   Remote Device: ${session.deviceId.substring(0, 8)}...');
          debugPrint('   Session appears to be from different device despite same session ID');
          _logSessionDetails(session, 'DEVICE_MISMATCH');
          
          // CRITICAL: Update local session state immediately
          _isSessionValid = false;
          _lastValidatedSessionId = null;
          
          _triggerSessionConflict();
          return;
        }
      } catch (deviceError) {
        debugPrint('⚠️ SessionManager: Device ID check failed: $deviceError');
        // Continue without device ID validation if it fails
      }
      
      // Session is valid - update local state
      _isSessionValid = true;
      _lastValidatedSessionId = localSessionId;
      
      debugPrint('✅ SessionManager: Session validated - ID and device match');
      _logSessionDetails(session, 'VALIDATED');
      
      // NEW: Check subscription status if needed (non-blocking)
      if (userId != null) {
        _checkSubscriptionStatusIfNeeded(userId);
      }
      
    } catch (e) {
      debugPrint('❌ SessionManager: Error validating session: $e');
      _triggerSessionConflict(); // Fail-safe: logout on any error
    }
  }

  /// Trigger session conflict (logout) with enhanced logging and analytics
  void _triggerSessionConflict() {
    debugPrint('🚨 SessionManager: Triggering session conflict logout');
    debugPrint('🔗 SessionManager: Callback exists: ${onSessionConflict != null}');
    
    // Update local session state immediately (critical for local validation)
    _isSessionValid = false;
    _lastValidatedSessionId = null;
    debugPrint('📍 SessionManager: Local session state set to invalid');
    
    // Log analytics event (no PII)
    try {
      serviceLocator.analytics.logEvent('session_conflict_detected', {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'platform': Platform.isAndroid ? 'android' : 
                   Platform.isIOS ? 'ios' : 
                   kIsWeb ? 'web' : 'other',
      });
      debugPrint('📊 SessionManager: Analytics event logged');
    } catch (e) {
      debugPrint('⚠️ SessionManager: Analytics error: $e');
    }
    
    // Stop monitoring to prevent further triggers
    stopSessionMonitoring();
    
    // Clear local session
    _clearLocalSessionId();
    
    // CRITICAL: Trigger the callback with detailed logging
    if (onSessionConflict != null) {
      debugPrint('📞 SessionManager: Executing session conflict callback');
      try {
        onSessionConflict!();
        debugPrint('✅ SessionManager: Session conflict callback executed successfully');
      } catch (e) {
        debugPrint('❌ SessionManager: Error executing callback: $e');
      }
    } else {
      debugPrint('❌ SessionManager: NO SESSION CONFLICT CALLBACK SET - This is the bug!');
      debugPrint('⚠️ SessionManager: User will NOT be logged out automatically');
    }
  }

  /// Start heartbeat to update session activity
  void _startHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) async {
      await _updateSessionActivity(userId);
    });
    
    debugPrint('💓 SessionManager: Heartbeat started (${_heartbeatInterval.inMinutes}min intervals)');
  }

  /// Update session activity timestamp
  Future<void> _updateSessionActivity(String userId) async {
    try {
      final localSessionId = await currentSessionId;
      if (localSessionId == null) {
        debugPrint('⚠️ SessionManager: No local session for heartbeat update');
        return;
      }
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc('active')
          .update({
        'lastActivity': FieldValue.serverTimestamp(),
      });
      
      debugPrint('💓 SessionManager: Session activity updated');
      
    } catch (e) {
      debugPrint('⚠️ SessionManager: Error updating session activity: $e');
      // Don't throw here - heartbeat failures shouldn't crash the app
    }
  }

  /// Validate session after a delay (for error recovery)
  void _validateSessionAfterDelay(String userId, String localSessionId) {
    Timer(Duration(seconds: 5), () async {
      final isValid = await isSessionValid(userId);
      if (!isValid) {
        debugPrint('🚨 SessionManager: Delayed validation failed - triggering logout');
        _triggerSessionConflict();
      }
    });
  }

  /// Check if current session is valid
  Future<bool> isSessionValid(String userId) async {
    try {
      final localSessionId = await currentSessionId;
      if (localSessionId == null) {
        debugPrint('⚠️ SessionManager: No local session ID');
        return false;
      }
      
      // Get current session from Firestore
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc('active')
          .get();
      
      if (!doc.exists) {
        debugPrint('⚠️ SessionManager: No active session document found');
        return false;
      }
      
      final session = UserSession.fromJson(doc.data()!);
      
      // Check if session IDs match
      if (session.sessionId != localSessionId) {
        debugPrint('⚠️ SessionManager: Session ID mismatch');
        return false;
      }
      
      debugPrint('✅ SessionManager: Session is valid');
      return true;
      
    } catch (e) {
      debugPrint('❌ SessionManager: Error validating session: $e');
      return false;
    }
  }

  /// Invalidate current session (logout)
  Future<void> invalidateSession(String userId) async {
    try {
      debugPrint('🗑️ SessionManager: Invalidating session for user: $userId');
      
      // Stop monitoring first
      stopSessionMonitoring();
      
      // Delete session from Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc('active')
          .delete();
      
      // Clear local session
      await _clearLocalSessionId();
      
      debugPrint('✅ SessionManager: Session invalidated successfully');
      
    } catch (e) {
      debugPrint('❌ SessionManager: Error invalidating session: $e');
      // Still clear local session even if Firestore delete fails
      await _clearLocalSessionId();
    }
  }

  /// Stop session monitoring
  void stopSessionMonitoring() {
    debugPrint('🛑 SessionManager: Stopping session monitoring');
    
    _sessionListener?.cancel();
    _sessionListener = null;
    
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Get current active session info (for debugging/display)
  Future<UserSession?> getCurrentSession(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc('active')
          .get();
      
      if (!doc.exists) return null;
      
      return UserSession.fromJson(doc.data()!);
      
    } catch (e) {
      debugPrint('❌ SessionManager: Error getting current session: $e');
      return null;
    }
  }

  /// Get local device ID for validation
  Future<String> _getLocalDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('device_id') ?? 'unknown';
    } catch (e) {
      debugPrint('⚠️ SessionManager: Error getting local device ID: $e');
      return 'unknown';
    }
  }

  /// Validate session after network reconnection
  Future<void> validateSessionAfterReconnection(String userId) async {
    try {
      debugPrint('🌐 SessionManager: Validating session after network reconnection');
      
      final isValid = await isSessionValid(userId);
      if (!isValid) {
        debugPrint('🚨 SessionManager: Session invalid after reconnection');
        _triggerSessionConflict();
      } else {
        debugPrint('✅ SessionManager: Session valid after reconnection');
      }
    } catch (e) {
      debugPrint('❌ SessionManager: Error validating after reconnection: $e');
      // Don't trigger logout on network errors
    }
  }

  /// Log detailed session information for debugging
  void _logSessionDetails(UserSession session, String context) {
    debugPrint('📊 SessionManager [$context]:');
    debugPrint('   Session ID: ${session.sessionId.substring(0, 8)}...');
    debugPrint('   Device: ${session.deviceInfo}');
    debugPrint('   Device ID: ${session.deviceId.substring(0, 8)}...');
    debugPrint('   Platform: ${session.platform}');
    debugPrint('   Login Time: ${session.loginTime}');
    debugPrint('   Last Activity: ${session.lastActivity}');
  }

  // NEW: Subscription status checking methods

  /// Extract user ID from session data (since sessions don't store userId directly)
  String? _getUserIdFromSessionData(Map<String, dynamic> data) {
    // For now, we'll need to pass userId separately or get it from the document path
    // This is a simplified approach - in practice we might need to modify session structure
    try {
      // We can get userId from the current document path or pass it through other means
      // For now, return null and we'll pass userId directly in other methods
      return null;
    } catch (e) {
      debugPrint('⚠️ SessionManager: Error extracting userId from session data: $e');
      return null;
    }
  }

  /// Check subscription status if needed (with throttling)
  Future<void> _checkSubscriptionStatusIfNeeded(String userId) async {
    if (!_shouldCheckSubscriptionStatus()) {
      return;
    }
    
    // Run subscription check independently (don't await)
    _performSubscriptionStatusCheck(userId).catchError((error) {
      debugPrint('⚠️ SessionManager: Subscription check failed (non-critical): $error');
    });
  }

  /// Check if subscription status check should be performed (throttling logic)
  bool _shouldCheckSubscriptionStatus() {
    if (_lastSubscriptionCheck == null) return true;
    
    final timeSinceLastCheck = DateTime.now().difference(_lastSubscriptionCheck!);
    return timeSinceLastCheck.inMinutes >= SUBSCRIPTION_CHECK_INTERVAL_MINUTES;
  }

  /// Perform the actual subscription status check
  Future<void> _performSubscriptionStatusCheck(String userId) async {
    debugPrint('🔄 SessionManager: Checking subscription status for user: $userId');
    
    try {
      // Get current subscription
      final subscription = await _subscriptionService.getUserSubscription(userId);
      
      if (subscription == null) {
        debugPrint('ℹ️ SessionManager: No subscription found for user');
        _lastSubscriptionCheck = DateTime.now();
        return;
      }
      
      // Check if subscription is expired but still marked as active
      if (subscription.status == 'active' && _isSubscriptionExpired(subscription)) {
        debugPrint('⚠️ SessionManager: Found expired subscription, updating status...');
        
        // Update subscription status to inactive
        await _subscriptionService.updateSubscriptionStatus(userId, 'inactive');
        
        debugPrint('✅ SessionManager: Subscription status updated to inactive');
        
        // Clear subscription cache to force refresh
        await _clearSubscriptionCache(userId);
        
        // Log the successful status update
        _logSubscriptionCheckResult(subscription, true);
      } else {
        debugPrint('ℹ️ SessionManager: Subscription status is current');
        _logSubscriptionCheckResult(subscription, false);
      }
      
      _lastSubscriptionCheck = DateTime.now();
      
    } catch (e) {
      debugPrint('❌ SessionManager: Subscription status check failed: $e');
      
      // Handle network errors differently (retry sooner)
      if (_isNetworkError(e)) {
        debugPrint('🌐 SessionManager: Network error detected, will retry sooner');
        // Don't update _lastSubscriptionCheck for network errors
      } else {
        // For other errors, update timestamp to avoid spam
        _lastSubscriptionCheck = DateTime.now();
      }
      
      rethrow; // Let the catchError handle it
    }
  }

  /// Check if subscription is expired
  bool _isSubscriptionExpired(UserSubscription subscription) {
    final now = DateTime.now();
    
    // Check trial expiration
    if (subscription.planType == 'trial') {
      if (subscription.trialEndsAt != null) {
        final isExpired = now.isAfter(subscription.trialEndsAt!);
        debugPrint('🔍 SessionManager: Trial expires at ${subscription.trialEndsAt}, expired: $isExpired');
        return isExpired;
      }
    }
    
    // Check paid subscription expiration
    if (subscription.planType != 'trial' && subscription.nextBillingDate != null) {
      final isExpired = now.isAfter(subscription.nextBillingDate!);
      debugPrint('🔍 SessionManager: Subscription expires at ${subscription.nextBillingDate}, expired: $isExpired');
      return isExpired;
    }
    
    return false;
  }

  /// Check if error is network-related
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') || 
           errorString.contains('timeout') || 
           errorString.contains('socket') ||
           errorString.contains('connection');
  }

  /// Clear subscription cache
  Future<void> _clearSubscriptionCache(String userId) async {
    try {
      // Access SubscriptionProvider from global context
      final context = navigatorKey.currentContext;
      if (context != null) {
        final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
        await subscriptionProvider.refreshSubscription(userId);
        debugPrint('✅ SessionManager: Subscription cache cleared');
      } else {
        debugPrint('⚠️ SessionManager: Global context not available for cache clearing');
      }
    } catch (e) {
      debugPrint('⚠️ SessionManager: Failed to clear subscription cache: $e');
    }
  }

  /// Log subscription check results
  void _logSubscriptionCheckResult(UserSubscription? subscription, bool wasUpdated) {
    if (subscription == null) {
      debugPrint('📊 SessionManager: Subscription Check Summary - No subscription found');
      return;
    }
    
    debugPrint('📊 SessionManager: Subscription Check Summary:');
    debugPrint('   - User ID: ${subscription.userId}');
    debugPrint('   - Plan Type: ${subscription.planType}');
    debugPrint('   - Status: ${subscription.status}');
    debugPrint('   - Is Active: ${subscription.isActive}');
    
    if (subscription.planType == 'trial') {
      debugPrint('   - Trial Ends: ${subscription.trialEndsAt}');
      debugPrint('   - Trial Expired: ${_isSubscriptionExpired(subscription)}');
    } else {
      debugPrint('   - Next Billing: ${subscription.nextBillingDate}');
      debugPrint('   - Subscription Expired: ${_isSubscriptionExpired(subscription)}');
    }
    
    debugPrint('   - Status Updated: $wasUpdated');
    debugPrint('   - Check Time: ${DateTime.now()}');
  }

  /// Public method to manually trigger subscription check (for testing)
  Future<void> checkSubscriptionStatusNow(String userId) async {
    debugPrint('🔄 SessionManager: Manual subscription check requested');
    await _performSubscriptionStatusCheck(userId);
  }

  /// Cleanup on app termination
  void dispose() {
    debugPrint('🧹 SessionManager: Disposing resources');
    stopSessionMonitoring();
  }
}

// Global instance for easy access
final sessionManager = SessionManager.instance;
