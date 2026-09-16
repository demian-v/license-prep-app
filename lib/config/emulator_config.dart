import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Local development only.
///
/// Off unless the build passes `--dart-define=USE_EMULATOR=true`, and it hard
/// fails in release mode, so a shipped binary can never be pointed at localhost.
const bool kUseEmulator = bool.fromEnvironment('USE_EMULATOR');

/// The project the emulator suite serves. Deliberately `demo-` prefixed:
/// Firebase treats such ids as offline-only, so the SDK cannot reach
/// production even if something else is misconfigured.
const String kEmulatorProjectId = 'demo-driveusa';

/// In emulator mode the app must connect as [kEmulatorProjectId], not the real
/// project. Connecting as `licenseprepapp` makes the Auth emulator reject the
/// session under singleProjectMode, and would put the app in a different,
/// empty Firestore namespace from the seeded content.
FirebaseOptions emulatorAwareOptions(FirebaseOptions real) {
  if (!kUseEmulator) return real;
  return real.copyWith(projectId: kEmulatorProjectId);
}

Future<void> connectToEmulatorsIfEnabled() async {
  if (!kUseEmulator) return;

  if (kReleaseMode) {
    throw StateError(
      'USE_EMULATOR was set in a release build. Local emulator wiring must '
      'never ship. Rebuild without the --dart-define.',
    );
  }

  // The Android emulator reaches the host machine on 10.0.2.2;
  // the iOS simulator shares the host's loopback.
  final host = (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? '10.0.2.2'
      : '127.0.0.1';

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);

  debugPrint(
    '🧪 EMULATOR MODE — $host  firestore:8080 auth:9099 functions:5001 storage:9199',
  );
}
