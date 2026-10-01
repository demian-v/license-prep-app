import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Signup must ask for a language, whichever way it is resumed.
///
/// Found on a real Android device on 2026-09-19, by noticing the app had
/// skipped a screen. The fresh-signup path is
///
///     signup_screen -> VerificationCodeScreen -> LanguageSelectionScreen
///                   -> StateSelectionScreen
///
/// but `SignupResumeGate` returned `StateSelectionScreen` from **both** of its
/// branches, so anyone resuming an interrupted signup was never asked their
/// language and stayed on the `'en'` default the account was created with.
///
/// It was not a corner case when it was found. `sendEmailVerificationCode` is
/// not deployed to production yet (see THE DEPLOY GATE in SESSION.md), so the
/// verification screen cannot complete, `onVerified` never fires, and the
/// resume gate — which fails open by design — was the ONLY route into the app
/// for a new user. Every new signup skipped language selection.
///
/// A structural guard rather than a widget test, for the same reason as
/// `no_hardcoded_question_state_test.dart`: the defect is which screen a
/// constructor names, and pumping either screen for real would need
/// AuthProvider, StateProvider, analytics and a live Firebase app to prove one
/// navigation target.
void main() {
  final gate = File('lib/screens/signup_resume_gate.dart');

  group('signup resume must not skip language selection', () {
    test('the gate never routes to StateSelectionScreen', () {
      final source = gate.readAsStringSync();

      final offenders = RegExp(r'StateSelectionScreen\s*\(')
          .allMatches(source)
          .map((m) => m.group(0))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'the resume path must go to LanguageSelectionScreen, which '
            'chains to StateSelectionScreen itself. Jumping straight to state '
            'skips the language question and silently leaves the account on '
            "'en'. Found: ${offenders.join(', ')}",
      );
    });

    // Since 2026-09-30 the role step sits between the code and language
    // (owner: «Create Student / Instructor Account» on the Sign Up page,
    // saved after the email code), and leads on to language itself.
    test('the gate resumes at the role step or language, on both branches', () {
      final source = gate.readAsStringSync();

      expect(source.contains('SignupRoleStep('), isTrue);
      expect(RegExp(r'LanguageSelectionScreen\s*\(').allMatches(source).length, 1);
      expect(source.contains('return next();'), isTrue, reason: 'the fail-open / already-verified branch');
      expect(source.contains('builder: (_) => next()'), isTrue, reason: 'the post-verification callback');
    });

    test('positive control — the role step leads to language selection', () {
      final role = File('lib/screens/signup_role_step.dart').readAsStringSync();
      expect(role.contains('LanguageSelectionScreen('), isTrue,
          reason: 'without this link the role step dead-ends before language');
    });

    test('positive control — language selection still leads to state', () {
      // The guard above must not be satisfiable by dropping state selection
      // altogether. Language is a step before state, not a replacement.
      final language = File('lib/screens/language_selection_screen.dart');
      expect(
        language.readAsStringSync().contains('StateSelectionScreen'),
        isTrue,
        reason: 'language selection is what forwards the user to state '
            'selection; if that link goes, the resume path dead-ends',
      );
    });

    test('positive control — fresh signup agrees with the resume path', () {
      // The two paths disagreeing is the whole bug. If signup_screen is ever
      // changed to go somewhere else, this test should fail rather than let
      // the two drift apart again.
      final signup = File('lib/screens/signup_screen.dart').readAsStringSync();
      expect(
        signup.contains('SignupRoleStep('),
        isTrue,
        reason: 'fresh signup goes to the role step (then language) after '
            'verification; the resume gate must match it',
      );
    });
  });
}
