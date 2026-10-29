import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/screens/biometric_consent_screen.dart';
import 'package:license_prep_app/services/instructor_service.dart';

/// Instructors P10b, plan v2 §6.3 — the biometric consent before Didit: the
/// box starts unticked and nothing reaches the server until it is ticked;
/// then consent, the session and Didit's flow, in that order.
class _FakeService extends InstructorService {
  _FakeService({this.sessionError, this.finished = true});

  final String? sessionError;
  final bool finished;
  final calls = <String>[];

  @override
  Future<void> recordBiometricConsent() async => calls.add('consent');

  @override
  Future<String> createIdentitySession() async {
    calls.add('session');
    final error = sessionError;
    if (error != null) throw FirebaseFunctionsException(code: 'failed-precondition', message: error);
    return 'tok-1';
  }

  @override
  Future<bool> runIdentityCheck(String token, String languageCode) async {
    calls.add('sdk:$token:$languageCode');
    return finished;
  }
}

Future<void> _pump(WidgetTester tester, _FakeService svc, {String locale = 'en'}) async {
  await tester.binding.setSurfaceSize(const Size(402, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale(locale)],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BiometricConsentScreen(service: svc))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

FilledButton _continue(WidgetTester tester) => tester.widget<FilledButton>(find.ancestor(of: find.text('Continue'), matching: find.byType(FilledButton)));

void main() {
  testWidgets('the box starts unticked and Continue waits for it', (tester) async {
    final svc = _FakeService();
    await _pump(tester, svc);
    expect(find.text('Biometric consent'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(_continue(tester).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(_continue(tester).onPressed, isNotNull);
    expect(svc.calls, isEmpty);
  });

  testWidgets('consent, then the session, then Didit — and back to Профиль', (tester) async {
    final svc = _FakeService();
    await _pump(tester, svc);
    await tester.tap(find.textContaining('I have read this'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(svc.calls, ['consent', 'session', 'sdk:tok-1:en']);
    expect(find.text('Thanks! We’ll let you know when the check is done.'), findsOneWidget);
    expect(find.text('Biometric consent'), findsNothing);
  });

  testWidgets('a cancelled flow goes back without the thank-you', (tester) async {
    await _pump(tester, _FakeService(finished: false));
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks! We’ll let you know when the check is done.'), findsNothing);
    expect(find.text('Biometric consent'), findsNothing);
  });

  testWidgets('says so when the 30-day limit is reached, and stays', (tester) async {
    final svc = _FakeService(sessionError: 'too-many-sessions');
    await _pump(tester, svc);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('You’ve started 3 checks in 30 days. Try again later or write to support.'), findsOneWidget);
    expect(svc.calls, ['consent', 'session']);
  });

  for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
    testWidgets('is translated in $locale', (tester) async {
      await _pump(tester, _FakeService(), locale: locale);
      final l = (await tester.runAsync(() => AppLocalizations.delegate.load(Locale(locale))))!;
      for (final key in ['iid_title', 'iid_intro', 'iid_what', 'iid_why', 'iid_who', 'iid_keep', 'iid_agree', 'iid_continue']) {
        final text = l.translate(key);
        expect(text, isNot(key), reason: '$key in $locale');
        expect(find.text(text), findsOneWidget, reason: '$key in $locale');
      }
      for (final key in ['iid_error', 'iid_too_many', 'iid_started', 'iid_failed_title', 'iid_failed_desc',
          'iid_contact_support', 'iprof_id_start', 'iprof_id_checking', 'iprof_hidden_title', 'iprof_hidden_desc',
          'stage_license_checked', 'instructor_notice_id_pending_title', 'instructor_notice_id_pending_desc', 'instructor_book_not_open']) {
        expect(l.translate(key), isNot(key), reason: '$key in $locale');
      }
    });
  }
}
