import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/config/meta_config.dart';
import 'package:license_prep_app/services/analytics_service.dart';
import 'package:license_prep_app/services/meta_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Analytics plan E (owner's decisions, 2026-10-30): nothing reaches Meta
/// before a yes, a no sends nothing and blocks nothing, and the events go out
/// from AnalyticsService next to the GA4 ones. The SDK is replaced by
/// [MetaEvents.debugSink]; the native settings are asserted on the files.
void main() {
  final meta = MetaEvents.instance;
  final analytics = AnalyticsService();
  final sent = <(String, Map<String, dynamic>)>[];
  String src(String path) => File(path).readAsStringSync();

  setUp(() {
    sent.clear();
    SharedPreferences.setMockInitialValues({});
    meta.debugReset();
    MetaEvents.debugConfigured = true;
    MetaEvents.debugSink = (kind, params) => sent.add((kind, params));
    MetaEvents.debugAsk = null;
    analytics.reset();
  });
  tearDown(() {
    MetaEvents.debugConfigured = null;
    MetaEvents.debugSink = null;
    MetaEvents.debugAsk = null;
  });

  List<String> kinds() => [for (final e in sent) e.$1];

  group('before an answer', () {
    test('nothing is sent: sign-up and the trial wait on the device', () async {
      await analytics.logSignUp('email');
      await analytics.logSignupTrialStarted();
      expect(sent, isEmpty);
      expect((await SharedPreferences.getInstance()).getStringList(MetaEvents.pendingKey), hasLength(2));
    });

    test('a yes sends what waited, in order, and later events go straight out', () async {
      await analytics.logSignUp('email');
      await analytics.logSignupTrialStarted();
      await meta.answer(true);
      expect(kinds(), ['registration', 'start_trial']);
      expect((await SharedPreferences.getInstance()).getStringList(MetaEvents.pendingKey), isNull);
      await analytics.logPurchase(productId: 'monthly_sub', value: 9.99, currency: 'USD');
      expect(kinds().last, 'purchase');
    });

    test('a no deletes what waited and nothing is ever sent', () async {
      await analytics.logSignUp('email');
      await analytics.logSignupTrialStarted();
      await meta.answer(false);
      await analytics.logPurchase(productId: 'monthly_sub', value: 9.99, currency: 'USD');
      expect(sent, isEmpty);
      expect((await SharedPreferences.getInstance()).getStringList(MetaEvents.pendingKey), isNull);
    });

    test('what waits is capped: an instructor is never asked', () async {
      for (var i = 0; i < MetaEvents.maxPending + 5; i++) {
        await analytics.logSignUp('email');
      }
      expect((await SharedPreferences.getInstance()).getStringList(MetaEvents.pendingKey), hasLength(MetaEvents.maxPending));
    });
  });

  group('the off switch', () {
    test('a yes can be taken back; a no can become a yes', () async {
      await meta.answer(true);
      await analytics.logSignUp('email');
      await meta.answer(false);
      await analytics.logSignupTrialStarted();
      expect(kinds(), ['registration']);
      await meta.answer(true);
      await analytics.logSignupTrialStarted();
      expect(kinds(), ['registration', 'start_trial']);
    });

    test('the answer outlasts a restart of the app', () async {
      await meta.answer(true);
      meta.debugReset();
      await meta.startIfAllowed();
      await analytics.logSignupTrialStarted();
      expect(kinds(), ['start_trial']);
    });
  });

  group('asking', () {
    testWidgets('asks once, after the calm delay, and never again', (tester) async {
      var asked = 0;
      MetaEvents.debugAsk = () async {
        asked++;
        return true;
      };
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      await tester.runAsync(() async {
        final first = meta.askOnce(context);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(asked, 0, reason: 'not the moment the screen appears');
        await first;
        await meta.askOnce(context);
      });
      expect(asked, 1);
    });

    testWidgets('a refusal is stored, so it is never asked again', (tester) async {
      var asked = 0;
      MetaEvents.debugAsk = () async {
        asked++;
        return false;
      };
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      await tester.runAsync(() async {
        await meta.askOnce(context);
        await meta.askOnce(context);
      });
      expect(asked, 1);
      expect(await meta.allowed(), isFalse);
    });

    test('home asks after onboarding, and only there', () {
      final home = src('lib/screens/home_screen.dart');
      expect('MetaEvents.instance.askOnce('.allMatches(home).length, 2, reason: 'after the tour, or next launch if it was already seen');
      final done = home.substring(home.indexOf('Future<void> _onOnboardingDone'));
      expect(done.indexOf('askOnce') > done.indexOf('markSeen'), isTrue);
      expect(home.indexOf('if (_isInstructor)') < home.indexOf('askOnce'), isTrue, reason: 'an instructor is not asked');
    });
  });

  group('what is sent', () {
    test('standard events, and nothing that names a person', () async {
      await meta.answer(true);
      await analytics.logSignUp('email');
      await analytics.logSignupTrialStarted(userId: 'uid-123');
      await analytics.logPurchase(productId: 'monthly_sub', value: 9.99, currency: 'USD', transactionId: 't1');
      expect(sent[0].$2, {'method': 'email'});
      expect(sent[1].$2, isEmpty);
      expect(sent[2].$2, {'amount': 9.99, 'currency': 'USD', 'product_id': 'monthly_sub'});
      expect(src('lib/services/meta_events.dart').contains('.setUserData('), isFalse);
    });

    test('a purchase with no price is not sent', () async {
      await meta.answer(true);
      await analytics.logPurchase(productId: 'monthly_sub');
      expect(sent, isEmpty);
    });

    test('purchase keeps the GA4 rule: after server validation, user-initiated only', () {
      final iap = src('lib/services/in_app_purchase_service.dart');
      expect(iap, contains('if (isUserInitiated) _logPurchase(purchaseDetails);'));
      expect(src('lib/services/analytics_service.dart'), contains("MetaEvents.instance.send('purchase'"));
      expect("MetaEvents.instance.send('purchase'".allMatches(iap).length, 0, reason: 'one place, next to GA4');
    });
  });

  group('off until the Meta app exists', () {
    test('the shipped switch is off, and with it off nothing happens at all', () async {
      expect(metaConfigured, isFalse, reason: 'flip it only with the privacy policy live');
      MetaEvents.debugConfigured = false;
      await analytics.logSignUp('email');
      await meta.startIfAllowed();
      expect(sent, isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(meta.hasOwnSwitch, isFalse);
    });
  });

  group('the SDK stays asleep (native settings)', () {
    test('iOS: no auto-init, no auto-logging, no advertiser ID until a yes', () {
      final plist = src('ios/Runner/Info.plist');
      for (final key in ['FacebookAutoInitEnabled', 'FacebookAutoLogAppEventsEnabled', 'FacebookAdvertiserIDCollectionEnabled']) {
        expect(RegExp('<key>$key</key>\\s*<false/>').hasMatch(plist), isTrue, reason: key);
      }
      expect(plist, contains('NSUserTrackingUsageDescription'));
      expect(plist, contains('<string>fb1116179314720357</string>'), reason: 'the URL scheme is fb + the app id');
    });

    test('the App Secret is nowhere in the app', () {
      for (final f in ['ios/Runner/Info.plist', 'android/app/src/main/res/values/strings.xml', 'android/app/src/main/AndroidManifest.xml']) {
        expect(src(f).toLowerCase().contains('app_secret') || src(f).contains('AppSecret'), isFalse, reason: f);
      }
    });

    test('Android: no auto-init, no auto-logging, no advertiser ID until a yes', () {
      final manifest = src('android/app/src/main/AndroidManifest.xml');
      for (final key in ['AutoInitEnabled', 'AutoLogAppEventsEnabled', 'AdvertiserIDCollectionEnabled', 'AutoLogAppMetadataEnabled']) {
        expect(manifest, contains('android:name="com.facebook.sdk.$key" android:value="false"'), reason: key);
      }
    });

    test('the tracking text exists in all five languages, on both platforms', () {
      for (final loc in ['en', 'es', 'pl', 'ru', 'uk']) {
        expect(src('ios/Runner/$loc.lproj/InfoPlist.strings'), contains('NSUserTrackingUsageDescription'), reason: loc);
        expect(src('lib/localization/l10n/$loc.json'), contains('"tracking_body"'), reason: loc);
      }
      final project = src('ios/Runner.xcodeproj/project.pbxproj');
      expect(project, contains('uk.lproj/InfoPlist.strings'));
      // In the app's own Resources phase, the one with the assets: in the tests' phase iOS shows English to everyone.
      final phases = RegExp(r'isa = PBXResourcesBuildPhase;[\s\S]*?\);').allMatches(project).map((m) => m[0]!);
      expect(phases.firstWhere((p) => p.contains('Assets.xcassets in Resources')), contains('InfoPlist.strings in Resources'));
    });
  });
}
