import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/data/state_data.dart';
import 'package:license_prep_app/data/state_learner_rules.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/widgets/state_requirements_card.dart';

/// «Что требует ваш штат» (instructors plan v2 §14.4): every released state
/// has learner rules, and the card renders them in every language with no
/// template placeholder left behind.
void main() {
  test('every released state has learner rules', () {
    expect(stateLearnerRules.keys.toSet(), StateData.releasedStateIds);
  });

  for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
    testWidgets('the card fills every template in $locale', (tester) async {
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
          home: Scaffold(
            // A Column, not a ListView: every state's card must be built.
            body: SingleChildScrollView(
              child: Column(children: [
                for (final id in stateLearnerRules.keys) StateRequirementsCard(stateId: id),
              ]),
            ),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      expect(find.byType(StateRequirementsCard), findsNWidgets(stateLearnerRules.length));
      expect(texts.where((t) => t.contains('{') || t.startsWith('sreq_')), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
