import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/screens/instructor_kind_screen.dart';
import 'package:license_prep_app/screens/role_choice_screen.dart';

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

  testWidgets('the role cards lead to the two instructor kinds', (tester) async {
    await pump(tester, const RoleChoiceScreen());
    expect(find.text('Зарегистрироваться как'), findsOneWidget);
    expect(find.text('Ученик'), findsOneWidget);
    expect(find.text('Инструктор'), findsOneWidget);

    await tester.tap(find.text('Инструктор'));
    await tester.pumpAndSettle();
    expect(find.byType(InstructorKindScreen), findsOneWidget);
    expect(find.text('Автошкола'), findsOneWidget);
    expect(find.text('Частный инструктор'), findsOneWidget);
  });

  // The longest translations must fit a 375pt phone without overflow.
  for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
    testWidgets('role and kind screens lay out in $locale at 375pt', (tester) async {
      await pump(tester, const RoleChoiceScreen(), locale: locale);
      expect(tester.takeException(), isNull);
      await pump(tester, const InstructorKindScreen(), locale: locale);
      expect(tester.takeException(), isNull);
    });
  }
}
