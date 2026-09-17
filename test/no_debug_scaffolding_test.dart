import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #51 — debug and example scaffolding living in `lib/`, plus an analytics
/// helper pointed at a package id that does not exist.
///
/// One correction to the register while fixing it: these files did **not** ship
/// in the binary. Dart compiles from `main.dart`'s import graph and none of them
/// was imported anywhere, so nothing reached the built app. Verified against the
/// compiled kernel: `FirebaseDebugTestWidget`, `ApiSwitcherExample` and
/// `QuizCacheIntegrationExample` each appeared 0 times, while a reachable widget
/// appeared 6 times as a control.
///
/// The real cost was in the repo, not the binary: five files that read as live
/// code, get analysed on every run, break when the APIs they call drift, and
/// turn up in greps for callers.
void main() {
  group('Risk #51 — no debug scaffolding in lib/', () {
    test('lib/test_firebase_debug.dart is gone', () {
      expect(File('lib/test_firebase_debug.dart').existsSync(), isFalse);
    });

    test('lib/examples/ is gone', () {
      expect(Directory('lib/examples').existsSync(), isFalse);
    });

    test('lib/ still holds the real app (positive control)', () {
      // Without this, deleting lib/ wholesale would pass the two tests above.
      expect(File('lib/main.dart').existsSync(), isTrue);
      expect(Directory('lib/screens').existsSync(), isTrue);
    });
  });

  group('Risk #51 — the analytics debug helper targets the real app', () {
    late String script;

    setUpAll(() {
      script = File('enable_firebase_debug.bat').readAsStringSync();
    });

    test('does not mention the Flutter template package id', () {
      // `com.example.license_prep_app` is the id `flutter create` generates.
      // adb accepted the setprop silently, so the helper appeared to work and
      // DebugView stayed empty — the worst kind of diagnostic.
      expect(script.contains('com.example.license_prep_app'), isFalse);
    });

    test('uses the shipped application id', () {
      // Matches android/app/build.gradle applicationId and the iOS bundle id.
      expect(script.contains('com.driveusa.app'), isTrue);
    });
  });
}
