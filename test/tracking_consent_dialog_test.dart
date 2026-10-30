import 'dart:async';
import 'dart:io';


import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/widgets/tracking_consent_dialog.dart';

/// Android's question (analytics plan E): the same weight for both answers,
/// and no way past it without one.
void main() {
  Future<BuildContext> pump(WidgetTester tester, String locale) async {
    late BuildContext context;
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
        home: Builder(builder: (c) {
          context = c;
          return const Scaffold();
        }),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();
    return context;
  }

  const allow = {'en': 'Allow', 'es': 'Permitir', 'pl': 'Zezwól', 'ru': 'Разрешить', 'uk': 'Дозволити'};
  const decline = {'en': "Don't allow", 'es': 'No permitir', 'pl': 'Nie zezwalaj', 'ru': 'Не разрешать', 'uk': 'Не дозволяти'};

  for (final locale in allow.keys) {
    testWidgets('$locale: Allow is true, the other answer false', (tester) async {
      final context = await pump(tester, locale);
      for (final (label, expected) in [(allow[locale]!, true), (decline[locale]!, false)]) {
        bool? got;
        unawaited(TrackingConsentDialog.show(context, required: true).then((v) => got = v));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(got, expected);
      }
    });
  }

  testWidgets('after onboarding, tapping outside does not answer', (tester) async {
    final context = await pump(tester, 'en');
    bool? got;
    unawaited(TrackingConsentDialog.show(context, required: true).then((v) => got = v));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(got, isNull);
    expect(find.text('Allow'), findsOneWidget);
  });

  testWidgets('after onboarding, the back button does not answer', (tester) async {
    final context = await pump(tester, 'en');
    bool? got;
    unawaited(TrackingConsentDialog.show(context, required: true).then((v) => got = v));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(got, isNull);
    expect(find.text('Allow'), findsOneWidget, reason: 'a closed dialog would delete the waiting sign-up and trial');
  });

  testWidgets('from Profile, the back button closes it and answers nothing', (tester) async {
    final context = await pump(tester, 'en');
    var done = false;
    bool? got = true;
    unawaited(TrackingConsentDialog.show(context).then((v) {
      got = v;
      done = true;
    }));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(got, isNull, reason: 'someone who said yes and backs out stays on');
    expect(find.text('Allow'), findsNothing);
  });

  test('Profile keeps the choice when the dialog closes without an answer', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    expect(profile, contains('if (yes == null) return;'));
  });

  testWidgets('both answers are the same size', (tester) async {
    final context = await pump(tester, 'en');
    unawaited(TrackingConsentDialog.show(context));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.widgetWithText(TextButton, 'Allow')), tester.getSize(find.widgetWithText(TextButton, "Don't allow")));
  });
}
