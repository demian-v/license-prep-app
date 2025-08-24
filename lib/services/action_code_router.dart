import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ActionCodeType {
  emailVerification,
  passwordReset,
  unknown
}

class ActionCodeRouteInfo {
  final ActionCodeType type;
  final String route;
  final String oobCode;
  final String? error;
  final String? email;

  ActionCodeRouteInfo({
    required this.type,
    required this.route,
    required this.oobCode,
    this.error,
    this.email,
  });
}

class ActionCodeRouter {
  /// Determines the correct route for an action code by checking its type with Firebase
  static Future<ActionCodeRouteInfo> determineRoute(String oobCode) async {
    try {
      debugPrint('🔍 ActionCodeRouter: Checking action code type for: ${oobCode.substring(0, 8)}...');
      
      // Check the action code to determine its type
      final actionCodeInfo = await FirebaseAuth.instance.checkActionCode(oobCode);
      
      debugPrint('📧 ActionCodeRouter: Action code operation: ${actionCodeInfo.operation}');
      debugPrint('📧 ActionCodeRouter: Action code data - email: ${actionCodeInfo.data['email']}');
      
      switch (actionCodeInfo.operation) {
        case ActionCodeInfoOperation.verifyAndChangeEmail:
          debugPrint('✉️ ActionCodeRouter: Routing to email verification');
          return ActionCodeRouteInfo(
            type: ActionCodeType.emailVerification,
            route: '/email-verification',
            oobCode: oobCode,
            email: actionCodeInfo.data['email'],
          );
          
        case ActionCodeInfoOperation.passwordReset:
          debugPrint('🔑 ActionCodeRouter: Routing to password reset');
          return ActionCodeRouteInfo(
            type: ActionCodeType.passwordReset,
            route: '/reset-password',
            oobCode: oobCode,
            email: actionCodeInfo.data['email'],
          );
          
        case ActionCodeInfoOperation.recoverEmail:
          debugPrint('📮 ActionCodeRouter: Email recovery not supported, defaulting to email verification');
          return ActionCodeRouteInfo(
            type: ActionCodeType.emailVerification,
            route: '/email-verification',
            oobCode: oobCode,
            email: actionCodeInfo.data['email'],
            error: 'Email recovery action detected but not specifically supported',
          );
          
        case ActionCodeInfoOperation.verifyEmail:
          debugPrint('📧 ActionCodeRouter: Email verification (signup) detected');
          return ActionCodeRouteInfo(
            type: ActionCodeType.emailVerification,
            route: '/email-verification',
            oobCode: oobCode,
            email: actionCodeInfo.data['email'],
          );
          
        default:
          debugPrint('❓ ActionCodeRouter: Unknown action code type: ${actionCodeInfo.operation}');
          return ActionCodeRouteInfo(
            type: ActionCodeType.unknown,
            route: '/profile', // Default fallback
            oobCode: oobCode,
            error: 'Unsupported action code type: ${actionCodeInfo.operation}',
          );
      }
      
    } catch (e) {
      debugPrint('❌ ActionCodeRouter: Error checking action code: $e');
      
      // For expired or invalid codes, we should still try to route appropriately
      // but include the error information
      String errorType = 'unknown_error';
      if (e.toString().toLowerCase().contains('expired')) {
        errorType = 'expired_code';
      } else if (e.toString().toLowerCase().contains('invalid')) {
        errorType = 'invalid_code';
      } else if (e.toString().toLowerCase().contains('malformed')) {
        errorType = 'malformed_code';
      }
      
      // Default to email verification for backward compatibility, but include error
      return ActionCodeRouteInfo(
        type: ActionCodeType.emailVerification,
        route: '/email-verification',
        oobCode: oobCode,
        error: '$errorType: ${e.toString()}',
      );
    }
  }

  /// Quick check to determine if a URL contains an action code
  static bool containsActionCode(String url) {
    return url.contains('oobCode');
  }

  /// Extract oobCode from URL (delegates to EmailVerificationHandler for consistency)
  static String? extractOobCode(String url) {
    try {
      debugPrint('🔍 ActionCodeRouter: Extracting oobCode from: $url');
      
      // Method 1: Try parsing as a complete URI
      final uri = Uri.tryParse(url);
      if (uri != null && uri.queryParameters.containsKey('oobCode')) {
        final code = uri.queryParameters['oobCode'];
        debugPrint('✅ ActionCodeRouter: Extracted oobCode via URI parsing: ${code?.substring(0, 8)}...');
        return code;
      }
      
      // Method 2: Manual regex extraction for various formats
      final patterns = [
        r'oobCode=([^&\s]+)',           // Standard: oobCode=XXX
        r'oobCode%3D([^&\s]+)',         // URL encoded: oobCode%3D
        r'\?oobCode=([^&\s]+)',         // Query param: ?oobCode=XXX
        r'&oobCode=([^&\s]+)',          // Multiple params: &oobCode=XXX
      ];
      
      for (final pattern in patterns) {
        final regex = RegExp(pattern);
        final match = regex.firstMatch(url);
        if (match != null && match.group(1) != null) {
          final code = match.group(1)!;
          debugPrint('✅ ActionCodeRouter: Extracted oobCode via regex: ${code.substring(0, 8)}...');
          return code;
        }
      }
      
      debugPrint('❌ ActionCodeRouter: No oobCode found in URL');
      return null;
    } catch (e) {
      debugPrint('❌ ActionCodeRouter: Error extracting oobCode: $e');
      return null;
    }
  }

  /// Get user-friendly error message based on action type and error
  static String getErrorMessage(ActionCodeType type, String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('expired')) {
      switch (type) {
        case ActionCodeType.passwordReset:
          return 'This password reset link has expired. Please request a new one from the forgot password page.';
        case ActionCodeType.emailVerification:
          return 'This email verification link has expired. Please request a new one from your profile settings.';
        default:
          return 'This verification link has expired. Please request a new one.';
      }
    } else if (errorLower.contains('invalid') || errorLower.contains('malformed')) {
      switch (type) {
        case ActionCodeType.passwordReset:
          return 'This password reset link is invalid or has already been used.';
        case ActionCodeType.emailVerification:
          return 'This email verification link is invalid or has already been used.';
        default:
          return 'This verification link is invalid or has already been used.';
      }
    } else if (errorLower.contains('user-disabled')) {
      return 'Your account has been disabled. Please contact support.';
    } else if (errorLower.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }
    
    switch (type) {
      case ActionCodeType.passwordReset:
        return 'Failed to process password reset link. Please try again or request a new one.';
      case ActionCodeType.emailVerification:
        return 'Failed to process email verification link. Please try again or request a new one.';
      default:
        return 'Failed to process verification link. Please try again.';
    }
  }
}
