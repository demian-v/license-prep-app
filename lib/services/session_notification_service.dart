import 'package:flutter/material.dart';
import '../main.dart';
import '../localization/app_localizations.dart';
import '../theme/solar_icons.dart';

/// Service for handling session-related user notifications
class SessionNotificationService {
  static final SessionNotificationService _instance = SessionNotificationService._internal();
  factory SessionNotificationService() => _instance;
  SessionNotificationService._internal();

  /// Show session conflict notification to user
  static void showSessionConflictNotification(BuildContext? context) {
    debugPrint('📢 SessionNotificationService: Showing session conflict notification');
    
    if (context == null) {
      // Use global navigator key if no context available
      final navigatorContext = navigatorKey.currentContext;
      if (navigatorContext != null) {
        _showNotification(navigatorContext);
      } else {
        debugPrint('⚠️ SessionNotificationService: No context available for notification');
      }
    } else {
      _showNotification(context);
    }
  }

  /// Show the actual notification with localized message
  static void _showNotification(BuildContext context) {
    try {
      final localizations = AppLocalizations.of(context);
      
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                SolarIcons.infoCircleLinear,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.translate('sessionConflictMessage'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[700],
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: localizations.translate('sessionConflictButton'),
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      
      debugPrint('✅ SessionNotificationService: Notification displayed successfully');
      
    } catch (e) {
      debugPrint('❌ SessionNotificationService: Error showing notification: $e');
    }
  }

  /// Show a test notification (for debugging)
  static void showTestNotification(BuildContext context) {
    debugPrint('🧪 SessionNotificationService: Showing test notification');
    _showNotification(context);
  }
}
