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

/// The emulator suite serves the app's REAL project id.
///
/// A `demo-` project id would be a stronger guarantee — Firebase treats those
/// as offline-only — but it cannot work for this iOS client. `FirebaseOptions`
/// carries one project's apiKey/appId/senderId as a matched set; overriding
/// only `projectId` leaves the real API key in place, so Firebase Installations
/// calls `projects/demo-*/installations` with a key that does not belong to it,
/// fails, and takes Auth and Firestore down with it. Making it work would mean
/// shipping a second GoogleService-Info.plist and build scheme for local runs.
///
/// What actually protects production here:
///   1. every Firebase service below is explicitly repointed at 127.0.0.1;
///   2. [kUseEmulator] is off by default and throws in release mode;
///   3. scripts refuse to run unless FIRESTORE_EMULATOR_HOST is set, which
///      overrides the target regardless of project id.
FirebaseOptions emulatorAwareOptions(FirebaseOptions real) => real;

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

  final settings = FirebaseFirestore.instance.settings;
  debugPrint('🧪 Firestore settings -> host=${settings.host} ssl=${settings.sslEnabled}');

  try {
    final probe = await FirebaseFirestore.instance
        .collection('subscriptionsType')
        .limit(1)
        .get();
    debugPrint('🧪 Emulator probe OK — subscriptionsType returned ${probe.docs.length} doc(s)');
  } catch (e) {
    debugPrint('🧪 Emulator probe FAILED — $e');
  }
}
