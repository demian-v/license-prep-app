import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

/**
 * Server-side entitlement gate (risk #3).
 *
 * Until this existed, entitlement was decided entirely in the Flutter UI
 * (lib/utils/subscription_checker.dart), which made every client-side paywall
 * decorative: the content callables had no `context.auth` check at all, so the
 * whole paid corpus — including `correctAnswer` and `explanation` — was
 * available to anyone who could name the callable.
 *
 * Three gates, in order:
 *   1. signed in at all                    -> else `unauthenticated`
 *   2. not an anonymous session            -> else `permission-denied`
 *   3. a live trial or paid subscription   -> else `permission-denied`
 *
 * Gate 2 matters because lib/main.dart signs every visitor in anonymously,
 * which turns any `request.auth != null` check into "public".
 *
 * Note on gate 3: the query filters on equality only (`userId`, `isActive`) and
 * evaluates expiry in code. Firestore serves equality-only queries from
 * single-field indexes, so this deliberately needs no composite index — see
 * risk #15, where a missing composite index silently breaks the purchase path.
 */
export async function requireEntitledUser(context: any): Promise<string> {
  if (!context || !context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Sign in to access this content.',
    );
  }

  const provider = context.auth.token?.firebase?.sign_in_provider;
  if (provider === 'anonymous') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Anonymous sessions cannot access subscriber content.',
    );
  }

  const uid: string = context.auth.uid;
  const snap = await admin
    .firestore()
    .collection('subscriptions')
    .where('userId', '==', uid)
    .where('isActive', '==', true)
    .get();

  // `isActive` alone is not proof of entitlement: the expiry schedulers are
  // capped at 100 documents per run (risk #25), so a lapsed subscription can
  // sit with isActive:true until a sweep reaches it. Checking the date here
  // makes the gate correct regardless of scheduler lag.
  const nowMs = Date.now();
  const entitled = snap.docs.some((doc) => {
    const nextBillingDate = doc.get('nextBillingDate');
    return nextBillingDate != null && nextBillingDate.toMillis() > nowMs;
  });

  if (!entitled) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'An active subscription or trial is required.',
    );
  }

  return uid;
}
