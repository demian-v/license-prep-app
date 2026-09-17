import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/services/content_cache_policy.dart';

/// Risk #47 — two halves of one row.
///
/// 1. The in-memory and on-disk caches disagreed on how long content stays
///    fresh: 2 h in `ContentProvider`, 24 h in both cache services, plus a 6 h
///    special case for modules. Whichever expired first decided, so the stated
///    policy was whichever number you happened to read.
/// 2. Nothing could force a refetch. A wrong answer expired out rather than
///    being pushed out.
void main() {
  group('Risk #47 — one TTL, not four', () {
    test('every content cache uses the same duration', () {
      expect(ContentCachePolicy.theoryTtl, ContentCachePolicy.ttl);
      expect(ContentCachePolicy.quizTtl, ContentCachePolicy.ttl);
      expect(ContentCachePolicy.inMemoryTtl, ContentCachePolicy.ttl);
    });

    test('fresh content is fresh', () {
      final justNow = DateTime.now().subtract(const Duration(minutes: 5));
      expect(ContentCachePolicy.isFresh(justNow), isTrue);
    });

    test('content older than the TTL is stale', () {
      final old = DateTime.now()
          .subtract(ContentCachePolicy.ttl + const Duration(minutes: 1));
      expect(ContentCachePolicy.isFresh(old), isFalse);
    });

    test('a timestamp from the future is not trusted', () {
      // Device clocks move. A future timestamp used to read as infinitely
      // fresh, which would pin a device to stale content until it was cleared
      // by hand.
      final future = DateTime.now().add(const Duration(days: 2));
      expect(ContentCachePolicy.isFresh(future), isFalse);
    });
  });

  group('Risk #47 — version changes bust the cache', () {
    test('same version keeps the cache', () {
      expect(ContentCachePolicy.shouldInvalidate(cached: 4, server: 4), isFalse);
    });

    test('a newer server version drops the cache', () {
      expect(ContentCachePolicy.shouldInvalidate(cached: 4, server: 5), isTrue);
    });

    test('a rolled-back server version also drops the cache', () {
      // If content is reverted, devices holding the withdrawn version are
      // exactly the ones that must refetch. "Different" is the trigger, not
      // "greater".
      expect(ContentCachePolicy.shouldInvalidate(cached: 5, server: 4), isTrue);
    });

    test('nothing cached yet is not an invalidation', () {
      // First run has no stored version. There is nothing to drop, and
      // reporting a bust here would clear a cache that was just written.
      expect(ContentCachePolicy.shouldInvalidate(cached: null, server: 3),
          isFalse);
    });

    test('version 0 on both sides is not an invalidation (positive control)', () {
      // A project with no contentMeta document reports 0 forever. That must be
      // a steady state, not a cache wipe on every launch.
      expect(ContentCachePolicy.shouldInvalidate(cached: 0, server: 0), isFalse);
    });
  });
}
