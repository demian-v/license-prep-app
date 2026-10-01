import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/screens/instructor_kind_screen.dart';

/// Instructors plan v2 §4.1–4.2, order from the owner (2026-09-30):
/// Sign Up -> Check email -> Student or Instructor. The account exists before
/// the answer, so the trial must wait for it — an instructor must never spend
/// the device's only trial (review bug #2, 2026-09-30).
void main() {
  group('an instructor signup never reaches a trial call', () {
    // The trial is started by initializeTrial, and only on the role choice.
    test('AuthProvider.signup does not start a trial', () {
      final src = File('lib/providers/auth_provider.dart').readAsStringSync();
      final start = src.indexOf('Future<bool> signup(');
      final body = src.substring(start, src.indexOf('Future<void> updateUserLanguage(', start));
      expect(body.contains('initializeTrial('), isFalse, reason: 'the role is not known yet at signup');
    });

    test('chooseSignupRole saves the intent, then starts only a student trial', () {
      final src = File('lib/providers/auth_provider.dart').readAsStringSync();
      final body = src.substring(src.indexOf('Future<void> chooseSignupRole('));
      final intent = body.indexOf('setSignupRole(');
      final guard = body.indexOf("if (role == 'student') {");
      final trial = body.indexOf('initializeTrial(');
      expect(intent, greaterThan(-1), reason: 'the server must know the role before any trial call');
      expect(guard, greaterThan(intent));
      expect(trial, greaterThan(guard), reason: 'initializeTrial now runs outside the student guard');
    });
  });

  Future<void> pump(WidgetTester tester, Widget home, {String locale = 'ru', double width = 375}) async {
    tester.view.physicalSize = Size(width * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
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
        home: home,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
  }

  // Owner, 2026-09-30: no «Sign up as» screen — the Sign Up page has the
  // student / instructor switch; the kind screen comes after the language.
  testWidgets('the two instructor kinds', (tester) async {
    await pump(tester, const InstructorKindScreen());
    expect(find.text('Автошкола'), findsOneWidget);
    expect(find.text('Частный инструктор'), findsOneWidget);
  });

  test('the Sign Up page saves the role; no role cards remain', () {
    expect(File('lib/screens/role_choice_screen.dart').existsSync(), isFalse);
    final signup = File('lib/screens/signup_screen.dart').readAsStringSync();
    expect(signup.contains("signupRole: _instructor ? 'instructor' : 'student'"), isTrue);
  });

  // Owner, 2026-09-30: picking a kind seemed to skip «Teaching languages» —
  // the wizard resumed its saved step. From the kind screen it now starts at
  // step 1; and a draft is only ever shown to the account that wrote it.
  test('the wizard starts at step 1 from the kind screen; drafts are per account', () {
    final step = File('lib/screens/signup_role_step.dart').readAsStringSync();
    expect(step.contains('InstructorRegistrationScreen(resumeStep: false)'), isTrue);
    final wizard = File('lib/screens/instructor_registration_screen.dart').readAsStringSync();
    expect(wizard.contains("_step = widget.resumeStep && _steps.contains(saved) ? saved : _Step.languages;"), isTrue);
    expect(wizard.contains("d != null && d['uid'] == user?.id ? d : null"), isTrue);
    expect(wizard.contains("'uid': uid,"), isTrue);
  });

  test('language comes before «How do you teach?» for an instructor', () {
    final step = File('lib/screens/signup_role_step.dart').readAsStringSync();
    expect(step.contains("if (_role == 'instructor') return LanguageSelectionScreen();"), isTrue);
    final language = File('lib/screens/language_selection_screen.dart').readAsStringSync();
    expect(language.contains('pendingInstructor\n                    ? const InstructorKindScreen()'), isTrue);
    expect(step.contains("role == 'instructor' ? const InstructorRegistrationScreen(resumeStep: false)"), isTrue,
        reason: 'after the kind, the wizard — not the language question again');
  });

  // The longest translations must fit a 375pt phone without overflow.
  for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
    testWidgets('the kind screen lays out in $locale at 375pt', (tester) async {
      await pump(tester, const InstructorKindScreen(), locale: locale);
      expect(tester.takeException(), isNull);
    });
  }
}
