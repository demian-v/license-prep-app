import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui' as ui;

class UserSession {
  final String sessionId;
  final String deviceInfo;
  final String deviceId;        // Unique per physical device
  final String deviceModel;     // Device model/name  
  final String screenInfo;      // Screen resolution info
  final DateTime loginTime;
  final DateTime lastActivity;
  final String platform;
  final String appVersion;

  UserSession({
    required this.sessionId,
    required this.deviceInfo,
    required this.deviceId,
    required this.deviceModel,
    required this.screenInfo,
    required this.loginTime,
    required this.lastActivity,
    required this.platform,
    required this.appVersion,
  });

  /// Generate device fingerprint with unique identifiers
  static Future<Map<String, String>> _generateDeviceFingerprint() async {
    try {
      // Get or create persistent device ID
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');
      
      if (deviceId == null) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
        debugPrint('🆔 Generated new device ID: ${deviceId.substring(0, 8)}...');
      }
      
      // Get device-specific info
      String deviceModel = await _getDeviceModel();
      String screenInfo = await _getScreenInfo();
      
      return {
        'deviceId': deviceId,
        'deviceModel': deviceModel,
        'screenInfo': screenInfo,
      };
    } catch (e) {
      debugPrint('⚠️ Error generating device fingerprint: $e');
      // Fallback to basic info
      return {
        'deviceId': const Uuid().v4(),
        'deviceModel': 'Unknown Device',
        'screenInfo': 'Unknown Screen',
      };
    }
  }

  /// Get device model information
  static Future<String> _getDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return '${webInfo.browserName} ${webInfo.platform}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} ${iosInfo.model}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return 'Windows ${windowsInfo.productName}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return '${macInfo.model} macOS';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return 'Linux ${linuxInfo.name}';
      }
    } catch (e) {
      debugPrint('⚠️ Error getting device model: $e');
    }
    
    // Fallback based on platform
    if (kIsWeb) return 'Web Browser';
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iOS Device';
    if (Platform.isWindows) return 'Windows Device';
    if (Platform.isMacOS) return 'macOS Device';
    if (Platform.isLinux) return 'Linux Device';
    return 'Unknown Device';
  }

  /// Get screen resolution information
  static Future<String> _getScreenInfo() async {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final size = view.physicalSize;
      final pixelRatio = view.devicePixelRatio;
      final logicalSize = size / pixelRatio;
      
      return '${logicalSize.width.toInt()}x${logicalSize.height.toInt()}@${pixelRatio.toStringAsFixed(1)}x';
    } catch (e) {
      debugPrint('⚠️ Error getting screen info: $e');
      return 'Unknown Screen';
    }
  }

  /// Create a new session with enhanced device fingerprinting
  static Future<UserSession> create({
    required String sessionId,
    required String appVersion,
  }) async {
    final now = DateTime.now();
    
    // Generate device fingerprint
    final fingerprint = await _generateDeviceFingerprint();
    
    // Determine platform info
    String platform;
    String baseDeviceInfo;
    
    if (kIsWeb) {
      platform = 'web';
      baseDeviceInfo = 'Web Browser';
    } else if (Platform.isAndroid) {
      platform = 'android';
      baseDeviceInfo = 'Android Device';
    } else if (Platform.isIOS) {
      platform = 'ios';
      baseDeviceInfo = 'iOS Device';
    } else if (Platform.isWindows) {
      platform = 'windows';
      baseDeviceInfo = 'Windows Device';
    } else if (Platform.isMacOS) {
      platform = 'macos';
      baseDeviceInfo = 'macOS Device';
    } else if (Platform.isLinux) {
      platform = 'linux';
      baseDeviceInfo = 'Linux Device';
    } else {
      platform = 'unknown';
      baseDeviceInfo = 'Unknown Device';
    }

    // Create enhanced device info string
    final deviceModel = fingerprint['deviceModel']!;
    final screenInfo = fingerprint['screenInfo']!;
    final enhancedDeviceInfo = '$deviceModel ($screenInfo)';

    return UserSession(
      sessionId: sessionId,
      deviceInfo: enhancedDeviceInfo,
      deviceId: fingerprint['deviceId']!,
      deviceModel: deviceModel,
      screenInfo: screenInfo,
      loginTime: now,
      lastActivity: now,
      platform: platform,
      appVersion: appVersion,
    );
  }

  /// Create from Firestore document
  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionId: json['sessionId'] ?? '',
      deviceInfo: json['deviceInfo'] ?? 'Unknown Device',
      deviceId: json['deviceId'] ?? '',
      deviceModel: json['deviceModel'] ?? 'Unknown Device',
      screenInfo: json['screenInfo'] ?? 'Unknown Screen',
      loginTime: (json['loginTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActivity: (json['lastActivity'] as Timestamp?)?.toDate() ?? DateTime.now(),
      platform: json['platform'] ?? 'unknown',
      appVersion: json['appVersion'] ?? '1.0.0',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'deviceInfo': deviceInfo,
      'deviceId': deviceId,
      'deviceModel': deviceModel,
      'screenInfo': screenInfo,
      'loginTime': Timestamp.fromDate(loginTime),
      'lastActivity': Timestamp.fromDate(lastActivity),
      'platform': platform,
      'appVersion': appVersion,
    };
  }

  /// Create a copy with updated last activity
  UserSession copyWithActivity() {
    return UserSession(
      sessionId: sessionId,
      deviceInfo: deviceInfo,
      deviceId: deviceId,
      deviceModel: deviceModel,
      screenInfo: screenInfo,
      loginTime: loginTime,
      lastActivity: DateTime.now(),
      platform: platform,
      appVersion: appVersion,
    );
  }

  /// Check if session is still valid (not older than specified duration)
  bool isValidForDuration(Duration maxAge) {
    final now = DateTime.now();
    return now.difference(loginTime) <= maxAge;
  }

  /// Get human-readable device description
  String get displayName {
    final duration = DateTime.now().difference(loginTime);
    final daysAgo = duration.inDays;
    final hoursAgo = duration.inHours;
    final minutesAgo = duration.inMinutes;
    
    String timeAgo;
    if (daysAgo > 0) {
      timeAgo = '${daysAgo}d ago';
    } else if (hoursAgo > 0) {
      timeAgo = '${hoursAgo}h ago';
    } else if (minutesAgo > 0) {
      timeAgo = '${minutesAgo}m ago';
    } else {
      timeAgo = 'Just now';
    }
    
    return '$deviceInfo • $timeAgo';
  }

  @override
  String toString() {
    return 'UserSession(id: ${sessionId.substring(0, 8)}..., device: $deviceInfo, deviceId: ${deviceId.substring(0, 8)}..., platform: $platform, login: $loginTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSession && 
           other.sessionId == sessionId && 
           other.deviceId == deviceId;
  }

  @override
  int get hashCode => Object.hash(sessionId, deviceId);
}
