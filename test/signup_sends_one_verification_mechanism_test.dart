import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #12 follow-up — signup must use ONE verification mechanism, not two.
///
/// Found on a real device 2026-09-19 by the owner noticing the wrong email. A
/// fresh signup produced this, from `noreply@licenseprepapp.firebaseapp.com`:
///
///     Follow this link to verify your email address.
///     https://licenseprepapp.web.app/auth-redirect.html?mode=verifyEmail&oobCode=…
///
/// while the screen in front of the user was asking for a **6-digit code**.
///
/// Two mechanisms were firing at signup:
///
///  1. `userCredential.user!.sendEmailVerification()` — Firebase's built-in
///     LINK email, left over from the first attempt at #12;
///  2. `sendEmailVerificationCode` — the app's own code email, which is the
///     design (`52452b6` server, `fd6ab4e` client).
///
/// The email that arrived could not satisfy the screen that was open, and once
/// the functions are deployed every signup would send **both**.
///
/// The link call was removed, not the code flow: `verifyEmailCode` sets
/// Firebase's real `emailVerified` via `admin.auth().updateUser`
/// (`verification-callables.ts:141`), which is the only thing the link email
/// did. Deploy order makes it safe — functions ship before the app.
void main() {
  group('signup sends exactly one kind of verification email', () {
    test('no call to Firebase\'s built-in sendEmailVerification()', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trim().startsWith('//')) continue;
          // `sendEmailVerificationCode` is the callable we DO want — match the
          // built-in only, by its empty argument list.
          if (line.contains('sendEmailVerification()')) {
            offenders.add('${entity.path}:${i + 1}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'this sends Firebase\'s LINK email alongside the app\'s 6-digit '
            'code email, so the user receives one that cannot satisfy the '
            'screen they are looking at. Found at: ${offenders.join(', ')}',
      );
    });

    test('positive control — the code flow is still wired', () {
      // The guard above must not be satisfiable by removing verification
      // altogether. One mechanism, and it must be the code one.
      final service =
          File('lib/services/email_verification_service.dart').readAsStringSync();
      expect(service.contains("httpsCallable('sendEmailVerificationCode')"), isTrue,
          reason: 'the code flow is the mechanism that replaced the link');
      expect(service.contains("httpsCallable('verifyEmailCode')"), isTrue,
          reason: 'and it is what sets Firebase emailVerified server-side');
    });
  });
}
