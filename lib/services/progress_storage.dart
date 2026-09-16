import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local progress storage, scoped to the signed-in user (risk #21).
///
/// Progress was written to a single SharedPreferences key, `'progress'`, with
/// no user id in it. Two accounts on one device therefore shared one set of
/// quiz scores, exam results and study progress: sign out, sign in as someone
/// else, and you saw the first person's data.
///
/// This does NOT add cross-device sync. The five progress Cloud Functions the
/// client calls (`getUserProgress`, `updateModuleProgress`,
/// `updateTopicProgress`, `updateQuestionProgress`, `saveTestScore`) have no
/// server-side implementation at all, and `progress/{uid}` is rule-denied.
/// Progress still lives only on the device and is still lost with it.
class ProgressStorage {
  /// The old, unscoped key. Read once per user for migration, then removed.
  static const String legacyKey = 'progress';

  static String keyFor(String? userId) =>
      userId == null || userId.isEmpty ? 'progress_anonymous' : 'progress_$userId';

  static String _currentKey() => keyFor(FirebaseAuth.instance.currentUser?.uid);

  /// Read this user's progress, migrating from the legacy unscoped key once.
  ///
  /// The legacy blob is claimed by whoever signs in first after the upgrade.
  /// That is a guess, but it is the same data they can already see today, and
  /// from then on each account is separate — which is the point.
  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentKey();

    final scoped = prefs.getString(key);
    if (scoped != null) return scoped;

    final legacy = prefs.getString(legacyKey);
    if (legacy == null) return null;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      await prefs.setString(key, legacy);
      await prefs.remove(legacyKey);
      debugPrint('📦 ProgressStorage: migrated legacy progress to $key');
    }
    return legacy;
  }

  static Future<void> write(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey(), json);
  }

  /// Clear only this user's progress — used on account deletion.
  static Future<void> clearForCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey());
  }
}
