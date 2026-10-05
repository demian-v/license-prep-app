import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Where a tapped push goes (instructors plan v2 §12). The server puts it in
/// `data.route`: `profile`, `chat/<id>` or `booking/<id>`. Anything else is
/// ignored, so a malformed payload can't send the app somewhere odd.
class PushRoute {
  const PushRoute(this.name, [this.id]);

  final String name;
  final String? id;

  static final _withId = RegExp(r'^(chat|booking)/([A-Za-z0-9_-]{1,128})$');

  static PushRoute? parse(Object? route) {
    if (route == 'profile') return const PushRoute('profile');
    final match = route is String ? _withId.firstMatch(route) : null;
    return match == null ? null : PushRoute(match[1]!, match[2]);
  }

  @override
  bool operator ==(Object other) => other is PushRoute && other.name == name && other.id == id;

  @override
  int get hashCode => Object.hash(name, id);
}

/// Push notifications (instructors plan v2 §12, P5).
///
/// Each device's FCM token is a doc in `users/{uid}/fcmTokens/{sha256(token)}`
/// (`{token, platform, updatedAt}`, owner-only in firestore.rules), so the
/// server can reach every device of a user and prune dead ones.
///
/// Permission is asked only at the moment it makes sense — the end of an
/// instructor's registration now, a student's first message in P6 — never at
/// app start. After that, every sign-in registers silently.
class PushService {
  PushService({FirebaseMessaging? messaging, FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _messagingOverride = messaging,
        _firestoreOverride = firestore,
        _authOverride = auth;

  static PushService instance = PushService();

  /// A tapped push waiting for Home to open it. Set before Home exists on a
  /// cold start, so Home reads it when it builds.
  static final ValueNotifier<PushRoute?> pendingRoute = ValueNotifier(null);

  // Resolved on first use, so a test fake that overrides the calls never
  // touches Firebase.
  final FirebaseMessaging? _messagingOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseMessaging get _messaging => _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static String tokenDocId(String token) => sha256.convert(utf8.encode(token)).toString();

  static String get platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Listeners for the app's lifetime: token rotation, sign-in, a push that
  /// arrives while the app is open ([onForeground] shows the in-app banner),
  /// and a tap on a system notification (cold start or from the background).
  Future<void> start({required void Function(String title, String body, PushRoute? route) onForeground}) async {
    _messaging.onTokenRefresh.listen((token) {
      _save(token).catchError((Object e) => debugPrint('PushService: token refresh not saved: $e'));
    });
    _auth.authStateChanges().listen((user) {
      if (user != null) registerIfAllowed();
    });
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      onForeground(n.title ?? '', n.body ?? '', PushRoute.parse(message.data['route']));
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_open);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _open(initial);
  }

  void _open(RemoteMessage message) {
    final route = PushRoute.parse(message.data['route']);
    if (route != null) pendingRoute.value = route;
  }

  /// The system prompt, then this device's token. Returns whether pushes are
  /// allowed. Never throws: a refused or failed prompt must not block the
  /// screen that asked.
  Future<bool> requestPermissionAndRegister() async {
    try {
      final settings = await requestPermission();
      if (!_allowed(settings)) return false;
      await registerIfAllowed();
      return true;
    } catch (e) {
      debugPrint('PushService: permission request failed: $e');
      return false;
    }
  }

  /// Saves this device's token when the user already allowed pushes; never
  /// prompts.
  Future<void> registerIfAllowed() async {
    try {
      if (!_allowed(await notificationSettings())) return;
      final token = await currentToken();
      if (token != null) await _save(token);
    } catch (e) {
      debugPrint('PushService: register skipped: $e');
    }
  }

  /// Before sign-out (and when another device takes the session): this device
  /// stops getting the user's pushes. Deleting the FCM token as well means a
  /// doc that could not be deleted (offline) points at a dead token, which
  /// the server prunes on its next send.
  Future<void> unregister() async {
    final token = await currentToken();
    // No token, nothing registered (and iOS refuses deleteToken without APNs).
    if (token == null) return;
    final uid = currentUid;
    if (uid != null) await deleteTokenDoc(uid, tokenDocId(token));
    await deleteDeviceToken();
  }

  Future<void> _save(String token) async {
    final uid = currentUid;
    if (uid == null) return;
    if (!_allowed(await notificationSettings())) return;
    await saveTokenDoc(uid, tokenDocId(token), {
      'token': token,
      'platform': platform,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  bool _allowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  // ── Platform calls, overridden in tests ──────────────────────────────────

  @protected
  String? get currentUid => _auth.currentUser?.uid;

  @protected
  Future<NotificationSettings> requestPermission() => _messaging.requestPermission();

  @protected
  Future<NotificationSettings> notificationSettings() => _messaging.getNotificationSettings();

  /// Null when there is none yet: on iOS the FCM token needs the APNs token
  /// first, and onTokenRefresh delivers it once it arrives.
  @protected
  Future<String?> currentToken() async {
    if (platform == 'ios' && await _messaging.getAPNSToken() == null) return null;
    return _messaging.getToken();
  }

  @protected
  Future<void> deleteDeviceToken() => _messaging.deleteToken();

  @protected
  Future<void> saveTokenDoc(String uid, String docId, Map<String, dynamic> data) =>
      _firestore.collection('users').doc(uid).collection('fcmTokens').doc(docId).set(data);

  @protected
  Future<void> deleteTokenDoc(String uid, String docId) =>
      _firestore.collection('users').doc(uid).collection('fcmTokens').doc(docId).delete();
}
