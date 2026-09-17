import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/providers/language_provider.dart';
import 'package:license_prep_app/screens/verification_code_screen.dart';
import 'package:license_prep_app/services/email_verification_service.dart';

/// Risk #12 — the code-entry screen.
///
/// The service is stubbed: every rule that matters (expiry, the attempt cap,
/// throttling, hashing) is enforced server-side and covered by the functions
/// suite. What is worth testing here is the screen's own behaviour — that it
/// submits, that it says something specific when refused, and that it does not
/// spend a send from the user's budget when resuming.

class _StubService implements EmailVerificationService {
  final List<String> submitted = [];
  int sendCalls = 0;

  SendCodeResult sendResult = const SendCodeResult(SendCodeOutcome.sent);
  VerifyResult verifyResult = const VerifyResult(VerifyOutcome.verified);

  @override
  Future<SendCodeResult> sendCode({String language = 'en'}) async {
    sendCalls++;
    return sendResult;
  }

  @override
  Future<VerifyResult> verify(String code) async {
    submitted.add(code);
    return verifyResult;
  }

  @override
  Future<VerificationStatus?> status() async => null;
}

Future<void> pumpScreen(
  WidgetTester tester,
  _StubService service, {
  bool sendOnOpen = true,
  VoidCallback? onVerified,
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
          onVerified: onVerified ?? () {},
        ),
      ),
  );

  // The localization delegate reads its JSON from the asset bundle. That is
  // real async I/O, which pumpAndSettle does NOT wait for — so without
  // runAsync the screen renders empty and every finder below sees nothing.
  // It won the race when this file ran alone and lost it in a batch.
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  // Bounded pumps rather than pumpAndSettle: the resend cooldown is a
  // Timer.periodic, and settling would fast-forward simulated time through the
  // whole 60 seconds, which is exactly what one of the tests below asserts has
  // NOT happened yet.
  await tester.pump();
  await tester.pump();
}

Future<void> enterCode(WidgetTester tester, String code) async {
  final fields = find.byType(TextField);
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(fields.at(i), code[i]);
    await tester.pump();
  }
  // Let the stubbed verify() future resolve and the resulting setState land.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('requests a code when opened fresh', (tester) async {
    final service = _StubService();
    await pumpScreen(tester, service);
    expect(service.sendCalls, 1);
  });

  testWidgets('does NOT request a code when resuming with one outstanding', (tester) async {
    // Sending again would invalidate the code already in the user's inbox and
    // spend one from their hourly budget.
    final service = _StubService();
    await pumpScreen(tester, service, sendOnOpen: false);
    expect(service.sendCalls, 0);
  });

  testWidgets('shows six entry boxes', (tester) async {
    await pumpScreen(tester, _StubService());
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('submits automatically once six digits are entered', (tester) async {
    final service = _StubService();
    await pumpScreen(tester, service);
    await enterCode(tester, '123456');
    expect(service.submitted, ['123456']);
  });

  testWidgets('calls onVerified when the code is accepted', (tester) async {
    final service = _StubService();
    var verified = false;
    await pumpScreen(tester, service, onVerified: () => verified = true);
    await enterCode(tester, '123456');
    expect(verified, isTrue);
  });

  testWidgets('does NOT call onVerified when the code is wrong', (tester) async {
    final service = _StubService()
      ..verifyResult = const VerifyResult(VerifyOutcome.wrongCode, attemptsLeft: 4);
    var verified = false;
    await pumpScreen(tester, service, onVerified: () => verified = true);
    await enterCode(tester, '000000');
    expect(verified, isFalse);
  });

  testWidgets('a wrong code reports how many attempts remain', (tester) async {
    final service = _StubService()
      ..verifyResult = const VerifyResult(VerifyOutcome.wrongCode, attemptsLeft: 3);
    await pumpScreen(tester, service);
    await enterCode(tester, '000000');
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('clears the boxes after a wrong code, ready to retype', (tester) async {
    final service = _StubService()
      ..verifyResult = const VerifyResult(VerifyOutcome.wrongCode, attemptsLeft: 4);
    await pumpScreen(tester, service);
    await enterCode(tester, '000000');

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.every((f) => f.controller!.text.isEmpty), isTrue);
  });

  testWidgets('an expired code says so, rather than "wrong code"', (tester) async {
    // Six different refusals used to look identical to the user; each now says
    // something the user can act on.
    final service = _StubService()
      ..verifyResult = const VerifyResult(VerifyOutcome.expired);
    await pumpScreen(tester, service);
    await enterCode(tester, '123456');
    expect(find.textContaining('expired'), findsOneWidget);
  });

  testWidgets('a burned code tells the user to request a new one', (tester) async {
    final service = _StubService()
      ..verifyResult = const VerifyResult(VerifyOutcome.tooManyAttempts);
    await pumpScreen(tester, service);
    await enterCode(tester, '123456');
    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('a failed send is reported, not swallowed', (tester) async {
    final service = _StubService()
      ..sendResult = const SendCodeResult(SendCodeOutcome.transportFailed);
    await pumpScreen(tester, service);
    expect(find.textContaining('could not send'), findsOneWidget);
  });

  testWidgets('pasting a full code into one box fills all six and submits', (tester) async {
    final service = _StubService();
    await pumpScreen(tester, service);
    await tester.enterText(find.byType(TextField).first, '654321');
    await tester.pump();
    await tester.pump();
    expect(service.submitted, ['654321']);
  });

  testWidgets('resend is disabled while the cooldown runs', (tester) async {
    final service = _StubService();
    await pumpScreen(tester, service);
    // A send happened on open, so the cooldown is active.
    final button = tester.widget<TextButton>(find.byType(TextButton).first);
    expect(button.onPressed, isNull);
  });

  testWidgets('already-verified short-circuits to onVerified', (tester) async {
    // Covers verification completing elsewhere (another device, a retry).
    final service = _StubService()
      ..sendResult = const SendCodeResult(SendCodeOutcome.alreadyVerified);
    var verified = false;
    await pumpScreen(tester, service, onVerified: () => verified = true);
    expect(verified, isTrue);
  });
}
