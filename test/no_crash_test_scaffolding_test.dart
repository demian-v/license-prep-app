import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Guards against the Crashlytics verification scaffolding being left in.
///
/// On 2026-09-17, testing Crashlytics required a temporary change to
/// `lib/main.dart`: release and profile modes are not supported on the iOS
/// simulator, so the only way to exercise real reporting there was to force
/// collection on in a debug build and deliberately crash the app a few seconds
/// after launch.
///
/// That code must never reach a user. Shipping it would crash the app on every
/// launch, and would send development crashes to production Crashlytics.
///
/// A note in a handoff document is not a good enough safeguard for something
/// with that blast radius — so this fails the build instead.
void main() {
  final mainDart = File('lib/main.dart').readAsStringSync();

  group('no Crashlytics verification scaffolding in lib/', () {
    test('main.dart does not deliberately crash the app', () {
      expect(
        mainDart.contains('FirebaseCrashlytics.instance.crash()'),
        isFalse,
        reason: 'crash() is a deliberate crash — it must never ship',
      );
    });

    test('crash collection is gated on build mode, not forced on', () {
      expect(
        mainDart.contains('final collect = kReleaseMode || kProfileMode'),
        isTrue,
        reason: 'collection must stay off in debug so development crashes do '
            'not reach production Crashlytics',
      );
      expect(
        mainDart.contains('final collect = true'),
        isFalse,
        reason: 'collection was forced on for a test and not reverted',
      );
    });

    test('no leftover test markers', () {
      for (final marker in ['CRASHTEST', 'TEMPORARY — CRASHLYTICS']) {
        expect(mainDart.contains(marker), isFalse, reason: 'left over: $marker');
      }
    });

    test('Crashlytics is still actually wired (positive control)', () {
      // The guards above must not be satisfiable by deleting the feature.
      expect(mainDart.contains('FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled'), isTrue);
      expect(mainDart.contains('FlutterError.onError'), isTrue);
      expect(mainDart.contains('platformDispatcher.onError'), isTrue);
    });
  });
}
