/// Risk #47 — one place that decides when cached content is stale.
///
/// Before this, four numbers disagreed: `ContentProvider` used 2 h by default
/// and 6 h for modules, while `TheoryCacheService` and `QuizCacheService` each
/// used 24 h on disk. Whichever expired first won, so the effective policy was
/// whichever constant you happened to read.
///
/// The TTL is the slow path. The fast path is [shouldInvalidate]: when content
/// is corrected server-side the version is bumped, and every device drops its
/// cache on next launch instead of waiting out the clock. That is what makes a
/// long TTL safe — a wrong answer no longer has to expire out.
class ContentCachePolicy {
  const ContentCachePolicy._();

  /// How long cached content stays fresh, everywhere.
  ///
  /// 24 h rather than the old 2 h: content changes rarely, refetching is a
  /// billed Firestore read on every launch, and an urgent correction now
  /// travels by version bump rather than by expiry.
  static const Duration ttl = Duration(hours: 24);

  // Named aliases so each call site reads clearly. They are the same value on
  // purpose, and a test asserts that — if these ever need to differ, that is a
  // deliberate decision someone has to make by changing the test first.
  static const Duration theoryTtl = ttl;
  static const Duration quizTtl = ttl;
  static const Duration inMemoryTtl = ttl;

  /// Whether content cached at [cachedAt] is still fresh.
  ///
  /// A timestamp in the future is treated as stale rather than as infinitely
  /// fresh. Device clocks move — daylight saving, a manual change, a bad NTP
  /// sync — and the old `now.difference(cachedAt) < ttl` form read a future
  /// timestamp as fresh forever, pinning that device to stale content.
  static bool isFresh(DateTime cachedAt, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final age = moment.difference(cachedAt);
    if (age.isNegative) return false;
    return age < ttl;
  }

  /// Whether a version change means the cached content must be dropped.
  ///
  /// Any difference triggers it, not just a higher number: if content is rolled
  /// back, the devices holding the withdrawn version are exactly the ones that
  /// need to refetch.
  ///
  /// [cached] is null on first run — nothing has been stored yet, so there is
  /// nothing to invalidate.
  static bool shouldInvalidate({required int? cached, required int server}) {
    if (cached == null) return false;
    return cached != server;
  }
}
