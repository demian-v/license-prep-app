import 'dart:convert';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/meta_config.dart';
import '../widgets/tracking_consent_dialog.dart';

/// Meta's App Events, behind the person's own answer (analytics plan E; the
/// owner's decisions of 2026-10-30).
///
/// - **Nothing reaches Meta before a yes.** The SDK's auto-init and
///   auto-logging are off in Info.plist and the Android manifest, so it stays
///   asleep until [_start]. Auto-logging stays off for good: it would log
///   store purchases itself, before server validation and with renewals.
/// - **Sign-up and the trial come before the question**, which is asked after
///   onboarding, so they wait here on the device: a yes sends them, a no
///   deletes them.
/// - **A no sends nothing and blocks nothing.** On iOS the answer is the
///   system prompt; Android has none, so it gets [TrackingConsentDialog] and
///   a row in Profile.
///
/// Only [AnalyticsService] sends events, next to the GA4 ones, so the two
/// can't drift. No email, name or user id ever goes to Meta.
class MetaEvents {
  MetaEvents._();
  static final MetaEvents instance = MetaEvents._();

  static const String choiceKey = 'meta_tracking_choice_v1';
  static const String pendingKey = 'meta_tracking_pending_v1';

  /// Events kept for an answer; more than sign-up, trial and a purchase
  /// means nobody is answering (an instructor is never asked).
  static const int maxPending = 10;
  static const Duration _calmAfter = Duration(milliseconds: 900);

  /// Tests only: replaces the SDK.
  @visibleForTesting
  static void Function(String kind, Map<String, dynamic> params)? debugSink;
  @visibleForTesting
  static bool? debugConfigured;
  /// Tests only: the person's answer to the question, instead of the prompt.
  @visibleForTesting
  static Future<bool> Function()? debugAsk;

  final FacebookAppEvents _sdk = FacebookAppEvents();
  bool _started = false;

  bool get _configured => debugConfigured ?? metaConfigured;

  /// The stored answer; null until the person answered.
  Future<bool?> allowed() async => (await SharedPreferences.getInstance()).getBool(choiceKey);

  /// The Profile row exists only where the app itself asks.
  bool get hasOwnSwitch => _configured && !kIsWeb && Platform.isAndroid;

  /// Sends, keeps for the answer, or drops, by what the person said.
  Future<void> send(String kind, Map<String, dynamic> params) async {
    if (!_configured) return;
    try {
      final answer = await allowed();
      if (answer == false) return;
      if (answer == null) {
        await _keep(kind, params);
        return;
      }
      await _start();
      await _deliver(kind, params);
    } catch (e) {
      debugPrint('❌ Meta event $kind: $e');
    }
  }

  /// At launch: a yes from an earlier run wakes the SDK. A yes withdrawn in
  /// the iOS settings counts as a no from here on.
  Future<void> startIfAllowed() async {
    if (!_configured) return;
    try {
      if (await allowed() != true) return;
      if (debugSink == null && Platform.isIOS
          && await AppTrackingTransparency.trackingAuthorizationStatus != TrackingStatus.authorized) {
        await answer(false);
        return;
      }
      await _start();
    } catch (e) {
      debugPrint('❌ Meta start: $e');
    }
  }

  /// Once, at a calm moment after onboarding. Never on the first screens, and
  /// not at all for someone who already answered.
  Future<void> askOnce(BuildContext context) async {
    if (!_configured || await allowed() != null) return;
    await Future<void>.delayed(_calmAfter);
    if (!context.mounted) return;
    await answer(await (debugAsk?.call() ?? _ask(context)));
  }

  Future<bool> _ask(BuildContext context) async {
    if (Platform.isIOS) {
      return await AppTrackingTransparency.requestTrackingAuthorization() == TrackingStatus.authorized;
    }
    return await TrackingConsentDialog.show(context);
  }

  /// Stores the answer. A yes sends what was kept; a no deletes it and quiets
  /// an SDK that is already awake.
  Future<void> answer(bool yes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(choiceKey, yes);
    final kept = prefs.getStringList(pendingKey) ?? const [];
    await prefs.remove(pendingKey);
    try {
      if (!yes) {
        if (_started && debugSink == null) await _sdk.setAdvertiserIdCollectionEnabled(false);
        _started = false;
        return;
      }
      await _start();
      for (final item in kept) {
        final e = jsonDecode(item) as Map<String, dynamic>;
        await _deliver(e['kind'] as String, (e['params'] as Map).cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('❌ Meta answer: $e');
    }
  }

  Future<void> _keep(String kind, Map<String, dynamic> params) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getStringList(pendingKey) ?? const [];
    if (kept.length >= maxPending) return;
    await prefs.setStringList(pendingKey, [...kept, jsonEncode({'kind': kind, 'params': params})]);
  }

  /// On iOS the SDK refuses every call before `initializeSdk`, so this comes
  /// first. With auto-logging off, `activateApp` is what counts the launch.
  Future<void> _start() async {
    if (_started) return;
    _started = true;
    if (debugSink != null) return;
    await _sdk.initializeSdk();
    await _sdk.setAdvertiserIdCollectionEnabled(true);
    await _sdk.activateApp();
  }

  Future<void> _deliver(String kind, Map<String, dynamic> p) async {
    final sink = debugSink;
    if (sink != null) {
      sink(kind, p);
      return;
    }
    switch (kind) {
      case 'registration':
        await _sdk.logCompletedRegistration(registrationMethod: p['method'] as String?);
      case 'start_trial':
        await _sdk.logStartTrial(currency: 'USD', orderId: 'signup_trial');
      case 'purchase':
        await _sdk.logPurchase(
          amount: (p['amount'] as num).toDouble(),
          currency: p['currency'] as String,
          parameters: {'fb_content_id': p['product_id'], 'fb_content_type': 'product'},
        );
    }
  }

  /// Tests only.
  @visibleForTesting
  void debugReset() => _started = false;
}
