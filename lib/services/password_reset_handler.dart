import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PasswordResetResult {
  success,
  failed,
  expired,
  invalid,
  wrongActionType
}

class PasswordResetHandler {
  /// Verifies a password reset code and returns the associated email address
  /// Throws an exception if the code is invalid, expired, or not a password reset code
  static Future<String> verifyResetCode(String oobCode) async {
    try {
      debugPrint('🔑 PasswordResetHandler: Verifying password reset code: ${oobCode.substring(0, 8)}...');
      
      // First, check if this is actually a password reset code
      final actionCodeInfo = await FirebaseAuth.instance.checkActionCode(oobCode);
      
      debugPrint('🔑 PasswordResetHandler: Action code operation: ${actionCodeInfo.operation}');
      
      // Ensure this is a password reset code
      if (actionCodeInfo.operation != ActionCodeInfoOperation.passwordReset) {
        debugPrint('❌ PasswordResetHandler: Wrong action type - expected passwordReset, got: ${actionCodeInfo.operation}');
        throw Exception('Invalid password reset link. This appears to be a different type of verification link (${actionCodeInfo.operation}).');
      }
      
      // Verify the password reset code and get the email
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(oobCode);
      
      debugPrint('✅ PasswordResetHandler: Password reset code verified for email: $email');
      return email;
      
    } catch (e) {
      debugPrint('❌ PasswordResetHandler: Error verifying reset code: $e');
      throw _handlePasswordResetError(e);
    }
  }
  
  /// Completes the password reset process with a new password
  static Future<PasswordResetResult> confirmPasswordReset(String oobCode, String newPassword) async {
    try {
      debugPrint('🔑 PasswordResetHandler: Confirming password reset with new password');
      
      // First verify the code is still valid and is a password reset code
      await verifyResetCode(oobCode);
      
      // Confirm the password reset
      await FirebaseAuth.instance.confirmPasswordReset(
        code: oobCode,
        newPassword: newPassword,
      );
      
      debugPrint('✅ PasswordResetHandler: Password reset confirmed successfully');
      return PasswordResetResult.success;
      
    } catch (e) {
      debugPrint('❌ PasswordResetHandler: Error confirming password reset: $e');
      
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('expired')) {
        return PasswordResetResult.expired;
      } else if (errorString.contains('invalid') || errorString.contains('malformed')) {
        return PasswordResetResult.invalid;
      } else if (errorString.contains('different type') || errorString.contains('wrong action')) {
        return PasswordResetResult.wrongActionType;
      }
      
      return PasswordResetResult.failed;
    }
  }
  
  /// Handles password reset specific errors and provides user-friendly messages
  static Exception _handlePasswordResetError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    debugPrint('🔍 PasswordResetHandler: Processing error: $errorString');
    
    if (errorString.contains('expired')) {
      return Exception('This password reset link has expired. Please request a new one from the forgot password page.');
    } else if (errorString.contains('invalid-action-code') || errorString.contains('invalid') || errorString.contains('malformed')) {
      return Exception('This password reset link is invalid or has already been used. Please request a new one.');
    } else if (errorString.contains('user-disabled')) {
      return Exception('Your account has been disabled. Please contact support.');
    } else if (errorString.contains('user-not-found')) {
      return Exception('No account found with this email address. The account may have been deleted.');
    } else if (errorString.contains('network')) {
      return Exception('Network error. Please check your connection and try again.');
    } else if (errorString.contains('weak-password')) {
      return Exception('The password is too weak. Please choose a stronger password.');
    } else if (errorString.contains('different type') || errorString.contains('wrong action') || errorString.contains('verifyAndChangeEmail')) {
      return Exception('This link is for email verification, not password reset. Please use the correct password reset link from your email.');
    }
    
    return Exception('Failed to verify password reset link. Please try again or request a new one.');
  }
  
  /// Get user-friendly error message for PasswordResetResult
  static String getErrorMessage(PasswordResetResult result) {
    switch (result) {
      case PasswordResetResult.success:
        return 'Password reset successful!';
      case PasswordResetResult.expired:
        return 'This password reset link has expired. Please request a new one.';
      case PasswordResetResult.invalid:
        return 'This password reset link is invalid or has already been used.';
      case PasswordResetResult.wrongActionType:
        return 'This link is not for password reset. Please use the correct password reset link.';
      case PasswordResetResult.failed:
        return 'Password reset failed. Please try again or request a new link.';
    }
  }
  
  /// Validates password strength for password reset
  static List<String> validatePasswordStrength(String password) {
    List<String> errors = [];
    
    if (password.length < 8) {
      errors.add('Password must be at least 8 characters long');
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one number');
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain at least one special character');
    }
    
    return errors;
  }
  
  /// Check if password meets strength requirements
  static bool isPasswordStrong(String password) {
    return validatePasswordStrength(password).isEmpty;
  }
  
  /// Get password strength score (0-100)
  static int getPasswordStrength(String password) {
    int score = 0;
    
    // Length check
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 10;
    
    // Character type checks
    if (password.contains(RegExp(r'[a-z]'))) score += 15;
    if (password.contains(RegExp(r'[A-Z]'))) score += 15;
    if (password.contains(RegExp(r'[0-9]'))) score += 15;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 15;
    
    // Bonus for variety
    if (password.contains(RegExp(r'[a-z]')) && 
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      score += 10;
    }
    
    return score.clamp(0, 100);
  }
  
  /// Get password strength description
  static String getPasswordStrengthDescription(String password) {
    int strength = getPasswordStrength(password);
    
    if (strength < 40) {
      return 'Weak';
    } else if (strength < 70) {
      return 'Fair';
    } else if (strength < 90) {
      return 'Good';
    } else {
      return 'Strong';
    }
  }
}
