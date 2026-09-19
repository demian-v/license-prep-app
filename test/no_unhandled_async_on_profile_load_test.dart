import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Opening the Profile screen could throw an unhandled exception.
///
/// **Observed on a real iPhone, 2026-09-19**, simply by being on Profile while
/// the auth backend could not answer:
///
/// ```
/// ❌ AuthProvider: Error applying verified email: [firebase_auth/internal-error]
/// [ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception:
///     [firebase_auth/internal-error]
/// ```
///
/// `AuthProvider.applyVerifiedEmail()` ended with `throw e; // Re-throw to
/// handle in UI`. Its three callers do not handle it, and the one that runs on
/// screen load is an **async `addPostFrameCallback`** — a fire-and-forget
/// callback with no error path at all. A throw there does not surface in the
/// UI; it escapes to the zone.
///
/// In a release build that reaches `platformDispatcher.onError` and is filed
/// to Crashlytics as a **fatal**. Reachable by any user whose auth call fails
/// in flight, which a flaky connection is enough to cause.
///
/// Two things are wrong and both are fixed: a best-effort background
/// reconciliation should not rethrow (every other failure inside that same
/// method — the Firestore write, the email sync — is already logged and
/// swallowed), and an async post-frame callback should never be left
/// unguarded.
void main() {
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  final authProvider = codeOf('lib/providers/auth_provider.dart');
  final profile = codeOf('lib/screens/profile_screen.dart');

  /// The body of `applyVerifiedEmail()`.
  String applyVerifiedEmailBody() {
    final start = authProvider.indexOf('Future<void> applyVerifiedEmail()');
    expect(start, greaterThan(-1), reason: 'applyVerifiedEmail not found');
    final next = authProvider.indexOf('Future<void> updateUserEmail(', start);
    return authProvider.substring(start, next < 0 ? authProvider.length : next);
  }

  group('applyVerifiedEmail is best-effort', () {
    test('does not rethrow to callers that cannot catch it', () {
      final body = applyVerifiedEmailBody();
      expect(
        body,
        isNot(matches(RegExp(r'^\s*(throw e;|rethrow;)', multiLine: true))),
        reason: 'Its callers include an async addPostFrameCallback with no '
            'error path, so a rethrow becomes an unhandled exception — a '
            'fatal Crashlytics report in release.',
      );
    });

    test('still reports the failure rather than swallowing it silently', () {
      expect(applyVerifiedEmailBody(), contains('Error applying verified email'));
    });
  });

  group('the Profile screen load callback', () {
    test('guards its awaits', () {
      // The callback also awaits emailSyncService.smartSync(), which has the
      // same exposure. Guarding the body covers both.
      // Scoped to the method, NOT a character window. A fixed window here
      // first reached into a later method's try/catch and passed while the
      // callback was still completely unguarded — the third false-positive
      // guard test in this project, and the reason bodies are now delimited
      // by the next declaration rather than by length.
      final start = profile.indexOf('void _syncEmailOnScreenLoad()');
      expect(start, greaterThan(-1));
      final end = profile.indexOf('String _translate(', start);
      expect(end, greaterThan(start), reason: 'could not delimit the method');
      final body = profile.substring(start, end);
      expect(
        body,
        contains('addPostFrameCallback'),
        reason: 'sanity: this is the fire-and-forget callback in question',
      );
      expect(
        body,
        contains('try {'),
        reason: 'An async post-frame callback has no error path. Anything it '
            'awaits must be caught here or it escapes to the zone.',
      );
    });
  });
}
