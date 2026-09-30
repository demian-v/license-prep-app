import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { isWithinStoreGrace } from './billing-grace';

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
  const { uid, live } = await liveSubscriptions(context);
  if (live.length === 0) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'An active subscription or trial is required.',
    );
  }
  return uid;
}

/**
 * Paid-subscriber gate — the Instructors marketplace (listing, chat, booking).
 *
 * Owner decision 2026-09-30: trial users see only a locked preview; the
 * marketplace needs a paid plan. Same three gates as requireEntitledUser, but
 * gate 3 ignores `planType: 'trial'` subscriptions. The trial/paid distinction
 * lives only on subscriptions docs — nothing mirrors it onto users/{uid} — so
 * Firestore rules cannot express this gate, and instructor data is served
 * through callables that call this instead of being client-readable.
 */
export async function requirePaidSubscriber(context: any): Promise<string> {
  const { uid, live } = await liveSubscriptions(context);
  if (!live.some((doc) => doc.get('planType') !== 'trial')) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'A paid subscription is required.',
    );
  }
  return uid;
}

async function liveSubscriptions(
  context: any,
): Promise<{ uid: string; live: FirebaseFirestore.QueryDocumentSnapshot[] }> {
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
  // sit with isActive:true until a sweep reaches it.
  //
  // But a bare `nextBillingDate > now` was too strict, and reproduced risk #7
  // one layer up: it locked out a paying customer the moment a renewal ran
  // late, while Apple or Google were still retrying the charge. Entitlement
  // therefore extends through the same store grace window the renewal
  // scheduler uses, so the two cannot disagree about who is entitled.
  const nowMs = Date.now();
  const live = snap.docs.filter((doc) => {
    const nextBillingDate = doc.get('nextBillingDate');
    if (nextBillingDate == null) return false;
    return nextBillingDate.toMillis() > nowMs || isWithinStoreGrace(nextBillingDate, nowMs);
  });

  return { uid, live };
}

/**
 * Administrator gate (risk #18).
 *
 * Four functions — processSubscriptionsManualy, getSubscriptionStats,
 * subscriptionSystemHealth, getRenewalStats — were callable by any
 * authenticated user, each carrying the comment "Optional: Add admin
 * authentication check". One mutates subscription state; another returns other
 * users' subscriptionLogs rows.
 *
 * Mirrors the isAdmin() helper in firestore.rules: membership is a document at
 * admins/{uid}. Read with the Admin SDK, so security rules do not apply and the
 * collection stays unreadable by clients.
 *
 * NOTE: the admins collection is empty in production, so until an admin
 * document is provisioned these endpoints are callable by nobody. That is the
 * intended resting state for admin tooling — deliberately closed by default.
 */
export async function requireAdmin(context: any): Promise<string> {
  if (!context || !context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required.',
    );
  }

  const uid: string = context.auth.uid;
  const doc = await admin.firestore().collection('admins').doc(uid).get();

  if (!doc.exists) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Administrator access required.',
    );
  }

  return uid;
}
