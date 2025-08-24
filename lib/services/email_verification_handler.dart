import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_sync_service.dart';

enum EmailVerificationResult {
  success,
  successButSignedOut,
  failed
}

class EmailVerificationHandler {
  /// Handles email verification using Firebase Auth action code
  /// Returns EmailVerificationResult indicating the outcome
  static Future<EmailVerificationResult> handleVerificationCode(String oobCode) async {
    try {
      debugPrint('📧 EmailVerificationHandler: Processing verification code: ${oobCode.substring(0, 8)}...');
      
      // Phase 1: Check and apply the verification code (this should always work)
      final actionCodeInfo = await FirebaseAuth.instance.checkActionCode(oobCode);
      debugPrint('📧 EmailVerificationHandler: Action type: ${actionCodeInfo.operation}');
      
      // Validate that this is actually an email verification code
      if (actionCodeInfo.operation != ActionCodeInfoOperation.verifyAndChangeEmail &&
          actionCodeInfo.operation != ActionCodeInfoOperation.verifyEmail) {
        debugPrint('❌ EmailVerificationHandler: Wrong action type - expected email verification, got: ${actionCodeInfo.operation}');
        
        if (actionCodeInfo.operation == ActionCodeInfoOperation.passwordReset) {
          debugPrint('🔑 EmailVerificationHandler: This is a password reset code, not email verification');
          throw Exception('This link is for password reset, not email verification. Please use the correct password reset link from your email.');
        } else {
          debugPrint('❓ EmailVerificationHandler: Unsupported action code type: ${actionCodeInfo.operation}');
          throw Exception('This verification link is not for email verification. Please use the correct email verification link.');
        }
      }
      
      await FirebaseAuth.instance.applyActionCode(oobCode);
      debugPrint('✅ EmailVerificationHandler: Action code applied successfully');
      
      // Phase 2: Check if user is still signed in after applying the action code
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        debugPrint('🚪 EmailVerificationHandler: User was signed out after email verification (Firebase security feature)');
        return EmailVerificationResult.successButSignedOut;
      }
      
      // Phase 3: Try to reload user data and sync (this might fail due to token expiry)
      try {
        await currentUser.reload();
        debugPrint('🔄 EmailVerificationHandler: User data reloaded');
        
        // Get the updated user
        final updatedUser = FirebaseAuth.instance.currentUser;
        debugPrint('📧 EmailVerificationHandler: Updated email: ${updatedUser?.email}');
        
        // Try to sync email data
        await emailSyncService.smartSync(force: true);
        debugPrint('🔄 EmailVerificationHandler: Email sync completed successfully');
        
        return EmailVerificationResult.success;
        
      } catch (syncError) {
        debugPrint('⚠️ EmailVerificationHandler: Sync operation failed: $syncError');
        
        // Check if it's a token expiry error
        if (_isTokenExpiryError(syncError)) {
          debugPrint('🚪 EmailVerificationHandler: Token expired during sync - treating as successful verification with sign-out');
          return EmailVerificationResult.successButSignedOut;
        }
        
        // For other sync errors, still consider verification successful
        // (the email verification itself succeeded, just sync failed)
        debugPrint('✅ EmailVerificationHandler: Email verification succeeded despite sync failure');
        return EmailVerificationResult.success;
      }
      
    } catch (verificationError) {
      debugPrint('❌ EmailVerificationHandler: Email verification failed: $verificationError');
      return EmailVerificationResult.failed;
    }
  }
  
  /// Checks if an error is related to token expiry or authentication issues
  static bool _isTokenExpiryError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('user-token-expired') ||
           errorString.contains('requires-recent-login') ||
           errorString.contains('credential is no longer valid') ||
           errorString.contains('token has expired') ||
           errorString.contains('user must sign in again') ||
           errorString.contains('auth/user-token-expired') ||
           errorString.contains('auth/requires-recent-login') ||
           errorString.contains('permission-denied') ||
           errorString.contains('unauthenticated');
  }
  
  /// Gets user-friendly error message for verification errors
  static String getErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('expired') || errorLower.contains('expire')) {
      return 'This verification link has expired. Please request a new one from your profile settings.';
    } else if (errorLower.contains('invalid') || errorLower.contains('malformed')) {
      return 'This verification link is invalid or has already been used.';
    } else if (errorLower.contains('user-disabled')) {
      return 'Your account has been disabled. Please contact support.';
    } else if (errorLower.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }
    
    return 'Failed to verify email. Please try again or request a new verification email.';
  }
  
  /// Extracts oobCode from various URL formats
  static String? extractOobCode(String url) {
    try {
      debugPrint('🔍 EmailVerificationHandler: Extracting oobCode from: $url');
      
      // Method 1: Try parsing as a complete URI
      final uri = Uri.tryParse(url);
      if (uri != null && uri.queryParameters.containsKey('oobCode')) {
        final code = uri.queryParameters['oobCode'];
        debugPrint('✅ EmailVerificationHandler: Extracted oobCode via URI parsing: ${code?.substring(0, 8)}...');
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
          debugPrint('✅ EmailVerificationHandler: Extracted oobCode via regex: ${code.substring(0, 8)}...');
          return code;
        }
      }
      
      debugPrint('❌ EmailVerificationHandler: No oobCode found in URL');
      return null;
    } catch (e) {
      debugPrint('❌ EmailVerificationHandler: Error extracting oobCode: $e');
      return null;
    }
  }
}
