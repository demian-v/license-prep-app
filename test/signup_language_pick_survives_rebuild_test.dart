import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #77 — the signup language screen reverted every non-English pick.
///
/// **What was wrong** (found on the iOS simulator, 2026-09-26). `MaterialApp`
/// is keyed by language (`main.dart`), so `setLanguage(code)` rebuilds the
/// whole app and this screen is built again from `home` while the pick is
/// still being saved. The new copy's `initState` ran `_verifyUserDefaults`,
/// saw the new language, called it a bad default and wrote English back. The
/// old copy was unmounted, so `if (context.mounted)` skipped the navigation to
/// state selection. Only English — no language change, no rebuild — ever got
/// through. A failed save also left the loading overlay up for good.
///
/// Structural, like `profile_language_change_lifecycle_test.dart`, because the
/// defect is an ordering one in the source and reproducing it needs a real
/// re-keyed `MaterialApp` with six providers — which the simulator run did.
void main() {
  final source =
      File('lib/screens/language_selection_screen.dart').readAsStringSync();

  /// Comment lines stripped, so the prose cannot satisfy a check on the code.
  String stripComments(String dart) => dart
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  String between(String from, String to) {
    final start = source.indexOf(from);
    expect(start, greaterThan(-1), reason: '$from not found');
    final end = source.indexOf(to, start);
    expect(end, greaterThan(start), reason: 'could not bound $from');
    return stripComments(source.substring(start, end));
  }

  String initState() => between('void initState()', 'void _onPickInProgressChanged(');
  String pickHandler() => between('Widget _buildLanguageButton(', '\n}\n');

  group('a signup language pick survives the app rebuild it causes', () {
    test('the pick is recorded outside the State, before setLanguage', () {
      final handler = pickHandler();
      final record = handler.indexOf('_pickInProgress.value = language');
      final setLanguage = handler.indexOf('setLanguage(code)');
      expect(record, greaterThan(-1),
          reason: 'a copy built by the rebuild has no other way to know');
      expect(setLanguage, greaterThan(-1));
      expect(record, lessThan(setLanguage));
      expect(source.contains('static final ValueNotifier<String?> _pickInProgress'),
          isTrue,
          reason: 'State fields die with the old copy; a static survives');
    });

    test('a copy built mid-pick does not reset the defaults', () {
      final init = initState();
      final check = init.indexOf('_pickInProgress.value');
      final bail = init.indexOf('return;', check);
      final verify = init.indexOf('_verifyUserDefaults(context)');
      expect(check, greaterThan(-1));
      expect(verify, greaterThan(-1),
          reason: 'positive control: a fresh screen still checks defaults');
      expect(bail, greaterThan(check));
      expect(bail, lessThan(verify),
          reason: 'running the check mid-pick writes English back — the bug');
    });

    test('a copy built mid-pick does not log a second "started" event', () {
      final init = initState();
      expect(init.indexOf('return;'),
          lessThan(init.indexOf('logLanguageSelectionStarted')));
    });

    test('navigation goes through the live navigator, not this context', () {
      final handler = pickHandler();
      expect(handler.contains('navigatorKey.currentState'), isTrue);
      expect(handler.contains('Navigator.of(context)'), isFalse,
          reason: 'this context belongs to the app the rebuild threw away');
    });

    test('AuthProvider is read before the language changes', () {
      final handler = pickHandler();
      expect(
        handler.indexOf('Provider.of<AuthProvider>(context'),
        lessThan(handler.indexOf('setLanguage(code)')),
        reason: 'a lookup through an unmounted context throws',
      );
    });

    test('a failure clears the overlay and the pick', () {
      final handler = pickHandler();
      final catchBlock = handler.substring(handler.indexOf('} catch (e) {'));
      expect(catchBlock.contains('_isLoading = false'), isTrue,
          reason: 'the overlay used to stay up for good');
      expect(catchBlock.contains('finally'), isTrue);
      expect(
        catchBlock.substring(catchBlock.indexOf('finally')).contains('_pickInProgress.value = null'),
        isTrue,
      );
      expect(catchBlock.contains('ScaffoldMessenger.of(context)'), isFalse,
          reason: 'this context may be unmounted by then');
    });
  });
}
