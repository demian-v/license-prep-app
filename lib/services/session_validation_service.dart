import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import 'session_manager.dart';

/// Service for lightweight session validation using local state (NO database calls)
class SessionValidationService {
  static final SessionValidationService _instance = SessionValidationService._internal();
  factory SessionValidationService() => _instance;
  SessionValidationService._internal();

  /// Fast local session check (NO DATABASE CALL - uses local state only)
  static bool isSessionValidLocally() {
    return sessionManager.isCurrentSessionValid;
  }

  /// Validate session before user action with immediate logout (LOCAL CHECK ONLY)
  static bool validateBeforeAction(BuildContext context) {
    debugPrint('🔍 SessionValidationService: Checking local session state');
    
    if (!isSessionValidLocally()) {
      debugPrint('🚨 SessionValidationService: Local session invalid - triggering immediate logout');
      
      try {
        // Get auth provider and trigger global session conflict handler
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        handleGlobalSessionConflict(authProvider);
      } catch (e) {
        debugPrint('❌ SessionValidationService: Error triggering logout: $e');
      }
      
      return false;
    }
    
    debugPrint('✅ SessionValidationService: Local session valid');
    return true;
  }

  /// Safe validation with error handling
  static bool validateBeforeActionSafely(BuildContext context) {
    try {
      return validateBeforeAction(context);
    } catch (e) {
      debugPrint('❌ SessionValidationService: Error during validation: $e');
      // On error, assume session is invalid for security
      return false;
    }
  }

  /// Debug method to check current session state
  static void debugSessionState() {
    debugPrint('🐛 SessionValidationService Debug:');
    debugPrint('   Local session valid: ${isSessionValidLocally()}');
  }
}
