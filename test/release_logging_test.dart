import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/utils/release_logging.dart';

/// Risk #34 — `print` and `debugPrint` are NOT stripped from a Flutter release
/// build, and about 122 of this app's log lines interpolate a user id, an email
/// or a report id, so they reach the device log on a shipped build.
///
/// These tests drive the suppression with an explicit `isRelease` flag rather
/// than `kReleaseMode`, because the test runner itself is a debug build and
/// could never exercise the release branch otherwise.

/// Runs [body] and returns everything it printed to the surrounding zone.
List<String> capturePrints(void Function() body) {
  final captured = <String>[];
  runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, String line) => captured.add(line),
    ),
  );
  return captured;
}

void main() {
  group('Risk #34 — print suppression in release builds', () {
    test('a release build drops print output', () {
      final escaped = capturePrints(() {
        runWithReleaseLogging(
          () => print('user id abc123 and email nobody@example.com'),
          isRelease: true,
        );
      });

      expect(escaped, isEmpty);
    });

    test('a debug build still prints (positive control)', () {
      final escaped = capturePrints(() {
        runWithReleaseLogging(
          () => print('diagnostic line'),
          isRelease: false,
        );
      });

      expect(escaped, contains('diagnostic line'));
    });

    test('suppression covers startup, not just the first frame', () {
      // The whole callback runs inside the suppressing zone, so lines logged
      // before runApp are covered too — several PII-bearing ones are.
      final escaped = capturePrints(() {
        runWithReleaseLogging(
          () {
            print('startup: applying language for user 42');
            print('startup: session check for user 42');
          },
          isRelease: true,
        );
      });

      expect(escaped, isEmpty);
    });

    test('the returned value is passed through', () {
      final result = runWithReleaseLogging(() => 7, isRelease: true);
      expect(result, 7);
    });
  });

  group('Risk #34 — debugPrint suppression in release builds', () {
    final original = debugPrint;
    tearDown(() => debugPrint = original);

    test('a release build silences debugPrint', () {
      final seen = <String?>[];
      debugPrint = (String? message, {int? wrapWidth}) => seen.add(message);

      silenceDebugPrintInRelease(isRelease: true);
      debugPrint('session for user 42');

      expect(seen, isEmpty);
    });

    test('a debug build leaves debugPrint alone (positive control)', () {
      final seen = <String?>[];
      debugPrint = (String? message, {int? wrapWidth}) => seen.add(message);

      silenceDebugPrintInRelease(isRelease: false);
      debugPrint('session for user 42');

      expect(seen, contains('session for user 42'));
    });
  });

  group('Risk #34 — the zone specification itself', () {
    test('is null in a debug build, so nothing is intercepted', () {
      expect(logSuppressionSpec(isRelease: false), isNull);
    });

    test('exists in a release build', () {
      expect(logSuppressionSpec(isRelease: true), isNotNull);
    });
  });
}
