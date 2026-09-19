import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Logging out must always finish. It could not.
///
/// **Observed on a real iPhone, 2026-09-19.** Six taps on Log out, zero
/// completions:
///
/// ```
/// 🚪 AuthProvider: Logging out user
/// 🚪 FirebaseAuthApi: Invalidating session for user: IP03TEHlFZ...
/// 🗑️ SessionManager: Invalidating session for user: IP03TEHlFZ...
/// 🛑 SessionManager: Stopping session monitoring
///     <- nothing further, ever>
/// ```
///
/// `FirebaseAuthApi.logout()` awaits `sessionManager.invalidateSession(uid)`
/// before signing out. That is a Firestore write, and **a Firestore write
/// Future does not complete until the server acknowledges it**. With no valid
/// auth token the write was never acknowledged, so the await never returned.
///
/// Both existing defences were useless, for the same reason: `AuthProvider`
/// wraps the call in try/catch and clears local state in the catch, and
/// `invalidateSession` has its own inner try/catch — but **a hang throws
/// nothing**. Neither the success path nor the error path was ever reached.
///
/// Production impact: an offline user, or one whose token has expired, taps
/// Log out and gets silence. No error, no logout, and no retry that can ever
/// succeed — they are locked into the session until they delete the app.
///
/// The fix is ordering plus a deadline. Remote session cleanup is best-effort
/// housekeeping; signing out locally is the part that must not be optional.
void main() {
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  final api = codeOf('lib/services/api/firebase_auth_api.dart');
  final provider = codeOf('lib/providers/auth_provider.dart');

  group('the remote session write cannot stall logout', () {
    test('invalidateSession is bounded by a timeout', () {
      // The specific await that hung. Without a deadline, the inner catch
      // cannot run, because nothing is ever thrown.
      expect(
        api,
        matches(RegExp(
          r'invalidateSession\([^)]*\)\s*\.timeout\(',
          multiLine: true,
        )),
        reason: 'A Firestore write with no server ack never completes. '
            'Logout must not wait on it indefinitely.',
      );
    });

    test('sign-out still happens after the cleanup attempt', () {
      // Order matters: the session write needs the auth token, so it has to
      // come first — but it must not be able to prevent the sign-out.
      final cleanup = api.indexOf('invalidateSession(');
      final signOut = api.indexOf('FirebaseAuth.instance.signOut()');
      expect(cleanup, greaterThan(-1));
      expect(signOut, greaterThan(-1));
      expect(cleanup, lessThan(signOut));
    });
  });

  group('the provider can always clear local state', () {
    test('the API logout call is itself bounded', () {
      // Defence in depth. AuthProvider.logout()'s catch block exists to clear
      // local data "even if API logout fails" — that promise is only real if
      // the call is guaranteed to return.
      expect(
        provider,
        matches(RegExp(r'serviceLocator\.auth\.logout\(\)\s*\.timeout\(')),
        reason: 'A hang in the API layer must still reach the catch that '
            'clears the local session.',
      );
    });
  });
}
