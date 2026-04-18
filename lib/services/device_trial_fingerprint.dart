import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceTrialFingerprint {
  static const _storageKey = 'trial_device_uuid';

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<({String hash, bool isPhysicalDevice})> compute() async {
    final deviceInfo = DeviceInfoPlugin();

    String platform;
    String hardwareId;
    bool isPhysicalDevice;

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      platform = 'ios';
      hardwareId = iosInfo.identifierForVendor ?? '';
      isPhysicalDevice = iosInfo.isPhysicalDevice;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      platform = 'android';
      hardwareId = androidInfo.id;
      isPhysicalDevice = androidInfo.isPhysicalDevice;
    } else {
      platform = 'unknown';
      hardwareId = '';
      isPhysicalDevice = false;
    }

    String? keychainUuid = await _storage.read(key: _storageKey);
    if (keychainUuid == null || keychainUuid.isEmpty) {
      keychainUuid = const Uuid().v4();
      await _storage.write(key: _storageKey, value: keychainUuid);
      debugPrint('🆔 [DeviceTrialFingerprint] Generated new keychain UUID');
    }

    final raw = '$platform|$hardwareId|$keychainUuid';
    final digest = sha256.convert(utf8.encode(raw));
    return (hash: digest.toString(), isPhysicalDevice: isPhysicalDevice);
  }
}
