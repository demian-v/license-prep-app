import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/services/push_service.dart';
import 'package:license_prep_app/widgets/push_banner.dart';

/// Instructors plan v2 §12 (P5): the device side of push — the token doc, the
/// permission moment, logout, and where a tapped push goes.
NotificationSettings _settings(AuthorizationStatus status) => NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );

class _FakePush extends PushService {
  _FakePush({this.status = AuthorizationStatus.notDetermined, this.answer = AuthorizationStatus.authorized});

  AuthorizationStatus status;
  final AuthorizationStatus answer;
  String? uid = 'u1';
  String? token = 'fcm-token-1';
  int prompts = 0;
  bool deviceTokenDeleted = false;
  final saved = <String, Map<String, dynamic>>{};
  final deleted = <String>[];

  @override
  String? get currentUid => uid;
  @override
  Future<NotificationSettings> requestPermission() async {
    prompts++;
    status = answer;
    return _settings(status);
  }

  @override
  Future<NotificationSettings> notificationSettings() async => _settings(status);
  @override
  Future<String?> currentToken() async => token;
  @override
  Future<void> deleteDeviceToken() async => deviceTokenDeleted = true;
  @override
  Future<void> saveTokenDoc(String uid, String docId, Map<String, dynamic> data) async =>
      saved['users/$uid/fcmTokens/$docId'] = data;
  @override
  Future<void> deleteTokenDoc(String uid, String docId) async => deleted.add('users/$uid/fcmTokens/$docId');
}

void main() {
  group('PushRoute.parse', () {
    test('accepts only the three route shapes', () {
      expect(PushRoute.parse('profile'), const PushRoute('profile'));
      expect(PushRoute.parse('chat/c_123-x'), const PushRoute('chat', 'c_123-x'));
      expect(PushRoute.parse('booking/b1'), const PushRoute('booking', 'b1'));
      for (final junk in [null, '', 'Profile', 'chat/', 'chat/a/b', 'chat/../x', 'https://x', 'settings', 42]) {
        expect(PushRoute.parse(junk), isNull, reason: '$junk');
      }
    });
  });

  test('the token doc id is the sha256 of the token, as the plan and the server expect', () {
    expect(PushService.tokenDocId('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  group('permission and token', () {
    test('asks once at the chosen moment and saves token, platform and time', () async {
      final push = _FakePush();
      expect(await push.requestPermissionAndRegister(), isTrue);
      expect(push.prompts, 1);
      final doc = push.saved['users/u1/fcmTokens/${PushService.tokenDocId('fcm-token-1')}']!;
      expect(doc.keys.toSet(), {'token', 'platform', 'updatedAt'}); // the rule's hasOnly
      expect(doc['token'], 'fcm-token-1');
      expect(doc['platform'], anyOf('ios', 'android'));
      expect(doc['updatedAt'], isA<FieldValue>());
    });

    test('a refused prompt saves nothing and does not throw', () async {
      final push = _FakePush(answer: AuthorizationStatus.denied);
      expect(await push.requestPermissionAndRegister(), isFalse);
      expect(push.saved, isEmpty);
    });

    test('sign-in never prompts; it registers only if already allowed', () async {
      final undecided = _FakePush();
      await undecided.registerIfAllowed();
      expect(undecided.prompts, 0);
      expect(undecided.saved, isEmpty);

      final allowed = _FakePush(status: AuthorizationStatus.authorized);
      await allowed.registerIfAllowed();
      expect(allowed.prompts, 0);
      expect(allowed.saved, hasLength(1));
    });

    test('no token yet (iOS before APNs) saves nothing', () async {
      final push = _FakePush(status: AuthorizationStatus.authorized)..token = null;
      await push.registerIfAllowed();
      expect(push.saved, isEmpty);
    });

    test('signed out: nothing is saved', () async {
      final push = _FakePush(status: AuthorizationStatus.authorized)..uid = null;
      await push.registerIfAllowed();
      expect(push.saved, isEmpty);
    });

    test('logout deletes this device\'s doc and its FCM token', () async {
      final push = _FakePush(status: AuthorizationStatus.authorized);
      await push.unregister();
      expect(push.deleted, ['users/u1/fcmTokens/${PushService.tokenDocId('fcm-token-1')}']);
      expect(push.deviceTokenDeleted, isTrue);
    });

    test('logout with no token yet touches nothing (iOS throws on deleteToken then)', () async {
      final push = _FakePush(status: AuthorizationStatus.authorized)..token = null;
      await push.unregister();
      expect(push.deleted, isEmpty);
      expect(push.deviceTokenDeleted, isFalse);
    });
  });

  group('where the code asks and cleans up', () {
    String code(String path) => File(path).readAsStringSync();

    test('the app start never asks for permission', () {
      expect(code('lib/main.dart'), isNot(contains('requestPermission')));
      // Every prompt goes through PushService.requestPermissionAndRegister.
      final raw = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('push_service.dart'))
          .where((f) => f.readAsStringSync().contains('.requestPermission('))
          .map((f) => f.path);
      expect(raw, isEmpty);
    });

    test('the end of the instructor wizard asks', () {
      expect(code('lib/screens/instructor_registration_screen.dart'),
          contains('PushService.instance.requestPermissionAndRegister()'));
    });

    test('logout drops the token before signOut, with a deadline (risk #61)', () {
      final api = code('lib/services/api/firebase_auth_api.dart');
      final unregister = api.indexOf('PushService.instance.unregister().timeout(');
      expect(unregister, greaterThan(0));
      expect(unregister, lessThan(api.indexOf('await FirebaseAuth.instance.signOut();')));
    });
  });

  group('in-app banner', () {
    Future<void> pump(WidgetTester tester, {VoidCallback? onTap, VoidCallback? onDismissed}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: PushBannerCard(
              title: 'Photo published',
              body: 'Students can now see it on your profile.',
              onTap: onTap,
              onDismissed: onDismissed ?? () {},
            ),
          ),
        ));

    testWidgets('shows title then text; a tap opens the route', (tester) async {
      var tapped = 0;
      await pump(tester, onTap: () => tapped++);
      await tester.pumpAndSettle();
      expect(find.text('Photo published'), findsOneWidget);
      expect(find.text('Students can now see it on your profile.'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Photo published')).dy,
          lessThan(tester.getTopLeft(find.text('Students can now see it on your profile.')).dy));
      await tester.tap(find.text('Photo published'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });

    testWidgets('goes away by itself', (tester) async {
      var dismissed = false;
      await pump(tester, onDismissed: () => dismissed = true);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    });
  });
}
