import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// #71 hardening — `user!` must not be dereferenced after an `await`.
///
/// `AuthProvider.updateUserState` opens with `if (user != null)` and then
/// awaits several network calls. `user` is a plain mutable field on a
/// ChangeNotifier (`User? user;`), so that check does **not** hold across the
/// awaits: anything that signs the user out — token expiry, a session conflict,
/// an explicit logout — nulls it while they are in flight, and the next `user!`
/// throws "Null check operator used on a null value".
///
/// That is the message the device reported as `state_change_failed` on
/// 2026-09-19 while offline, which is also when the API fallback path runs.
/// **Whether this method is the actual source of #71 is NOT yet proven** — the
/// stack has not been read. This test exists because the hazard is real on its
/// own terms, not because the cause is established. Do not close #71 on it.
///
/// Note there is no `mounted` to guard with here: `mounted` belongs to State,
/// and this is a ChangeNotifier. Capturing the value once, before any await,
/// is the equivalent.
void main() {
  final file = File('lib/providers/auth_provider.dart');
  final lines = file.readAsLinesSync();

  int lineOf(String needle) =>
      lines.indexWhere((l) => l.contains(needle));

  group('#71 hardening — no user! across an await in updateUserState', () {
    test('the method captures user once, before any await', () {
      final start = lineOf('Future<void> updateUserState(');
      expect(start, isNot(-1), reason: 'updateUserState not found');

      final capture = lines
          .sublist(start, start + 25)
          .indexWhere((l) => !l.trim().startsWith('//') && l.contains('final before = user!'));

      expect(capture, isNot(-1),
          reason: 'updateUserState must capture `user` into a local before it '
              'awaits anything, so the later fallbacks are total');
    });

    test('no bare user! survives inside the method body', () {
      final start = lineOf('Future<void> updateUserState(');
      // The method ends at the next top-level method declaration.
      var end = start + 1;
      while (end < lines.length && !RegExp(r'^  [A-Za-z<].*\(').hasMatch(lines[end])) {
        end++;
      }

      final offenders = <int>[];
      for (var i = start; i < end; i++) {
        final l = lines[i];
        if (l.trim().startsWith('//')) continue;
        if (!l.contains('user!')) continue;
        // The single deliberate capture is the one permitted use.
        if (l.contains('final before = user!')) continue;
        offenders.add(i + 1);
      }

      expect(
        offenders,
        isEmpty,
        reason: 'every other `user!` in this method sits after an await and is '
            'a time-of-check/time-of-use bug. Use the captured `before`, or '
            '`user ?? before`. Offending line(s): ${offenders.join(', ')}',
      );
    });

    test('positive control — the offline fallback still updates something', () {
      // The guard must not be satisfied by deleting the fallback. Offline is
      // the path that matters here: "API not available" is what a dropped
      // connection looks like.
      final source = file.readAsStringSync();
      expect(
        source.contains('(user ?? before).copyWith(state: state)'),
        isTrue,
        reason: 'the offline fallback must still apply the new state, using '
            'the pre-await capture rather than a bare user!',
      );
    });
  });
}
