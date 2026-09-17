import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #46 — orphaned anonymous Auth users accumulate forever.
///
/// `main()` signed in anonymously whenever nobody was logged in, and signup
/// used `createUserWithEmailAndPassword` rather than `linkWithCredential`, so
/// the anonymous account was abandoned rather than upgraded. Measured on the
/// emulator before the fix: a fresh install plus one signup left two Auth
/// users, one of them a permanent orphan. Every logout-then-signup repeats it.
///
/// The anonymous session also stopped being useful once risk #3 landed. Content
/// callables and Firestore rules both require `isNotAnonymous()`, so an
/// anonymous caller can read nothing — the account exists only to be refused,
/// while still counting towards the Auth user total.
///
/// Asserting absence rather than behaviour is deliberate: a sign-in that cannot
/// happen cannot be reintroduced by a well-meaning "fix" for a permission error.
void main() {
  group('Risk #46 — nothing signs in anonymously', () {
    late List<File> dartFiles;

    setUpAll(() {
      dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    });

    test('lib/ contains no signInAnonymously call', () {
      final offenders = <String>[];
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        for (final line in source.split('\n')) {
          // Skip the comments that explain why this is gone.
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (line.contains('signInAnonymously')) {
            offenders.add(file.path);
            break;
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'Anonymous sign-in creates an Auth user that every rule and '
              'callable refuses. Found in: ${offenders.join(', ')}');
    });

    test('the scan actually reads the source (positive control)', () {
      // Without this, a broken glob would make the test above pass by finding
      // no files at all.
      expect(dartFiles.length, greaterThan(50));
      final anyAuthUse = dartFiles.any(
          (f) => f.readAsStringSync().contains('FirebaseAuth.instance'));
      expect(anyAuthUse, isTrue);
    });
  });
}
