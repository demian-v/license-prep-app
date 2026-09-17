import { Firestore } from 'firebase-admin/firestore';

/**
 * Risk #47 — the content cache-bust signal.
 *
 * Content is cached on device for up to 24 hours. Without a signal, a wrong
 * answer or a legally sensitive traffic-rule correction cannot be pushed out —
 * it expires out, whenever each device happens to get there. This is one
 * integer the client compares against the version it cached: if they differ,
 * the cache is dropped, regardless of how fresh the TTL thinks it is.
 *
 * Bumping it is a content-operations step, not a deploy.
 */
export const CONTENT_VERSION_COLLECTION = 'contentMeta';
export const CONTENT_VERSION_DOC = 'current';

/**
 * What a project with no version document reports. A fresh or not-yet-seeded
 * project must still serve content, so "missing" is version 0, never an error.
 */
export const DEFAULT_CONTENT_VERSION = 0;

/**
 * Coerce whatever is in the document into a usable version.
 *
 * Anything malformed reads as the default rather than as "newer". A hand-edit
 * in the Firebase console that produced `"3"` or `-1` would otherwise make every
 * device treat its cache as stale on every launch — a self-inflicted stampede
 * on the content callables.
 */
export function parseContentVersion(data: any): number {
  const raw = data?.version;
  if (typeof raw !== 'number' || !Number.isFinite(raw) || raw < 0) {
    return DEFAULT_CONTENT_VERSION;
  }
  return Math.floor(raw);
}

export async function readContentVersion(db: Firestore): Promise<number> {
  const snap = await db
    .collection(CONTENT_VERSION_COLLECTION)
    .doc(CONTENT_VERSION_DOC)
    .get();

  if (!snap.exists) return DEFAULT_CONTENT_VERSION;
  return parseContentVersion(snap.data());
}
