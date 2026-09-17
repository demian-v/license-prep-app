import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #39 — questions must be fetched for the user's state, not Illinois.
///
/// This exists because the row was fixed once and stayed broken. Commit
/// `7fa9a6c` replaced a hardcoded `'IL'` inside `ExamProvider` and
/// `PracticeProvider` with their `state` parameter, and the register recorded
/// #39 as DONE. But the two call sites in `test_screen.dart` went on passing
/// the literal `'IL'` **into** that parameter, so a New York user still got
/// Illinois exam and practice questions. The literal moved one layer up
/// instead of going away — the same shape as the #3 follow-up, where fixing
/// only the inner catch changed nothing because an outer one caught it again.
///
/// A structural guard rather than a widget test: the defect is a constant in
/// the source, so the source is the right thing to assert on, and driving
/// `TestScreen` would need six providers and a Firebase app to prove one
/// argument. The live behaviour is verified on the simulator instead.
void main() {
  /// Screens that START a content fetch. Each of these passes a state into a
  /// provider that forwards it to `getQuizQuestions`.
  const screens = [
    'lib/screens/test_screen.dart',
    'lib/screens/theory_screen.dart',
    'lib/screens/quiz_question_screen.dart',
    'lib/screens/topic_quiz_screen.dart',
    'lib/screens/practice_test_screen.dart',
  ];

  group('risk #39 — no hardcoded state on a content request', () {
    for (final path in screens) {
      test('$path passes no literal state', () {
        final file = File(path);
        if (!file.existsSync()) {
          markTestSkipped('$path does not exist');
          return;
        }

        final source = file.readAsStringSync();

        // `state: 'IL'` is the exact form the defect took, in both call sites
        // and in the comment that justified it ("to match Firebase data
        // structure") — which the topic query one line above disproved.
        //
        // `?? 'IL'` is deliberately allowed: that is the last-resort fallback
        // when neither the account nor the picker knows a state, and it has to
        // be something.
        final literals = RegExp(r"""state:\s*(['"])(IL|NY)\1""")
            .allMatches(source)
            .map((m) => m.group(0))
            .toList();

        expect(
          literals,
          isEmpty,
          reason: 'a state literal here overrides the user\'s own selection — '
              'resolve it from AuthProvider/StateProvider instead. Found: '
              '${literals.join(', ')}',
        );
      });
    }

    test('test_screen resolves the state it requests (positive control)', () {
      // The guard above must not be satisfiable by removing the argument
      // altogether, which would silently fall back to ExamProvider's
      // `state = 'all'` default.
      final source = File('lib/screens/test_screen.dart').readAsStringSync();

      expect(source.contains('String _questionState()'), isTrue);
      expect(
        source.contains("authProvider.user?.state ?? stateProvider.selectedState?.id"),
        isTrue,
        reason: 'must mirror _logExamStartedAnalytics, or the analytics event '
            'and the actual request can disagree about which state was used — '
            'which is how this defect survived being reported as fixed',
      );
      expect(
        RegExp(r'state:\s*_questionState\(\)').allMatches(source).length,
        2,
        reason: 'both the exam and the practice call sites',
      );
    });
  });
}
