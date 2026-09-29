import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/models/exam.dart';
import 'package:license_prep_app/models/result_meme.dart';
import 'package:license_prep_app/services/result_meme_service.dart';
import 'package:license_prep_app/widgets/result_meme_picture.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result-page memes (owner, 2026-09-28): the buckets are < 30, 30–59, 60–89
/// and ≥ 90 = passed, plus "out of time" for an Экзамен the timer ended
/// below the pass mark. A pass always gets a win picture.
void main() {
  group('bucketFor — edges', () {
    MemeBucket notPassed(int percent) =>
        ResultMemeService.bucketFor(percent: percent, passed: false);

    test('below 30 is the first bucket', () {
      expect(notPassed(0), MemeBucket.under30);
      expect(notPassed(29), MemeBucket.under30);
    });

    test('30 to 59', () {
      expect(notPassed(30), MemeBucket.from30);
      expect(notPassed(31), MemeBucket.from30);
      expect(notPassed(59), MemeBucket.from30);
    });

    test('60 to 89', () {
      expect(notPassed(60), MemeBucket.from60);
      expect(notPassed(61), MemeBucket.from60);
      expect(notPassed(89), MemeBucket.from60);
    });

    test('a pass is the win bucket: 90, 91, 100', () {
      for (final p in [90, 91, 100]) {
        expect(ResultMemeService.bucketFor(percent: p, passed: true),
            MemeBucket.passed);
      }
    });

    test('90 % or more without a pass never shows a win picture', () {
      expect(notPassed(90), MemeBucket.from60);
      expect(notPassed(100), MemeBucket.from60);
    });

    test('out of time wins over the score, a pass wins over out of time', () {
      expect(
          ResultMemeService.bucketFor(percent: 10, passed: false, outOfTime: true),
          MemeBucket.outOfTime);
      expect(
          ResultMemeService.bucketFor(percent: 80, passed: false, outOfTime: true),
          MemeBucket.outOfTime);
      expect(
          ResultMemeService.bucketFor(percent: 92, passed: true, outOfTime: true),
          MemeBucket.passed);
    });

    test('bucket ids match the Storage folders and the collection field', () {
      expect(MemeBucket.values.map((b) => b.id),
          ['lt30', '30-59', '60-89', '90-100', 'out-of-time']);
    });
  });

  group('ranOutOfTime', () {
    final start = DateTime(2026, 9, 28, 12);
    Exam exam({required int limit, DateTime? completedAt}) => Exam(
          questionIds: const ['q'],
          startTime: start,
          timeLimit: limit,
          isCompleted: completedAt != null,
          completedAt: completedAt,
        );

    test('completed by the timer at the limit', () {
      expect(
          ResultMemeService.ranOutOfTime(
              exam(limit: 60, completedAt: start.add(const Duration(minutes: 60, seconds: 1)))),
          isTrue);
      expect(
          ResultMemeService.ranOutOfTime(
              exam(limit: 60, completedAt: start.add(const Duration(minutes: 60)))),
          isTrue);
    });

    test('finished by the learner before the limit', () {
      expect(
          ResultMemeService.ranOutOfTime(
              exam(limit: 60, completedAt: start.add(const Duration(minutes: 42)))),
          isFalse);
    });

    test('Практика (limit 0) is never out of time', () {
      expect(
          ResultMemeService.ranOutOfTime(
              exam(limit: 0, completedAt: start.add(const Duration(minutes: 5)))),
          isFalse);
    });

    test('not completed is not out of time', () {
      expect(ResultMemeService.ranOutOfTime(exam(limit: 60)), isFalse);
    });
  });

  group('percentOf', () {
    test('rounds down, so 89.9 % stays under the 90 edge', () {
      expect(ResultMemeService.percentOf(36, 40), 90); // the exam pass mark
      expect(ResultMemeService.percentOf(35, 40), 87);
      expect(ResultMemeService.percentOf(14, 15), 93);
      expect(ResultMemeService.percentOf(13, 15), 86);
      expect(ResultMemeService.percentOf(899, 1000), 89);
    });

    test('nothing to count is 0 %, not a division by zero', () {
      expect(ResultMemeService.percentOf(0, 0), 0);
    });
  });

  group('pickUrl', () {
    ResultMeme meme(String id, {bool active = true}) => ResultMeme(
          id: id,
          bucket: 'lt30',
          storagePath: 'result_memes/lt30/$id.webp',
          width: 512,
          height: 384,
          bytes: 20000,
          active: active,
          order: 1,
        );

    setUp(() => SharedPreferences.setMockInitialValues({}));

    ResultMemeService service(
      List<ResultMeme> memes, {
      Future<String?> Function(String)? resolve,
      int seed = 1,
    }) =>
        ResultMemeService(
          loadBucket: (_) async => memes,
          resolveUrl: resolve ?? (p) async => 'https://example.test/$p',
          random: Random(seed),
        );

    test('never shows the same picture twice in a row', () async {
      final s = service([meme('a'), meme('b'), meme('c')]);
      String? last;
      for (var i = 0; i < 30; i++) {
        final url = await s.pickUrl(MemeBucket.under30);
        expect(url, isNotNull);
        expect(url, isNot(last));
        last = url;
      }
    });

    test('remembers the last picture across service instances', () async {
      for (var seed = 0; seed < 10; seed++) {
        SharedPreferences.setMockInitialValues({'result_meme_last_lt30': 'a'});
        final url = await service([meme('a'), meme('b')], seed: seed)
            .pickUrl(MemeBucket.under30);
        expect(url, endsWith('/b.webp'));
      }
    });

    test('a single picture is still shown every time', () async {
      final s = service([meme('only')]);
      expect(await s.pickUrl(MemeBucket.under30), endsWith('/only.webp'));
      expect(await s.pickUrl(MemeBucket.under30), endsWith('/only.webp'));
    });

    test('inactive pictures are never chosen', () async {
      final s = service([meme('off', active: false), meme('on')]);
      for (var i = 0; i < 5; i++) {
        expect(await s.pickUrl(MemeBucket.under30), endsWith('/on.webp'));
      }
    });

    test('an empty collection gives null (the page falls back)', () async {
      expect(await service([]).pickUrl(MemeBucket.under30), isNull);
    });

    test('offline (the query throws) gives null', () async {
      final s = ResultMemeService(
        loadBucket: (_) async => throw Exception('unavailable'),
        resolveUrl: (_) async => 'x',
      );
      expect(await s.pickUrl(MemeBucket.passed), isNull);
    });

    test('a missing Storage file gives null', () async {
      final s = service([meme('a')], resolve: (_) async => null);
      expect(await s.pickUrl(MemeBucket.under30), isNull);
    });
  });

  group('ResultMemePicture — fallback', () {
    const fail = 'assets/images/success_fail/fail.png';

    Future<void> pump(WidgetTester tester, Future<String?> url) =>
        tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 240,
              child: ResultMemePicture(
                url: url,
                fallbackAsset: fail,
                toneSurface: Colors.red.shade50,
              ),
            ),
          ),
        ));

    bool showsAsset(WidgetTester tester, String asset) => tester
        .widgetList<Image>(find.byType(Image))
        .any((i) => i.image is AssetImage && (i.image as AssetImage).assetName == asset);

    testWidgets('no meme to be had shows the bundled picture', (tester) async {
      await pump(tester, Future.value(null));
      await tester.pump();
      expect(showsAsset(tester, fail), isTrue);
    });

    testWidgets('while choosing, the space is held with no spinner',
        (tester) async {
      await pump(tester, Future.delayed(const Duration(seconds: 1), () => null));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byType(ResultMemePicture)), const Size(320, 240));
      await tester.pump(const Duration(seconds: 1));
      expect(showsAsset(tester, fail), isTrue);
    });
  });
}
