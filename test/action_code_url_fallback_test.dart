import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/services/action_code_router.dart';

/// Risk #28 follow-up — the mode in the URL is the fallback when Firebase
/// will not say what an action code is for.
///
/// Measured end to end on the simulator on 2026-09-17, with a REAL
/// password-reset code from the Auth emulator: `firebase_auth` 6.0.1 on iOS
/// returned `ActionCodeInfoOperation.unknown` even though everything around
/// it was correct — `accounts:resetPassword` answered
/// `requestType: PASSWORD_RESET`, and the same call reported the right email.
/// The router fell to its default branch and sent the user to `/profile`: a
/// dead end, with no route to the new-password screen.
///
/// With this fallback the same link reaches "Change Your Password", the reset
/// completes, and the new password works while the old one is rejected. All
/// four of those were verified by running it.
void main() {
  group('the deep-link form decides whether the mode survives', () {
    // Measured, not assumed:
    //   driveusa://resetPassword?oobCode=X   -> route "/?oobCode=X"          (mode LOST)
    //   driveusa:///resetPassword?oobCode=X  -> route "/resetPassword?..."   (mode kept)
    // password-reset.html therefore offers the three-slash form FIRST.
    test('the host form loses the mode, so it cannot be recognised', () {
      expect(ActionCodeRouter.typeFromUrl('/?oobCode=abc'), isNull);
    });

    test('the path form keeps it', () {
      expect(
        ActionCodeRouter.typeFromUrl('/resetPassword?oobCode=abc'),
        ActionCodeType.passwordReset,
      );
    });
  });

  group('recognising a password reset', () {
    for (final url in [
      '/resetPassword?oobCode=abc',
      '/reset-password?oobCode=abc',
      'driveusa:///resetPassword?oobCode=abc',
      'https://x/__/auth/action?mode=resetPassword&oobCode=abc',
      '/RESETPASSWORD?oobCode=abc',
    ]) {
      test(url, () {
        expect(ActionCodeRouter.typeFromUrl(url), ActionCodeType.passwordReset);
      });
    }
  });

  group('recognising an email action', () {
    for (final url in [
      '/email-verified?oobCode=abc',
      '/emailVerified?oobCode=abc',
      'https://x/__/auth/action?mode=verifyEmail&oobCode=abc',
      // recoverEmail has no screen of its own; email verification is the
      // closest thing that can explain itself, which is what the old code did
      // for EVERY unknown mode.
      'https://x/__/auth/action?mode=recoverEmail&oobCode=abc',
    ]) {
      test(url, () {
        expect(
          ActionCodeRouter.typeFromUrl(url),
          ActionCodeType.emailVerification,
        );
      });
    }
  });

  group('when the URL says nothing', () {
    for (final url in [null, '', '/', '/profile', '/?oobCode=abc']) {
      test('${url ?? "null"} yields no hint', () {
        expect(ActionCodeRouter.typeFromUrl(url), isNull);
      });
    }

    test('a mode-less URL must not be guessed as a password reset', () {
      // The fallback decides which SCREEN opens. Guessing "reset" for an
      // unknown link would hand a stranger the password screen; the code is
      // still validated by Firebase there, but the screen should not be
      // offered on a guess.
      expect(ActionCodeRouter.typeFromUrl('/something?oobCode=abc'), isNull);
    });
  });
}
