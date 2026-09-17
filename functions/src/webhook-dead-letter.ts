import { FieldValue } from 'firebase-admin/firestore';

/**
 * Dead-letter queue for store webhooks (risk #9).
 *
 * Both handlers used to swallow failures: Apple always received 200 "even on
 * internal error", and the Play handler never rethrew, so Pub/Sub always
 * acked. A renewal or revocation lost to a transient Firestore error was lost
 * permanently, with nothing recording that it had arrived.
 *
 * The original reasoning is in the code they replaced — retry storms caused by
 * our own bugs — and it is a real concern, so retries are BOUNDED. Every
 * failure is recorded; the platform is asked to retry a few times; after that
 * we stop asking and the record stays for manual replay.
 */
export const MAX_WEBHOOK_RETRIES = 5;

/** Firestore's document limit is ~1 MiB; stay well clear of it. */
const MAX_PAYLOAD_CHARS = 100_000;

export interface WebhookFailure {
  source: 'apple' | 'play';
  /** Stable per-notification id: Apple's notificationUUID, Play's messageId. */
  key: string;
  notificationType: string;
  payload: unknown;
  error: unknown;
}

export interface WebhookFailureResult {
  attempts: number;
  /** True while the platform should be asked to deliver this again. */
  shouldRetry: boolean;
}

/**
 * Record a webhook failure and report whether the platform should retry.
 *
 * Never throws. A dead-letter writer that throws would replace the real error
 * with its own and lose both.
 */
export async function recordWebhookFailure(
  db: FirebaseFirestore.Firestore,
  failure: WebhookFailure,
): Promise<WebhookFailureResult> {
  const docId = `${failure.source}_${failure.key}`;

  try {
    let serialised = '';
    let truncated = false;
    try {
      serialised = JSON.stringify(failure.payload) ?? '';
    } catch {
      // Circular or otherwise unserialisable — keep the failure, drop the body.
      serialised = '[unserialisable payload]';
      truncated = true;
    }
    if (serialised.length > MAX_PAYLOAD_CHARS) {
      serialised = serialised.slice(0, MAX_PAYLOAD_CHARS);
      truncated = true;
    }

    const ref = db.collection('webhookDeadLetter').doc(docId);
    const attempts = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const next = ((snap.exists ? snap.get('attempts') : 0) ?? 0) + 1;

      tx.set(ref, {
        source: failure.source,
        key: failure.key,
        notificationType: failure.notificationType,
        attempts: next,
        status: next > MAX_WEBHOOK_RETRIES ? 'exhausted' : 'pending',
        lastError: failure.error instanceof Error
          ? failure.error.message
          : String(failure.error),
        payload: serialised,
        payloadTruncated: truncated,
        firstSeenAt: snap.exists ? snap.get('firstSeenAt') : FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      return next;
    });

    const shouldRetry = attempts <= MAX_WEBHOOK_RETRIES;
    console.error(
      `📮 Dead-lettered ${failure.source} webhook ${failure.key} ` +
      `(type ${failure.notificationType}), attempt ${attempts}/${MAX_WEBHOOK_RETRIES}. ` +
      (shouldRetry
        ? 'Asking the platform to retry.'
        : 'Retry budget spent — parked for manual replay.'),
    );

    return { attempts, shouldRetry };
  } catch (writeError) {
    // Even the dead letter failed. Say so loudly and let the caller ack, so a
    // broken Firestore cannot become an infinite redelivery loop.
    console.error(
      `📮 CRITICAL: could not dead-letter ${failure.source} webhook ${failure.key}: `,
      writeError,
    );
    return { attempts: 0, shouldRetry: false };
  }
}
