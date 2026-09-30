import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Changing the state in Профиль always ended in "Error changing state",
/// although the server had saved it (found 2026-09-29).
///
/// The tap handler sets `_isDialogLoading`, so the «Обновление штата…» spinner
/// replaces the list at once and the tapped row is removed. `context` in the
/// handler is that row's (the list's `itemBuilder` parameter), so a
/// `Provider.of(context)` after `await authProvider.updateUserState(...)` looked
/// up a deactivated element and threw. The catch turned it into the error
/// snackbar, and StateProvider never took the new state.
///
/// Structural, like `dialog_callbacks_are_mount_guarded_test` (#70): driving the
/// real dialog needs six providers and a live Firebase app.
void main() {
  final lines = File('lib/screens/profile_screen.dart').readAsLinesSync();

  int firstAt(int from, bool Function(String) match) {
    for (var i = from; i < lines.length; i++) {
      if (match(lines[i])) return i;
    }
    return -1;
  }

  bool isCode(String line) => !line.trimLeft().startsWith('//');

  final start = firstAt(0, (l) => l.contains('void _showStateSelector('));
  final end = firstAt(start + 1, (l) => l == '  }');
  final save = firstAt(start, (l) => isCode(l) && l.contains('await authProvider.updateUserState('));
  // The dialog's result handler: past it, `context` is the screen's again
  // (checked with `mounted`), not the row's.
  final dialogEnd = firstAt(save, (l) => l.contains(').then((result) {'));

  test('the state picker handler is where the test expects it', () {
    expect(start, greaterThan(-1), reason: '_showStateSelector not found');
    expect(save, allOf(greaterThan(start), lessThan(end)),
        reason: 'the updateUserState await is not inside _showStateSelector');
  });

  test('StateProvider is looked up from the screen, before the await', () {
    final lookup = firstAt(start, (l) => isCode(l) && l.contains('Provider.of<StateProvider>('));
    expect(lookup, allOf(greaterThan(start), lessThan(save)),
        reason: 'look StateProvider up BEFORE awaiting updateUserState: after it, '
            'the tapped row has been replaced by the spinner');
    expect(lines[lookup], contains('Provider.of<StateProvider>(this.context'),
        reason: "the handler's own `context` is the row's; use the screen's");
  });

  test('nothing after the await looks up through the row context', () {
    expect(dialogEnd, allOf(greaterThan(save), lessThan(end)));
    for (var i = save + 1; i < dialogEnd; i++) {
      final l = lines[i];
      if (!isCode(l)) continue;
      expect(RegExp(r'\.of(<[^>]*>)?\(context[,)]').hasMatch(l), isFalse,
          reason: 'profile_screen.dart:${i + 1} looks up through `context` after the '
              'await, when that row is already gone: $l');
    }
  });
}
