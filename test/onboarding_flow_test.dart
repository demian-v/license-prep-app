import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/screens/onboarding_screen.dart';
import 'package:license_prep_app/widgets/onboarding_shots.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first-run onboarding (owner, 2026-09-29): a greeting card, then six
/// screenshot steps, with «Назад» and «Пропустить». It must never strand the
/// user: Start and Skip both end it, exactly once.
Future<void> pumpOnboarding(
  WidgetTester tester, {
  required VoidCallback onDone,
  bool reduceMotion = true,
  String locale = 'ru',
}) async {
  // An iPhone 16 Pro: the screenshots and layout are made for a phone.
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = MaterialApp(
    locale: Locale(locale),
    // As in the app (main.dart): Material and Cupertino strings for ru too.
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale(locale)],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: OnboardingScreen(key: UniqueKey(), onDone: onDone),
      ),
    ),
  );
  // The localization delegate does real async asset I/O that pump does not wait for.
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();
  await tester.pump();
}

Future<void> settle(WidgetTester tester, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('onboarding flow', () {
    testWidgets('greeting first, with no Back', (tester) async {
      await pumpOnboarding(tester, onDone: () {});
      expect(find.text('Добро пожаловать в DriveUSA'), findsOneWidget);
      expect(find.text('Привет!'), findsOneWidget);
      expect(find.text('Начнём'), findsOneWidget);
      final back = tester.widget<AnimatedOpacity>(
        find.ancestor(of: find.byTooltip('Назад'), matching: find.byType(AnimatedOpacity)).first,
      );
      expect(back.opacity, 0, reason: 'nothing to go back to on the greeting');
    });

    testWidgets('Next walks the steps, Back returns, Start ends it once', (tester) async {
      var done = 0;
      await pumpOnboarding(tester, onDone: () => done++);

      await tester.tap(find.text('Начнём'));
      await settle(tester);
      expect(find.text('Здесь всё для подготовки к письменному экзамену.'), findsOneWidget);

      await tester.tap(find.byTooltip('Назад'));
      await settle(tester);
      expect(find.text('Добро пожаловать в DriveUSA'), findsOneWidget);

      await tester.tap(find.text('Начнём'));
      await settle(tester);
      for (final body in [
        'Симуляция настоящего экзамена: 40 вопросов, 60 минут.',
        'Учите вопросы по темам или решайте практические билеты.',
        'Вопросы, в которых вы ошиблись, собираются здесь.',
        'Справочник водителя вашего штата, разбитый на модули.',
        'Найдите автошколу или инструктора рядом. Входит в платную подписку.',
        'Меняйте язык и штат в любой момент.',
      ]) {
        await tester.tap(find.byTooltip('Далее').first);
        await settle(tester);
        expect(find.text(body), findsOneWidget);
      }

      expect(find.text('Начать'), findsOneWidget, reason: 'the last step offers Start');
      await tester.tap(find.text('Начать'));
      await settle(tester, 2000);
      expect(done, 1);

      await tester.tap(find.text('Начать'), warnIfMissed: false);
      await settle(tester, 2000);
      expect(done, 1, reason: 'Start must not end the onboarding twice');
    });

    testWidgets('Skip ends it from the greeting and from a step', (tester) async {
      var done = 0;
      await pumpOnboarding(tester, onDone: () => done++);
      await tester.tap(find.text('Пропустить'));
      await settle(tester);
      expect(done, 1);

      done = 0;
      await pumpOnboarding(tester, onDone: () => done++);
      await tester.tap(find.text('Начнём'));
      await settle(tester);
      await tester.tap(find.text('Пропустить'));
      await settle(tester, 2000);
      expect(done, 1);
    });

    testWidgets('with full motion it plays through without errors', (tester) async {
      var done = 0;
      await pumpOnboarding(tester, onDone: () => done++, reduceMotion: false);
      await settle(tester, 2000);
      await tester.tap(find.text('Начнём'));
      await settle(tester, 1500);
      for (var i = 0; i < 6; i++) {
        await tester.tap(find.byTooltip('Далее').first);
        await settle(tester, 1200);
      }
      await tester.tap(find.text('Начать'));
      await settle(tester, 2500);
      expect(done, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('onboarding in every language', () {
    for (final loc in ['en', 'es', 'pl', 'ru', 'uk']) {
      testWidgets('$loc: its own greeting and its own screenshots', (tester) async {
        final strings = Map<String, dynamic>.from(
            jsonDecode(File('lib/localization/l10n/$loc.json').readAsStringSync()) as Map);
        await pumpOnboarding(tester, onDone: () {}, locale: loc);
        expect(find.text(strings['onboarding_hello'] as String), findsOneWidget);

        await tester.tap(find.text(strings['onboarding_lets_go'] as String));
        await settle(tester);
        final shots = tester
            .widgetList<Image>(find.byType(Image))
            .map((i) => i.image)
            .whereType<AssetImage>()
            .map((a) => a.assetName)
            .toSet();
        expect(shots, contains('assets/images/onboarding/$loc/tests.webp'));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('onboarding gate', () {
    test('shows until seen, then not again', () async {
      expect(await OnboardingGate.shouldShow(), isTrue);
      await OnboardingGate.markSeen();
      expect(await OnboardingGate.shouldShow(), isFalse);
    });
  });

  group('onboarding screenshots', () {
    const keys = [
      'tests.tab', 'tests.hero', 'tests.tiles', 'tests.mistakes',
      'theory.tab', 'theory.module', 'instructors.tab', 'instructors.card',
      'profile.tab', 'profile.settings',
    ];

    test('every screenshot locale has every rect, inside the screenshot', () {
      final bounds = Offset.zero & onboardingShotSize;
      for (final loc in onboardingShotLocales) {
        for (final key in keys) {
          final r = onboardingShotRects[loc]?[key];
          expect(r, isNotNull, reason: '$loc is missing $key');
          expect(bounds.intersect(r!), r, reason: '$loc $key is outside the screenshot');
        }
      }
    });

    test('every screenshot locale has its images and a pubspec entry', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final loc in onboardingShotLocales) {
        expect(pubspec, contains('- assets/images/onboarding/$loc/'),
            reason: 'Flutter does not bundle subfolders on its own');
        for (final screen in ['tests', 'theory', 'instructors', 'profile']) {
          expect(File('assets/images/onboarding/$loc/$screen.webp').existsSync(), isTrue,
              reason: '$loc/$screen.webp is missing');
        }
      }
    });
  });
}
