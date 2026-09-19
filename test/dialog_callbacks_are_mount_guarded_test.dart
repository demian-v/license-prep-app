import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #70 — `setState` after the dialog is gone.
///
/// Found by the FIRST Crashlytics report this app ever delivered, 2026-09-19,
/// on a Galaxy S10 Lite. The stack trace is the whole story:
///
///     Null check operator used on a null value
///         State.setState (framework.dart:1219)
///         _ProfileScreenState._showStateSelector.<fn>.<fn>.<fn>.<fn>
///                                            (profile_screen.dart:1291)
///
/// `framework.dart:1219` is inside Flutter's own `setState`, which ends in
/// `_element!.markNeedsBuild()`. On an unmounted State `_element` is null, so
/// the `!` throws. **The null assertion is Flutter's, not ours** — which is why
/// auditing our own `!` operators found nothing: every one of them in
/// profile_screen.dart was, and remains, correctly guarded.
///
/// Reproduction: change state with no network, then dismiss the dialog by
/// tapping outside while `updateUserState` is still in flight. It fails, the
/// catch runs, and the StatefulBuilder it wants to rebuild is gone.
///
/// The asymmetry is the lesson. The SUCCESS path already had `if (mounted)` on
/// its `setState`; the ERROR path had nothing. Failure paths run in precisely
/// the conditions that tear widgets down — offline, timeout, a user giving up
/// and dismissing — so they need the guard *more*, not less.
///
/// Structural, like `no_hardcoded_question_state_test` (#39): the defect is a
/// missing guard around a specific call, and driving the real dialog to an
/// unmounted state needs six providers and a live Firebase app.
void main() {
  final file = File('lib/screens/profile_screen.dart');
  final lines = file.readAsLinesSync();

  int firstAt(int from, bool Function(String) match) {
    for (var i = from; i < lines.length; i++) {
      if (match(lines[i])) return i;
    }
    return -1;
  }

  /// A guard must be CODE, not prose.
  ///
  /// This matters more than it sounds: the comment in profile_screen.dart that
  /// explains this very bug contains the string `if (mounted)`, and an earlier
  /// version of this test matched it — **the documentation satisfied the check
  /// that was supposed to detect the bug's absence**. That was the fourth false
  /// pass while writing this test, and the reason every claim below was
  /// re-verified by deleting the fix and watching it go red.
  bool isCode(String l) => !l.trim().startsWith('//');
  bool isGuard(String l) =>
      isCode(l) &&
      (l.contains('dialogContext.mounted') || l.contains('if (mounted)'));
  bool isCallback(String l) =>
      isCode(l) &&
      (l.contains('setDialogState(') ||
          l.contains('Navigator.pop(dialogContext'));

  /// Within the region starting at [from], a mount guard must appear BEFORE
  /// the first dialog callback.
  ///
  /// Block-scoped on purpose. Two weaker rules were tried while writing this,
  /// and both were wrong:
  ///
  ///  * proximity by line count **gave a false pass** — with a window wide
  ///    enough to see past an explanatory comment it found the SUCCESS path's
  ///    guard and pronounced the unguarded ERROR path fine, which is exactly
  ///    the bug this test exists to catch;
  ///  * strict adjacency **gave a false failure** — it cannot see that an
  ///    early `return` guard above protects every statement after it.
  ///
  /// Asking "is there a guard before the first callback in this block" has
  /// neither failure mode, and is the rule a reviewer would actually apply.
  void expectGuardedRegion(int from, String what) {
    final callback = firstAt(from, isCallback);
    expect(callback, isNot(-1), reason: 'no dialog callback found in $what');

    // Bounded to [from, callback). An unbounded forward search was tried and
    // **gave a false pass**: it ran past the end of the block and matched an
    // unrelated `if (mounted)` further down the file, so removing the real
    // guard still looked fine. The window has to stop at the callback.
    final guarded = lines
        .sublist(from, callback)
        .any(isGuard);

    expect(
      guarded,
      isTrue,
      reason: 'in $what the first dialog callback is at line ${callback + 1} '
          'with no mount guard between it and the start of the block. '
          'setState on an unmounted StatefulBuilder throws "Null check '
          'operator used on a null value" from inside Flutter '
          '(framework.dart:1219).',
    );
  }

  group('risk #70 — dialog callbacks must be mount-guarded', () {
    test('the state selector ERROR path guards before touching the dialog', () {
      // The DEFINITION, not the first mention. Matching `_showStateSelector`
      // loosely found the CALL SITE ~300 lines earlier, and the search then
      // ran into an unrelated method's catch block that happened to be
      // guarded — **a false pass**, the third this test produced while being
      // written. Each one looked like the code was fine.
      final selector =
          firstAt(0, (l) => l.contains('void _showStateSelector('));
      expect(selector, isNot(-1),
          reason: '_showStateSelector definition not found');
      // `} catch (e` rather than `} catch (e) {` — the block legitimately
      // became `} catch (e, stackTrace) {` when stack capture was added, and
      // the stricter form made this test fail with "catch block not found".
      // Failing loudly there was correct behaviour, not a nuisance: a
      // structural test that cannot locate its target must never quietly pass.
      final catchLine = firstAt(selector, (l) => l.contains('} catch (e'));
      expect(catchLine, isNot(-1),
          reason: 'the state selector catch block could not be located — if it '
              'was renamed or restructured, update this matcher rather than '
              'deleting the test');
      expectGuardedRegion(catchLine, 'the state selector catch block');
    });

    test('every setDialogState has a guard somewhere above it', () {
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('setDialogState(')) continue;
        final guardAbove = lines.sublist(0, i).lastIndexWhere(isGuard);
        expect(guardAbove, isNot(-1),
            reason: 'setDialogState at line ${i + 1} has no guard above it');
      }
    });

    test('positive control — both paths are guarded, not just one', () {
      // #70 existed because the success path was guarded and the failure path
      // was not. If a future edit guards only one again, this count drops.
      final source = file.readAsStringSync();
      expect(
        RegExp(r'dialogContext\.mounted').allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason: 'the success path and the error path each need their own guard',
      );
    });
  });
}
