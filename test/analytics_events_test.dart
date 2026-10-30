import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/models/user_subscription.dart';
import 'package:license_prep_app/providers/subscription_provider.dart';
import 'package:license_prep_app/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The analytics plan, parts A and B (2026-10-29; vault
/// raw/drive_usa/2026-10-29-Analytics plan.md): the paywall and purchase
/// funnel, a truthful `subscription_status`, the activation and instructor
/// events, and no noise events.
///
/// Events are read through [AnalyticsService.debugEventSink], which runs
/// before the initialised check, so no Firebase is needed. Where the code
/// cannot run in a unit test (StoreKit, the navigator), the wiring is asserted
/// on the source, as the purchase tests already do.
void main() {
  final events = <(String, Map<String, dynamic>?)>[];
  final props = <String, String?>{};
  final analytics = AnalyticsService();

  setUp(() {
    events.clear();
    props.clear();
    analytics.reset();
    SharedPreferences.setMockInitialValues({});
    AnalyticsService.debugEventSink = (name, params) => events.add((name, params));
    AnalyticsService.debugUserPropertySink = (name, value) => props[name] = value;
  });
  tearDown(() {
    AnalyticsService.debugEventSink = null;
    AnalyticsService.debugUserPropertySink = null;
  });

  List<String> names() => [for (final e in events) e.$1];
  Map<String, dynamic>? params(String name) => events.firstWhere((e) => e.$1 == name).$2;
  String src(String path) => File(path).readAsStringSync();

  group('paywall and purchase', () {
    test('paywall_viewed carries where it was opened from', () async {
      await analytics.logPaywallViewed('theory_locked');
      expect(params('paywall_viewed'), {'source': 'theory_locked'});
    });

    test("purchase has GA4's revenue fields", () async {
      await analytics.logPurchase(productId: 'monthly_sub', value: 9.99, currency: 'USD', transactionId: 't1');
      expect(params('purchase'), {
        'item_id': 'monthly_sub',
        'product_id': 'monthly_sub',
        'value': 9.99,
        'currency': 'USD',
        'transaction_id': 't1',
      });
    });

    test('purchase_failed keeps the reason short', () async {
      await analytics.logPurchaseFailed('yearly_sub', 'x' * 300);
      expect((params('purchase_failed')!['reason'] as String).length, 100);
    });

    test('the purchase flow logs started, failed, cancelled, restore and purchase', () {
      final iap = src('lib/services/in_app_purchase_service.dart');
      for (final call in [
        'logPurchaseStarted(productId)',
        "logPurchaseFailed(productId, 'store_unavailable')",
        "logPurchaseFailed(productId, 'product_not_found')",
        'logPurchaseCancelled(purchaseDetails.productID)',
        "logRestorePurchases('started')",
        "logRestorePurchases('unavailable')",
        "logRestorePurchases('error')",
      ]) {
        expect(iap, contains(call));
      }
      // Renewals and restores are validated through the same path; only the
      // purchase the user just made is a GA4 purchase.
      expect(iap, contains('if (isUserInitiated) _logPurchase(purchaseDetails);'));
      expect('_logPurchase('.allMatches(iap).length, 2, reason: 'one call, one definition');
    });

    test('every way into the paywall says where it came from', () {
      final bare = RegExp(r"pushNamed\(context, '/subscription'\)");
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        expect(bare.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
      expect(src('lib/screens/subscription_screen.dart'), contains('logPaywallViewed('));
    });
  });

  group('subscription_status', () {
    UserSubscription sub(String plan, {DateTime? trialEnds, DateTime? billing, String status = 'active'}) =>
        UserSubscription(
          id: 's',
          userId: 'u',
          packageId: 1,
          status: status,
          isActive: true,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
          trialEndsAt: trialEnds,
          duration: 30,
          nextBillingDate: billing,
          planType: plan,
        );
    final future = DateTime.now().add(const Duration(days: 3));
    final past = DateTime.now().subtract(const Duration(days: 3));

    test('follows the loaded subscription', () {
      expect(SubscriptionProvider.analyticsStatus(null), 'none');
      expect(SubscriptionProvider.analyticsStatus(sub('trial', trialEnds: future)), 'trial');
      expect(SubscriptionProvider.analyticsStatus(sub('trial', trialEnds: past)), 'expired');
      expect(SubscriptionProvider.analyticsStatus(sub('monthly', billing: future)), 'monthly');
      expect(SubscriptionProvider.analyticsStatus(sub('yearly', billing: future)), 'yearly');
      expect(SubscriptionProvider.analyticsStatus(sub('yearly', billing: past)), 'expired');
    });

    test('is no longer hard-coded at app start or login', () {
      expect(src('lib/main.dart'), isNot(contains("subscriptionStatus: 'trial'")));
      expect(src('lib/providers/auth_provider.dart'), isNot(contains('subscriptionStatus:')));
      expect(src('lib/providers/subscription_provider.dart'),
          contains("setUserProperty('subscription_status', analyticsStatus(sub))"));
    });
  });

  group('activation', () {
    test('first_learning_action once per device, with what it was', () async {
      await analytics.logTheoryModuleSelected(moduleId: 'm1');
      await analytics.logExamStarted();
      await analytics.trackQTopicStarted(
        sessionId: 's', stateId: 'IL', licenseType: 'car', topicId: 't', topicName: 'Signs', questionCount: 10,
      );
      expect(names().where((n) => n == 'first_learning_action').length, 1);
      expect(params('first_learning_action'), {'kind': 'theory'});
      expect(names(), containsAll(['theory_module_selected', 'exam_started', 'q_topic_started']));
    });

    test('first_learning_action survives a restart', () async {
      SharedPreferences.setMockInitialValues({AnalyticsService.firstLearningActionKey: true});
      await analytics.logPracticeStarted(practiceId: 'p', state: 'IL', language: 'en', licenseType: 'car');
      expect(names(), isNot(contains('first_learning_action')));
    });

    test('trial_expired_seen once per app run, however often the card builds', () async {
      await analytics.logTrialExpiredSeen();
      await analytics.logTrialExpiredSeen();
      expect(names().where((n) => n == 'trial_expired_seen').length, 1);
      analytics.reset();
      await analytics.logTrialExpiredSeen();
      expect(names().where((n) => n == 'trial_expired_seen').length, 2);
    });
  });

  group('user_type', () {
    test('an instructor keeps the kind set at registration', () async {
      await analytics.setUserType('instructor', instructorKind: 'school');
      await analytics.setUserType('instructor');
      expect(props, {'user_type': 'instructor', 'instructor_kind': 'school'});
    });

    test('a student has no instructor kind', () async {
      props['instructor_kind'] = 'private';
      await analytics.setUserType('student');
      expect(props, {'instructor_kind': null, 'user_type': 'student'});
    });
  });

  group('wiring', () {
    test('instructor-side events come from the service calls that succeed', () {
      final s = src('lib/services/instructor_service.dart');
      for (final call in [
        'logInstructorRegistered(kind: kind)',
        'logLicenseSubmitted()',
        'logProfilePhotoUploaded()',
        'logLicensePhotoUploaded()',
        "if (section == 'availability') await _analytics.logAvailabilitySaved()",
        'logPayoutsSetupStarted()',
        'logIdentityCheckStarted()',
        'logIdentityCheckResult(',
        'logInstructorFavorited(on: saved)',
        'logInstructorsTabViewed(',
      ]) {
        expect(s, contains(call));
      }
    });

    test('push taps, account deletion and filters are logged', () {
      expect(src('lib/services/push_service.dart'), contains('logNotificationOpened('));
      expect(src('lib/providers/auth_provider.dart'), contains('logAccountDeleted(userType: userType)'));
      expect(src('lib/screens/instructors_screen.dart'), contains('logInstructorListFiltered('));
    });

    test('key screens name themselves', () {
      for (final f in [
        'home_screen',
        'subscription_screen',
        'exam_question_screen',
        'exam_result_screen',
        'practice_result_screen',
        'quiz_result_screen',
        'instructor_detail_screen',
        'chat_thread_screen',
        'booking_screen',
        'instructor_registration_screen',
      ]) {
        expect(src('lib/screens/$f.dart'), contains('logScreenView('), reason: f);
      }
    });
  });

  group('cleanup', () {
    test('no noise events', () {
      final lib = [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart')) f.readAsStringSync(),
      ].join('\n');
      for (final noise in ["'user_configured'", "'anonymous_user_configured'", "'user_properties_updated'"]) {
        expect(lib, isNot(contains(noise)));
      }
      // A failed prefetch still reports (a counter you notice); success did
      // not say anything.
      expect("'content_prefetch'".allMatches(src('lib/services/content_loading_manager.dart')).length, 1);
    });

    test('the never-called duplicates are gone', () {
      final s = src('lib/services/analytics_service.dart');
      for (final m in [
        'logContentViewed', 'logExamStart(', 'logExamComplete', 'logPracticeStart(', 'logPracticeComplete',
        'logQuizStart', 'logQuizComplete', 'logQuestionAnswered', 'logQuestionSaved', 'logQuestionUnsaved',
        'logLicenseSelected', 'logStateSelected', 'logPasswordReset(', 'logSessionStart',
        'logTheoryModuleListFailed', 'logSubscriptionPurchased', 'logSubscriptionViewed',
      ]) {
        expect(s, isNot(contains(m)), reason: m);
      }
    });
  });
}
