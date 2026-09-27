import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// W9 — the duplicate practice screen from the app's Ukrainian previous life.
///
/// This app began as a Ukrainian driving-test app. When the practice flow was
/// rebuilt for DriveUSA the OLD screen was never deleted, so every build still
/// shipped `PracticeTestScreen`, reachable by the `/practice/<id>` route that
/// nothing navigated to. Forced open on a device 2026-09-19 via
/// `driveusa:///practice/driver`, it rendered:
///
///   - a Ukrainian title, "Правила Дорожнього Руху";
///   - hardcoded Ukrainian cards — "Складай іспит", "як в СЦ МВС" (Ukraine's
///     Ministry of Internal Affairs service centre), "Тренуйся по білетах";
///   - and **"Your trial has ended. Subscribe to continue practicing."** on an
///     account with an ACTIVE three-day trial, because it read entitlement with
///     the old logic.
///
/// It also settles W9: that screen used a hardcoded local list, so it never
/// called `getPracticeTests` either. The backend function has **no client
/// caller at all**, and the `practiceTests` index deployed 2026-09-17 protects
/// a query nobody makes.
///
/// Deleted: the screen, its route, its `TestCard` widget (used by nothing else
/// — the live screens use `EnhancedTestCard`) and the hardcoded list.
void main() {
  group('W9 — the legacy practice screen stays deleted', () {
    test('the orphaned screen and its widget are gone', () {
      for (final path in const [
        'lib/screens/practice_test_screen.dart',
        'lib/widgets/test_card.dart',
      ]) {
        expect(File(path).existsSync(), isFalse,
            reason: '$path is legacy from the Ukrainian app and was deleted');
      }
    });

    test('the dead /practice/ route is gone from main.dart', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main.contains("startsWith('/practice/')"), isFalse,
          reason: 'nothing navigated here; it only existed as a way to reach '
              'the deleted screen by deep link');
      expect(main.contains('PracticeTestScreen'), isFalse);
    });

    test('no hardcoded Ukrainian practice data survives', () {
      // The whole legacy data file is gone (owner, 2026-09-26): after the
      // practice cards went, its `licenseTypes` and `theoryModules` were also
      // legacy Ukrainian ('Правила Дорожнього Руху', 'Знаки') whose only
      // reader, `LicenseSelectionScreen`, was deleted as unused. Its model,
      // `LicenseType`, had no other user and went with it.
      for (final path in const [
        'lib/data/license_data.dart',
        'lib/models/license_type.dart',
      ]) {
        expect(File(path).existsSync(), isFalse,
            reason: '$path is legacy from the Ukrainian app and was deleted');
      }
    });

    test('positive control — the LIVE practice flow is untouched', () {
      // The deletion must not have taken the working flow with it. "Practice
      // Tickets" goes to PracticeQuestionScreen, which is a different screen.
      expect(File('lib/screens/practice_question_screen.dart').existsSync(), isTrue);
      final testScreen = File('lib/screens/test_screen.dart').readAsStringSync();
      expect(testScreen.contains('PracticeQuestionScreen'), isTrue,
          reason: 'this is the practice screen users actually reach');
      expect(File('lib/widgets/enhanced_test_card.dart').existsSync(), isTrue,
          reason: 'the live screens use EnhancedTestCard, not the deleted one');
    });
  });
}
