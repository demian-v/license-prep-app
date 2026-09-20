/**
 * Risk #76 — every Google Play notification deduped against the SAME document.
 *
 * `handleGooglePlayNotifications` keyed its dedup document on
 * `(message as any).messageId`. The handler is Functions **v1**, and the v1
 * `Message` class exposes only `data`, `attributes`, `json` and `toJSON()` —
 * there is no `messageId`. The Pub/Sub delivery id lives on the second
 * handler argument, `context.eventId`.
 *
 * So the expression was always `undefined`, every notification addressed
 * `processedWebhooks/gp_undefined`, the first one created it, and every one
 * since returned early as "already processed". Production holds exactly one
 * Google document, its id literally `gp_undefined`, dated 2026-04-17 — while
 * Apple's documents, keyed on a real notificationUUID, are numerous and fine.
 *
 * The `as any` cast is what hid it: without the cast this would not compile.
 *
 * What these tests actually protect:
 *
 *   1. the key is DERIVED — two different deliveries cannot collide;
 *   2. a missing id yields `null` rather than a constant, so the caller skips
 *      deduplication instead of silently deduplicating everything together.
 *      Processing a Pub/Sub redelivery twice is recoverable; dropping every
 *      notification for five months is what actually happened.
 */
import * as fs from 'fs';
import * as path from 'path';
import { playDedupKey } from '../play-notifications';

describe('Risk #76 — the Play dedup key is derived, never constant', () => {
  it('different delivery ids produce different keys', () => {
    const a = playDedupKey('1234567890');
    const b = playDedupKey('9876543210');
    expect(a).toBe('gp_1234567890');
    expect(b).toBe('gp_9876543210');
    expect(a).not.toBe(b);
  });

  it('never produces the literal that broke production', () => {
    expect(playDedupKey('abc')).not.toBe('gp_undefined');
    // The exact shape of the bug: an absent id must not stringify into the key.
    for (const missing of [undefined, null, '']) {
      expect(playDedupKey(missing)).not.toBe('gp_undefined');
      expect(String(playDedupKey(missing))).not.toContain('undefined');
    }
  });

  it('a missing id disables dedup rather than collapsing everything onto one doc', () => {
    // null tells the caller "do not dedup this one", which fails toward
    // processing a duplicate rather than toward dropping every notification.
    expect(playDedupKey(undefined)).toBeNull();
    expect(playDedupKey(null)).toBeNull();
    expect(playDedupKey('')).toBeNull();
  });
});

describe('Risk #76 — the handler reads the id from the right place', () => {
  const SRC = fs.readFileSync(path.join(__dirname, '../index.ts'), 'utf8');

  // Delimit on the next top-level export so the assertions cannot accidentally
  // match a neighbouring function — a sloppy window has produced a false pass
  // in this project before.
  const START = 'export const handleGooglePlayNotifications';
  const startIdx = SRC.indexOf(START);
  const afterStart = SRC.indexOf('\nexport ', startIdx + START.length);
  const handler = SRC.slice(startIdx, afterStart === -1 ? SRC.length : afterStart);

  // Assert on CODE, not prose. The comments in this handler necessarily quote
  // the old broken expression to explain it, and a guard that reads comments
  // would fail on its own documentation.
  const code = handler
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');

  it('positive control: the handler region was actually found', () => {
    expect(startIdx).toBeGreaterThan(-1);
    expect(handler).toContain('play-rtdn');
    expect(handler).toContain('subscriptionNotification');
    // Long enough to be the real body, not a stub or a comment.
    expect(handler.length).toBeGreaterThan(2000);
  });

  it('positive control: stripping comments left real code behind', () => {
    // Without this, a bug in the stripper above would empty `code` and make
    // every "not.toMatch" assertion below pass for the wrong reason.
    expect(code).toContain('subscriptionNotification');
    expect(code).toContain('processedWebhooks');
    expect(code.length).toBeGreaterThan(1000);
  });

  it('does not read messageId off the Pub/Sub message (it does not exist in v1)', () => {
    expect(code).not.toMatch(/message\s+as\s+any/);
    expect(code).not.toMatch(/\.messageId/);
  });

  it('takes the delivery id from context.eventId', () => {
    expect(code).toMatch(/context[.?]/);
    expect(code).toContain('eventId');
  });

  it('does not build the dedup document id by interpolating in place', () => {
    // Every write site must go through the shared, tested key instead of
    // re-deriving `gp_${...}` — three sites drifted apart once already.
    expect(code).not.toMatch(/gp_\$\{/);
  });
});
