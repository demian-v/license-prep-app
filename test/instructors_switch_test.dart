import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/config/instructors_config.dart';
import 'package:license_prep_app/providers/language_provider.dart';
import 'package:license_prep_app/widgets/super_enhanced_footer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-10-30: a release can go out without instructors. The switch
/// hides every way in, so the identity check and Stripe can't be reached.
void main() {
  tearDown(() => debugInstructorsOn = null);

  Future<void> pumpBar(WidgetTester tester, {bool forInstructor = false}) async {
    SharedPreferences.setMockInitialValues({'language': 'ru', 'app_initialized': true});
    final language = LanguageProvider();
    await tester.runAsync(language.waitForLoad);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SuperEnhancedFooter(
              currentIndex: 0,
              onTap: (_) {},
              forInstructor: forInstructor,
              badges: const [0, 0, 0],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('a plain build has instructors off', () {
    expect(instructorsReleased, isFalse,
        reason: 'Turning this on needs risk #81 closed and the real Stripe and Didit secrets');
    expect(instructorsOn, isFalse);
  });

  testWidgets('switched off, students have no Инструкторы tab', (tester) async {
    await pumpBar(tester);
    expect(find.text('Инструкторы'), findsNothing);
    expect(find.text('Тесты'), findsOneWidget);
    expect(find.text('Теория'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
  });

  testWidgets('switched on, the tab is back', (tester) async {
    debugInstructorsOn = true;
    await pumpBar(tester);
    expect(find.text('Инструкторы'), findsOneWidget);
  });

  testWidgets('an instructor keeps their own tabs either way', (tester) async {
    await pumpBar(tester, forInstructor: true);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.text('Профиль'), findsOneWidget);
  });

  test('Sign Up, Home and onboarding all go through the switch', () {
    final signup = File('lib/screens/signup_screen.dart').readAsStringSync();
    final link = signup.indexOf("auth_switch_to_instructor");
    final gate = signup.lastIndexOf('if (instructorsOn)', link);
    expect(gate, greaterThan(-1), reason: 'the instructor link must sit behind the switch');
    expect(signup.indexOf("auth_switch_to_instructor", link + 1), -1,
        reason: 'no second way to the instructor form');

    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(home, contains('if (instructorsOn) const InstructorsScreen()'));
    expect(home, contains("if (instructorsOn) 'instructors'"));

    final onboarding = File('lib/screens/onboarding_screen.dart').readAsStringSync();
    expect(onboarding, contains("if (instructorsOn)\n          _Step(l.translate('onboarding_instructors_title')"));
  });
}
