import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/services/progress_storage.dart';

/// Risk #21 — progress was stored under one unscoped key, so two accounts on
/// one device shared quiz scores, exam results and study progress.
void main() {
  group('Risk #21 — progress keys are per user', () {
    test('two users get different keys', () {
      expect(ProgressStorage.keyFor('user-a'), isNot(ProgressStorage.keyFor('user-b')));
    });

    test('a key always contains the user id', () {
      expect(ProgressStorage.keyFor('user-a'), contains('user-a'));
    });

    test('a signed-out device gets its own key, not the shared one', () {
      expect(ProgressStorage.keyFor(null), 'progress_anonymous');
      expect(ProgressStorage.keyFor(''), 'progress_anonymous');
      // The old unscoped key must never be reused as a scoped one.
      expect(ProgressStorage.keyFor(null), isNot(ProgressStorage.legacyKey));
    });
  });
}
