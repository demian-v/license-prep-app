import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:license_prep_app/services/crash_reporter.dart';

/// Records what would have been sent to Crashlytics.
///
/// `FirebaseCrashlytics` has no interface to implement and needs a live
/// Firebase app, so this fakes it by overriding the methods `CrashReporter`
/// calls. `noSuchMethod` covers the rest of the (large) surface, which this
/// class deliberately does not use.
class _FakeCrashlytics implements FirebaseCrashlytics {
  final Map<String, String> keys = {};
  final List<String> logs = [];
  final List<({Object error, String? reason, bool fatal})> recorded = [];
  String? userId;

  /// Set to make every call throw, to prove failures here cannot reach callers.
  bool throwOnEverything = false;

  void _maybeThrow() {
    if (throwOnEverything) throw StateError('Crashlytics is unavailable');
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    _maybeThrow();
    keys[key] = value.toString();
  }

  @override
  Future<void> log(String message) async {
    _maybeThrow();
    logs.add(message);
  }

  @override
  Future<void> setUserIdentifier(String identifier) async {
    _maybeThrow();
    userId = identifier;
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) async {
    _maybeThrow();
    recorded.add((error: exception as Object, reason: reason?.toString(), fatal: fatal));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used by CrashReporter');
}

void main() {
  late _FakeCrashlytics fake;
  late CrashReporter reporter;

  setUp(() {
    fake = _FakeCrashlytics();
    reporter = CrashReporter(crashlytics: fake);
  });

  group('custom keys', () {
    test('publishes state, language, subscription status and entitlement', () async {
      await reporter.setUserState('NY');
      await reporter.setLanguage('ru');
      await reporter.setSubscription(status: 'trial/active', entitled: true);

      expect(fake.keys, {
        'state': 'NY',
        'language': 'ru',
        'subscription_status': 'trial/active',
        'entitled': 'true',
      });
    });

    test('status and entitlement are published separately, so they can disagree', () async {
      // The case that matters: a trial document that still says active, past
      // its end date. Collapsing these into one key would lose exactly the
      // discrepancy worth knowing about.
      await reporter.setSubscription(status: 'trial/active', entitled: false);

      expect(fake.keys['subscription_status'], 'trial/active');
      expect(fake.keys['entitled'], 'false');
    });

    test('a null state is "none", not the string "null"', () async {
      await reporter.setUserState(null);
      expect(fake.keys['state'], 'none');
    });
  });

  group('user identifier', () {
    test('is set from the uid', () async {
      await reporter.setUserIdentifier('uid-123');
      expect(fake.userId, 'uid-123');
    });

    test('null CLEARS it', () async {
      // Otherwise the next person to sign in on a shared device inherits the
      // previous account's identifier on their crash reports.
      await reporter.setUserIdentifier('uid-123');
      await reporter.setUserIdentifier(null);
      expect(fake.userId, '');
    });
  });

  group('non-fatal errors', () {
    test('records with a reason and extra keys, and is NOT fatal', () async {
      await reporter.recordNonFatal(
        StateError('receipt rejected'),
        StackTrace.current,
        reason: 'receipt_validation_rejected',
        keys: {'receipt_platform': 'ios'},
      );

      expect(fake.recorded, hasLength(1));
      expect(fake.recorded.single.reason, 'receipt_validation_rejected');
      expect(fake.recorded.single.fatal, isFalse,
          reason: 'a swallowed failure must not be reported as a crash');
      expect(fake.keys['receipt_platform'], 'ios');
    });
  });

  group('diagnostics never break the app', () {
    // The whole class is wrapped for this. A crash reporter that throws is
    // worse than no crash reporter: it would take out a purchase or a build.
    test('every method swallows a failing Crashlytics', () async {
      fake.throwOnEverything = true;

      await expectLater(reporter.setUserState('NY'), completes);
      await expectLater(reporter.setLanguage('en'), completes);
      await expectLater(
          reporter.setSubscription(status: 'none', entitled: false), completes);
      await expectLater(reporter.setUserIdentifier('uid-1'), completes);
      await expectLater(reporter.log('nav: tab theory'), completes);
      await expectLater(
        reporter.recordNonFatal(StateError('x'), null, reason: 'r'),
        completes,
      );
    });
  });

  group('CrashBreadcrumbObserver', () {
    test('logs named routes on push, pop and replace', () {
      final observer = CrashBreadcrumbObserver(reporter);
      Route<void> route(String? name) =>
          PageRouteBuilder<void>(
            settings: RouteSettings(name: name),
            pageBuilder: (_, __, ___) => const SizedBox(),
          );

      observer.didPush(route('/home'), null);
      observer.didPop(route('/subscription'), null);
      observer.didReplace(newRoute: route('/login'), oldRoute: null);

      expect(fake.logs, [
        'nav: push /home',
        'nav: pop /subscription',
        'nav: replace /login',
      ]);
    });

    test('drops unnamed routes rather than logging "null"', () {
      // Roughly half this app's navigation is an unnamed MaterialPageRoute.
      // Those points log explicitly at their call sites instead.
      final observer = CrashBreadcrumbObserver(reporter);
      observer.didPush(
        PageRouteBuilder<void>(pageBuilder: (_, __, ___) => const SizedBox()),
        null,
      );

      expect(fake.logs, isEmpty);
    });
  });
}
