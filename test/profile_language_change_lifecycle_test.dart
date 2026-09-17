import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Guards the language-change handler in `profile_screen.dart` against the
/// three-part defect found by hand on the iOS simulator on 2026-09-17.
///
/// **What was wrong.** `await provider.setLanguage(code)` changes
/// `MaterialApp.locale` synchronously, which rebuilds the whole tree.
/// `HomeScreen` rebuilds its `_screens` list, so `_ProfileScreenState` is
/// deactivated before the await returns. Everything after it that touched
/// `context` then threw, in three escalating ways as each was fixed:
///
/// 1. `_prefetchEntitled` reads `Provider.of(context)` →
///    *"This widget has been unmounted"*. Thrown while evaluating an argument,
///    so `prefetchInBackground` was never called at all: **the content
///    prefetch after a language change never ran**, which is half of what the
///    feature exists for. The `language_changed` analytics event and the
///    success `Navigator.pop` were skipped too, so every language change was
///    recorded as `language_change_failed` while actually succeeding.
/// 2. `Navigator.pop(context, ...)` →
///    *"Looking up a deactivated widget's ancestor is unsafe"*, once in the
///    try and again in the catch, where nothing catches it.
/// 3. The pop resolved but ran mid-rebuild → `!_debugLocked` assertion.
///
/// **Why the state handler was fine** and this one was not: changing the state
/// does not change the locale, so that State survives its awaits. That
/// asymmetry is why the state half of the prefetch was observed working and
/// the language half was not — and why "it works for state" was not evidence.
///
/// A structural test because the defect is an ORDERING one in the source, and
/// because reproducing it needs a real locale change through a real
/// `MaterialApp` with six providers — which is what the manual simulator run
/// did. The live behaviour was verified there: before, zero
/// `getTheoryModules`; after, one, with no exception of any kind.
void main() {
  final source = File('lib/screens/profile_screen.dart').readAsStringSync();

  /// Comment lines stripped, so the prose explaining the defect cannot
  /// satisfy — or, as happened when this test was written, fail — a check
  /// meant to be about the code.
  String stripComments(String dart) => dart
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  /// The handler runs from `_buildLanguageOption` to the next method.
  String languageHandler() {
    final start = source.indexOf('Widget _buildLanguageOption(');
    expect(start, greaterThan(-1), reason: '_buildLanguageOption not found');
    final end = source.indexOf('void _showStateSelector(', start);
    expect(end, greaterThan(start), reason: 'could not bound the handler');
    return stripComments(source.substring(start, end));
  }

  group('profile language change survives the locale rebuild', () {
    test('entitlement is read BEFORE setLanguage, not after', () {
      final handler = languageHandler();
      final capture = handler.indexOf('_prefetchEntitled');
      final setLanguage = handler.indexOf('setLanguage(code)');

      expect(capture, greaterThan(-1));
      expect(setLanguage, greaterThan(-1));
      expect(
        capture,
        lessThan(setLanguage),
        reason: 'reading _prefetchEntitled after setLanguage touches a '
            'deactivated State.context and throws, which silently skips the '
            'prefetch entirely',
      );
    });

    test('the prefetch is passed the captured value, not a fresh read', () {
      final handler = languageHandler();
      expect(
        handler.contains('entitled: wasEntitled'),
        isTrue,
        reason: 'passing `entitled: _prefetchEntitled` evaluates it at call '
            'time, which is after the rebuild — the whole defect',
      );
    });

    test('the navigator is resolved before the awaits', () {
      final handler = languageHandler();
      final capture = handler.indexOf('Navigator.of(context)');
      final setLanguage = handler.indexOf('setLanguage(code)');

      expect(capture, greaterThan(-1),
          reason: 'a NavigatorState survives the rebuild; the element used to '
              'look it up does not');
      expect(capture, lessThan(setLanguage));
    });

    test('no pop goes through context after the language changes', () {
      final handler = languageHandler();
      expect(
        handler.contains('Navigator.pop(context'),
        isFalse,
        reason: 'looks up an ancestor through a deactivated element',
      );
    });

    test('the pop waits for the frame the rebuild is in', () {
      final handler = languageHandler();
      expect(
        handler.contains('addPostFrameCallback'),
        isTrue,
        reason: 'popping while the Navigator is locked mid-build trips its '
            'own !_debugLocked assertion',
      );
      expect(
        handler.contains('navigator.mounted'),
        isTrue,
        reason: 'the frame callback can outlive the route',
      );
    });

    test('the state handler still prefetches (positive control)', () {
      // These guards must not be satisfiable by removing the prefetch.
      final start = source.indexOf('void _showStateSelector(');
      final stateHandler = stripComments(source.substring(start));
      expect(
        stateHandler.contains("reason: 'state changed in settings'"),
        isTrue,
      );
      expect(
        languageHandler().contains("reason: 'language changed in settings'"),
        isTrue,
      );
    });
  });
}
