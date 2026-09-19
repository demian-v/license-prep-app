import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/providers/language_provider.dart';
import 'package:license_prep_app/screens/verification_code_screen.dart';
import 'package:license_prep_app/services/email_verification_service.dart';

/// Risk #67 — the screen must not claim it sent a code it did not send.
///
/// Observed on a device 2026-09-19, both on screen at the same time:
///
///     "We sent a 6-digit code to gefeb69217@blobapps.com"
///     "Something went wrong. Please try again."
///
/// The heading and subtitle were rendered unconditionally, so a FAILED send
/// still asserted that a code was on its way. The user then hunts an inbox with
/// nothing in it, and "Send a new code" invites them to do it again.
///
/// It surfaced because `sendEmailVerificationCode` is not deployed yet (THE
/// DEPLOY GATE), but it is **not** a deploy-ordering bug: any send failure —
/// a dropped connection, a provider outage, a quota — produces the same
/// contradiction, so it outlives the gate.
class _StubService implements EmailVerificationService {
  SendCodeResult sendResult = const SendCodeResult(SendCodeOutcome.sent);

  @override
  Future<SendCodeResult> sendCode({String language = 'en'}) async => sendResult;

  @override
  Future<VerifyResult> verify(String code) async =>
      const VerifyResult(VerifyOutcome.verified);

  @override
  Future<VerificationStatus?> status() async => null;
}

Future<void> pump(
  WidgetTester tester,
  _StubService service, {
  bool sendOnOpen = true,
}) async {
  final app = ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider(),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en')],
      home: VerificationCodeScreen(
        email: 'someone@example.com',
        service: service,
        sendOnOpen: sendOnOpen,
        onVerified: () {},
      ),
    ),
  );

  // Same reason as email_verification_flow_test: the localization delegate does
  // real async asset I/O that pumpAndSettle does not wait for.
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pump();
}

void main() {
  group('risk #67 — no claim of a code that was not sent', () {
    testWidgets('a FAILED send does not say a code was sent', (tester) async {
      final service = _StubService()
        ..sendResult = const SendCodeResult(SendCodeOutcome.failed);

      await pump(tester, service);

      expect(
        find.textContaining('We sent'),
        findsNothing,
        reason: 'the send failed — saying it succeeded, directly above the '
            'error saying it did not, is the whole of #67',
      );
      expect(find.textContaining('Check your email'), findsNothing,
          reason: 'and do not send them to an inbox with nothing in it');
      // It must still say what the screen is for, in the future tense.
      expect(find.textContaining("We'll send"), findsOneWidget);
    });

    testWidgets('a SUCCESSFUL send does say a code was sent', (tester) async {
      // The positive control. The guard above must not be satisfiable by
      // never making the claim at all — when it is true, it is worth saying.
      final service = _StubService()
        ..sendResult = const SendCodeResult(SendCodeOutcome.sent);

      await pump(tester, service);

      expect(find.textContaining('We sent'), findsOneWidget);
      expect(find.textContaining("We'll send"), findsNothing);
    });

    testWidgets('resuming with a code already outstanding claims it', (tester) async {
      // sendOnOpen: false means a code is already in their inbox, so the claim
      // is true even though THIS screen never sent one.
      await pump(tester, _StubService(), sendOnOpen: false);

      expect(find.textContaining('We sent'), findsOneWidget);
    });

    testWidgets('a THROTTLED send still claims it, because one exists', (tester) async {
      // Throttling refuses a second send BECAUSE one went recently enough to
      // still be there. Telling the user nothing was sent would be the same
      // defect in the opposite direction.
      final service = _StubService()
        ..sendResult = const SendCodeResult(SendCodeOutcome.throttled);

      await pump(tester, service);

      expect(find.textContaining('We sent'), findsOneWidget);
    });
  });
}
