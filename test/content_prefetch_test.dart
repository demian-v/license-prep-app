import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:license_prep_app/services/content_loading_manager.dart';
import 'package:license_prep_app/providers/content_provider.dart';
import 'package:license_prep_app/providers/language_provider.dart';
import 'package:license_prep_app/providers/state_provider.dart';

/// Content prefetch (2026-09-17).
///
/// Warms the content cache after state selection during signup, and after a
/// state or language change in settings — always in the background, so the user
/// never waits for it.
///
/// Two properties matter and are pinned here:
///   1. a prefetch NEVER throws at its caller, because nobody asked for it and
///      an error from unrequested work is worse than the work not happening;
///   2. the first prefetch switches ON the manager's language/state listeners,
///      which is what makes later changes reload without separate wiring.

/// Implemented rather than extended: ContentProvider's constructor reaches into
/// the ServiceLocator, which a unit test has no business standing up. Only the
/// two members ContentLoadingManager actually calls need real behaviour.
class _FakeContentProvider implements ContentProvider {
  int fetchCount = 0;
  bool shouldFail = false;
  Completer<void>? gate;

  @override
  void setPreferences({String? language, String? state, String? licenseId}) {}

  @override
  Future<void> fetchContentAfterSelection({bool forceRefresh = false}) async {
    fetchCount++;
    if (gate != null) await gate!.future;
    if (shouldFail) throw Exception('network down');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeStateProvider implements StateProvider {
  @override
  Future<String?> getSelectedStateIdSafe() async => 'IL';

  // Real values, not noSuchMethod's null: the manager reads these in its log
  // lines, and a null where a bool is expected throws before any fetch happens.
  @override
  bool get isInitialized => true;

  @override
  String? get selectedStateId => 'IL';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _FakeContentProvider content;
  late LanguageProvider language;
  late _FakeStateProvider state;
  late ContentLoadingManager manager;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    // Reset between tests: the mock store is process-wide, so a language set by
    // one test would otherwise leak into the next.
    SharedPreferences.setMockInitialValues({});
    content = _FakeContentProvider();
    language = LanguageProvider();
    state = _FakeStateProvider();
    manager = ContentLoadingManager(
      contentProvider: content,
      languageProvider: language,
      stateProvider: state,
    );
  });

  tearDown(() => manager.dispose());

  test('a prefetch fetches content', () async {
    manager.prefetchInBackground(entitled: true, reason: 'test');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(content.fetchCount, greaterThan(0));
  });

  test('a prefetch does not block its caller', () async {
    // Hold the fetch open, so "did the caller get control back" is a real
    // question rather than one the speed of the fake answers for us.
    content.gate = Completer<void>();

    manager.prefetchInBackground(entitled: true, reason: 'test');
    // Reaching this line at all means the call did not await the fetch.

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(content.fetchCount, 1, reason: 'the fetch should have started');
    expect(manager.hasInitializedContent, isFalse,
        reason: 'and should still be in flight, not finished');

    content.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(manager.hasInitializedContent, isTrue);
  });

  test('a FAILING prefetch never throws at the caller', () async {
    // The whole point: unrequested background work must not surface an error.
    content.shouldFail = true;
    expect(() => manager.prefetchInBackground(entitled: true, reason: 'test'), returnsNormally);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // And the failure did not leave the manager wedged — another try works.
    content.shouldFail = false;
    manager.prefetchInBackground(entitled: true, reason: 'retry');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(content.fetchCount, greaterThan(1));
  });

  test('the first prefetch switches the change listeners on', () async {
    // Before: the manager ignores changes, which is why nothing reloaded for
    // years — initializeContent was the only thing that set the flag, and
    // nothing called it.
    expect(manager.hasInitializedContent, isFalse);

    manager.prefetchInBackground(entitled: true, reason: 'state selected');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(manager.hasInitializedContent, isTrue);
  });

  test('a later change reloads on its own once initialised', () async {
    manager.prefetchInBackground(entitled: true, reason: 'state selected');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final afterPrefetch = content.fetchCount;

    await language.setLanguage('ru');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(content.fetchCount, greaterThan(afterPrefetch));
  });

  test('a repeat prefetch still refreshes rather than silently doing nothing', () async {
    manager.prefetchInBackground(entitled: true, reason: 'first');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final afterFirst = content.fetchCount;

    manager.prefetchInBackground(entitled: true, reason: 'second');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // initializeContent would have skipped; the reload path must not.
    expect(content.fetchCount, greaterThan(afterFirst));
  });

  test('a prefetch is SKIPPED when the user is known to be unentitled', () async {
    // Every content callable calls requireEntitledUser, so this would be two
    // Cloud Function invocations guaranteed to be refused — on every state or
    // language change, for every unsubscribed user.
    manager.prefetchInBackground(entitled: false, reason: 'unentitled');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(content.fetchCount, 0);
    expect(manager.hasInitializedContent, isFalse);
  });

  test('skipping does not poison later prefetches', () async {
    manager.prefetchInBackground(entitled: false, reason: 'unentitled');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(content.fetchCount, 0);

    // Entitlement arrives (a trial starts, a purchase completes).
    manager.prefetchInBackground(entitled: true, reason: 'now entitled');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(content.fetchCount, 1);
    expect(manager.hasInitializedContent, isTrue);
  });
}
