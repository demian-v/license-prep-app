import 'package:shared_preferences/shared_preferences.dart';
import 'content_cache_policy.dart';
import 'service_locator.dart';

/// Risk #47 — pulls the server's content version and drops cached content when
/// it has changed.
///
/// Without this, a corrected answer reaches a device only when its cache
/// expires — up to [ContentCachePolicy.ttl] later, per device, with no way to
/// hurry it. Bumping `contentMeta/current.version` server-side now makes every
/// device refetch on its next launch.
///
/// Failure is deliberately silent and non-blocking: if the version cannot be
/// read, cached content is kept and the app carries on. A cache-bust check that
/// could break content loading would be a worse bug than the one it fixes.
class ContentVersionService {
  static const String prefsKey = 'content_version';
  static const String functionName = 'getContentVersion';

  /// Fetch the server version and clear content caches if it differs from the
  /// one stored on this device. Returns the version now stored, or null if the
  /// check could not be completed.
  Future<int?> syncAndInvalidateIfChanged() async {
    final int serverVersion;
    try {
      final response = await serviceLocator.firebaseFunctionsClient
          .callFunction<Map<String, dynamic>>(functionName);
      final raw = response['version'];
      if (raw is! num) {
        print('⚠️ Content version: malformed response, keeping cache');
        return null;
      }
      serverVersion = raw.toInt();
    } catch (e) {
      // Offline, signed out, or the callable is not deployed yet. Keep what we
      // have — stale content beats no content.
      print('⚠️ Content version check failed, keeping cache: $e');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getInt(prefsKey);

    if (ContentCachePolicy.shouldInvalidate(cached: cached, server: serverVersion)) {
      print('🔄 Content version $cached → $serverVersion, dropping cached content');
      await serviceLocator.theoryCache.clearAllCaches();
      await serviceLocator.quizCache.clearAllQuizCaches();
    }

    await prefs.setInt(prefsKey, serverVersion);
    return serverVersion;
  }
}
