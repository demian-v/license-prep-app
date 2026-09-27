import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/models/progress.dart';
import 'package:license_prep_app/providers/progress_provider.dart';

/// Two leaks from one account into the next, found on the iOS simulator on
/// 2026-09-26 by signing out and signing up as a new user on the same device.
///
/// 1. **Progress.** Storage has been per account since risk #21, but the
///    in-memory `ProgressProvider` was read once at launch. The new account saw
///    the previous one's Теория ticks — and its next save would have written
///    them into its own record.
/// 2. **Content.** The new account had no trial; the server refused its
///    Ukrainian content, and Теория went on listing the previous account's
///    Russian modules, because the refusal left the old list in memory and the
///    "subscription required" screen only shows when that list is empty.
void main() {
  String stripComments(String dart) => dart
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  group('progress follows the signed-in account', () {
    UserProgress someonesProgress() => UserProgress(
          completedModules: ['traffic_rules_ru_IL_02'],
          testScores: {'exam': 0.9},
          selectedLicense: 'driver',
          topicProgress: {'topic_2': 1.0},
          savedQuestions: ['q1'],
        );

    test('an account with nothing stored starts empty, not with the last one', () {
      final provider = ProgressProvider(someonesProgress());
      var notified = 0;
      provider.addListener(() => notified++);

      provider.reloadFrom(null);

      expect(provider.progress.completedModules, isEmpty);
      expect(provider.progress.testScores, isEmpty);
      expect(provider.progress.topicProgress, isEmpty);
      expect(provider.progress.savedQuestions, isEmpty);
      expect(notified, 1, reason: 'Теория must redraw without the old ticks');
    });

    test("an account with a stored record gets exactly that record", () {
      final provider = ProgressProvider(ProgressProvider.fromStored(null));
      final theirs = jsonEncode(someonesProgress().toJson());

      provider.reloadFrom(theirs);

      expect(provider.progress.completedModules, ['traffic_rules_ru_IL_02']);
      expect(provider.progress.topicProgress['topic_2'], 1.0);
    });

    test('main.dart reloads progress when the signed-in uid changes', () {
      final main = stripComments(File('lib/main.dart').readAsStringSync());
      final create = main.indexOf('final progressProvider = ProgressProvider(progress);');
      expect(create, greaterThan(-1));
      final after = main.substring(create);
      final listen = after.indexOf('authStateChanges().listen(');
      expect(listen, greaterThan(-1),
          reason: 'without a listener the launch-time progress is never replaced');
      final reload = after.indexOf('progressProvider.reloadFrom(', listen);
      expect(reload, greaterThan(listen));
      expect(after.substring(listen, reload).contains('return;'), isTrue,
          reason: 'same uid (a token refresh, the launch restore) must not reload');
    });
  });

  group('the subscription follows the signed-in account', () {
    // SubscriptionProvider reaches for Firestore when constructed, so these
    // read the source, as the other structural tests in this suite do.
    test('reset forgets the plan, the trial-days cache and the recovery guard', () {
      final source = stripComments(
          File('lib/providers/subscription_provider.dart').readAsStringSync());
      final start = source.indexOf('void resetForAccountChange()');
      expect(start, greaterThan(-1));
      final body = source.substring(start, source.indexOf('\n  }\n', start));
      expect(body.contains('_subscription = null'), isTrue);
      expect(body.contains('_cachedTrialDaysRemaining = null'), isTrue,
          reason: 'days left is cached for 30s — the old number would show');
      expect(body.contains('_trialRecoveryAttempted = false'), isTrue,
          reason: 'risk #24 recovery is one attempt per account');
      expect(body.contains('notifyListeners()'), isTrue);
      expect(body.contains('initialize('), isFalse,
          reason: 'loading here would race trial creation during signup');
    });

    test('main.dart resets it when the signed-in uid changes', () {
      final main = stripComments(File('lib/main.dart').readAsStringSync());
      final listen = main.indexOf('authStateChanges().listen((authUser)');
      expect(listen, greaterThan(-1));
      final end = main.indexOf('});', listen);
      final listener = main.substring(listen, end);
      final guard = listener.indexOf('return;');
      final reset = listener.indexOf('subscriptionProvider.resetForAccountChange()');
      expect(reset, greaterThan(guard),
          reason: 'only on a real account change, not a token refresh');
    });
  });

  group('a refusal does not leave the last request on screen', () {
    test('an entitlement denial clears the modules and topics in memory', () {
      final source =
          stripComments(File('lib/providers/content_provider.dart').readAsStringSync());
      final start = source.indexOf('Future<void> _fetchContent(');
      final end = source.indexOf('Future<void> preloadRelatedContent(', start);
      final fetch = source.substring(start, end);
      final outerCatch = fetch.lastIndexOf('} catch (e) {');
      final denial = fetch.indexOf('if (_isEntitlementDenial(e)) {', outerCatch);
      expect(denial, greaterThan(outerCatch));
      final branch = fetch.substring(denial, fetch.indexOf('}', denial));
      expect(branch.contains('_contentRequiresSubscription = true'), isTrue);
      expect(branch.contains('_modules = []'), isTrue,
          reason: 'a kept list hides SubscriptionRequiredView');
      expect(branch.contains('_topics = []'), isTrue);
    });
  });
}
