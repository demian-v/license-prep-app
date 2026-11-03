import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/providers/exam_timer_provider.dart';
import 'package:license_prep_app/widgets/animated_exam_timer.dart';
import 'package:provider/provider.dart';

/// VoiceOver reads this label, and it was Russian in every language
/// (iOS Simulator, 2026-11-02).
void main() {
  const labels = {
    'en': '59 min 30 sec',
    'es': '59 min 30 s',
    'pl': '59 min 30 s',
    'ru': '59 мин 30 сек',
    'uk': '59 хв 30 с',
  };

  for (final locale in labels.keys) {
    testWidgets('$locale: the timer is read in that language', (tester) async {
      final semantics = tester.ensureSemantics();
      final timer = ExamTimerProvider()
        ..updateRemainingTime(const Duration(minutes: 59, seconds: 30));

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
          home: ChangeNotifierProvider.value(
            value: timer,
            child: const Scaffold(body: AnimatedExamTimer()),
          ),
        ));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump();

      final label = tester.getSemantics(find.byType(AnimatedExamTimer)).label;
      expect(label, startsWith(labels[locale]!));
      semantics.dispose();
    });
  }
}
