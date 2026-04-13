import * as admin from 'firebase-admin';

// Function to get Firestore instance (ensures Firebase is initialized)
function getDb() {
  return admin.firestore();
}

// Maximum consecutive missed billing cycles before a subscription is deactivated.
// Each scheduler run represents one 6-hour window, so 3 attempts ≈ 18 hours grace.
const MAX_RENEWAL_ATTEMPTS = 3;

// Interface definitions
interface SubscriptionData {
  id: string;
  userId: string;
  isActive: boolean;
  status: string;
  trialUsed: number;
  nextBillingDate: admin.firestore.Timestamp;
  planType: string; // 'monthly' | 'yearly'
  packageId: number;
  renewalAttempts?: number; // tracks consecutive missed billing cycles
}

interface RenewalResult {
  totalProcessed: number;
  successfulRenewals: number;
  failedRenewals: number;
  emailsSent: number;
  errors: string[];
}

interface UserData {
  name: string;
  email: string;
  language: string;
}

/**
 * Main function to check and process all active subscriptions due for renewal
 * Called by the scheduled Cloud Function
 */
export async function processActiveSubscriptionRenewals(): Promise<RenewalResult> {
  console.log('🔄 Starting subscription renewal check...');
  const startTime = Date.now();
  
  const result: RenewalResult = {
    totalProcessed: 0,
    successfulRenewals: 0,
    failedRenewals: 0,
    emailsSent: 0,
    errors: []
  };

  try {
    // Process subscription renewals
    const renewalResult = await checkSubscriptionRenewals();
    result.totalProcessed = renewalResult.processed;
    result.successfulRenewals = renewalResult.successful;
    result.failedRenewals = renewalResult.failed;
    result.emailsSent = renewalResult.emailsSent;
    result.errors = renewalResult.errors;

    const duration = Date.now() - startTime;
    console.log(`✅ Subscription renewal check completed in ${duration}ms`);
    console.log(`📊 Results: ${result.totalProcessed} processed, ${result.successfulRenewals} renewed`);
    
    return result;
  } catch (error) {
    console.error('❌ Critical error in processActiveSubscriptionRenewals:', error);
    result.errors.push(`Critical error: ${error instanceof Error ? error.message : String(error)}`);
    return result;
  }
}

/**
 * Check and process subscriptions that are overdue (past their nextBillingDate).
 *
 * IMPORTANT: For iOS/Android, the App Store / Google Play handles the actual
 * payment and renewal. This scheduler's job is purely to track Firestore state:
 *
 *   1. First occurrence: mark subscription `past_due`, increment renewalAttempts.
 *   2. After MAX_RENEWAL_ATTEMPTS consecutive missed cycles: deactivate the
 *      subscription (isActive=false, status='inactive') and notify the user.
 *   3. When Apple/Google delivers a real renewal receipt to the Flutter app, the
 *      receipt-validation function resets status→'active' and renewalAttempts→0.
 *
 * Querying both 'active' and 'past_due' statuses because after the first run
 * overdue subscriptions become 'past_due' and would be missed by a single query.
 */
async function checkSubscriptionRenewals(): Promise<{
  processed: number;
  successful: number;
  failed: number;
  emailsSent: number;
  errors: string[];
}> {
  console.log('🔄 Checking subscriptions due for renewal...');
  const result = { processed: 0, successful: 0, failed: 0, emailsSent: 0, errors: [] as string[] };

  try {
    const now = admin.firestore.Timestamp.now();
    const db = getDb();

    // Run two queries (Firestore does not support OR on different field values
    // without a composite index; two separate queries are simpler and reliable).
    const [activeQuery, pastDueQuery] = await Promise.all([
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', now)
        .where('status', '==', 'active')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .limit(100)
        .get(),
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', now)
        .where('status', '==', 'past_due')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .limit(100)
        .get(),
    ]);

    // Merge and de-duplicate (shouldn't overlap, but be safe)
    const seen = new Set<string>();
    const allDocs = [...activeQuery.docs, ...pastDueQuery.docs].filter(doc => {
      if (seen.has(doc.id)) return false;
      seen.add(doc.id);
      return true;
    });

    console.log(`Found ${allDocs.length} overdue subscription(s) to process`);

    for (const doc of allDocs) {
      try {
        const subscriptionData = { id: doc.id, ...doc.data() } as SubscriptionData;
        const { deactivated, emailSent } = await processOverdueSubscription(subscriptionData);

        if (deactivated) {
          result.failed++;
        } else {
          result.successful++;
        }
        if (emailSent) result.emailsSent++;
        result.processed++;

      } catch (error) {
        const errorMsg = `Error processing overdue subscription ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
        console.error(`❌ ${errorMsg}`);
        result.errors.push(errorMsg);
      }
    }

    return result;
  } catch (error) {
    const errorMsg = `Error in checkSubscriptionRenewals: ${error instanceof Error ? error.message : String(error)}`;
    console.error(`❌ ${errorMsg}`);
    result.errors.push(errorMsg);
    return result;
  }
}

/**
 * Process a single overdue subscription.
 *
 * - Increments renewalAttempts and marks status 'past_due'.
 * - After MAX_RENEWAL_ATTEMPTS it deactivates the subscription entirely.
 *
 * Real payment/renewal is done by Apple/Google — we only track Firestore state.
 * The receipt-validation function resets attempts when a real receipt arrives.
 */
async function processOverdueSubscription(
  subscriptionData: SubscriptionData
): Promise<{ deactivated: boolean; emailSent: boolean }> {
  const db = getDb();
  const attempts = (subscriptionData.renewalAttempts ?? 0);
  const newAttempts = attempts + 1;

  if (newAttempts > MAX_RENEWAL_ATTEMPTS) {
    // ── Deactivate ──────────────────────────────────────────────────────────
    const batch = db.batch();
    batch.update(db.collection('subscriptions').doc(subscriptionData.id), {
      isActive: false,
      status: 'inactive',
      renewalAttempts: 0, // reset so it can be reactivated cleanly if user re-subscribes
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // RM-MOD-1 FIX: Use batch.set(..., {merge:true}) instead of batch.update().
    // batch.update() throws NOT_FOUND if the user document doesn't exist (e.g.
    // user deleted their profile but their subscription survived 3 grace cycles).
    // That would cause the entire batch to fail silently, leaving the subscription
    // isActive=true even after grace period exhaustion — permanent free access.
    // set/merge creates the doc if missing and merges if present — always safe.
    // This mirrors the exact same fix applied in subscription-manager.ts for
    // updateExpiredTrial and updateExpiredCanceledSubscription (SM-MOD-1).
    batch.set(
      db.collection('users').doc(subscriptionData.userId),
      { isActive: false, lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
    await batch.commit();

    const emailSent = await sendRenewalFailureNotification(subscriptionData.userId);
    await logRenewalActivity(subscriptionData, 'subscription_deactivated', false, emailSent);

    return { deactivated: true, emailSent };
  }

  // ── Mark past_due, increment counter ──────────────────────────────────────
  await db.collection('subscriptions').doc(subscriptionData.id).update({
    status: 'past_due',
    renewalAttempts: newAttempts,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // BUG RM-1 FIX: Only email the user on the FIRST missed billing cycle
  // (when attempts transitions from 0 → 1, i.e. status changes from 'active'
  // to 'past_due').  On every subsequent scheduler run the subscription is
  // already 'past_due' — re-sending the same email every 6 hours is spammy
  // and hurts deliverability.  The user receives a second (final) notification
  // when the subscription is deactivated after MAX_RENEWAL_ATTEMPTS.
  const isFirstMiss = attempts === 0;
  const emailSent = isFirstMiss
    ? await sendRenewalFailureNotification(subscriptionData.userId)
    : false;

  await logRenewalActivity(subscriptionData, 'subscription_past_due', false, emailSent);

  return { deactivated: false, emailSent };
}

/**
 * Send renewal failure / past-due notification email
 */
async function sendRenewalFailureNotification(userId: string): Promise<boolean> {
  try {
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // Mock email sending - replace with actual implementation
    
    return true;
  } catch (error) {
    console.error(`❌ Error sending renewal failure email to ${userId}:`, error);
    return false;
  }
}

/**
 * Get user data for email notifications
 */
async function getUserData(userId: string): Promise<UserData | null> {
  try {
    const db = getDb();
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.warn(`⚠️ User document not found: ${userId}`);
      return null;
    }

    const data = userDoc.data();
    if (!data) {
      console.warn(`⚠️ User data is empty: ${userId}`);
      return null;
    }

    return {
      name: data.name || 'User',
      email: data.email || '',
      language: data.language || 'en'
    };
  } catch (error) {
    console.error(`❌ Error getting user data for ${userId}:`, error);
    return null;
  }
}

// All possible renewal-lifecycle actions written to the audit log.
type RenewalAction =
  | 'subscription_past_due'      // overdue; within grace period
  | 'subscription_deactivated'   // grace period exhausted; access revoked
  | 'subscription_renewed';      // kept for backward-compat with existing logs

/**
 * Log renewal activity for audit trail.
 * BUG F FIX: emailSent is now passed in from the caller instead of being
 * hardcoded to `true`, so the log accurately reflects what happened.
 */
async function logRenewalActivity(
  subscriptionData: SubscriptionData,
  action: RenewalAction,
  success: boolean,
  emailSent: boolean  // FIX: actual result, not hardcoded true
): Promise<void> {
  try {
    const isDeactivated = action === 'subscription_deactivated';

    const logEntry = {
      userId: subscriptionData.userId,
      subscriptionId: subscriptionData.id,
      action,
      oldStatus: {
        nextBillingDate: subscriptionData.nextBillingDate,
        status: subscriptionData.status,
        isActive: subscriptionData.isActive,
        renewalAttempts: subscriptionData.renewalAttempts ?? 0,
      },
      newStatus: {
        status: isDeactivated ? 'inactive' : 'past_due',
        isActive: !isDeactivated,
      },
      renewalDetails: {
        planType: subscriptionData.planType,
        packageId: subscriptionData.packageId,
        renewalSuccess: success,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: 'renewal_function',
      emailSent,  // FIX: actual value, not hardcoded true
    };

    const db = getDb();
    await db.collection('subscriptionLogs').add(logEntry);
    console.log(`📊 Logged renewal activity: ${action} for ${subscriptionData.userId}`);
  } catch (error) {
    console.error('❌ Error logging renewal activity:', error);
    // Don't throw — logging failure must not stop subscription processing
  }
}

/**
 * Get statistics about subscription renewals for monitoring.
 * BUG RM-2 FIX: Added `pastDueCount` — subscriptions already in the grace
 * period (status='past_due') were previously invisible to the dashboard,
 * making it look like there were 0 overdue subscriptions when there could be
 * dozens waiting to be deactivated.
 */
export async function getRenewalStatistics(): Promise<{
  subscriptionsDueToday: number;    // active subscriptions that just became overdue
  subscriptionsDueTomorrow: number; // active subscriptions overdue within 24 h
  monthlySubscriptionsDue: number;
  yearlySubscriptionsDue: number;
  pastDueCount: number;             // FIX: subscriptions already in grace period
}> {
  const now = new Date();
  const today = admin.firestore.Timestamp.fromDate(now);
  const tomorrow = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000));

  try {
    const db = getDb();

    // Fetch all five counts in parallel for efficiency
    const [
      subscriptionsTodaySnap,
      subscriptionsTomorrowSnap,
      monthlySnap,
      yearlySnap,
      pastDueSnap,              // FIX: new query
    ] = await Promise.all([
      // Active subscriptions that are already overdue
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', today)
        .where('status', '==', 'active')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .get(),

      // Active subscriptions that will become overdue within the next 24 h
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', tomorrow)
        .where('nextBillingDate', '>', today)
        .where('status', '==', 'active')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .get(),

      // Monthly breakdown of overdue active subscriptions
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', today)
        .where('status', '==', 'active')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .where('planType', '==', 'monthly')
        .get(),

      // Yearly breakdown of overdue active subscriptions
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', today)
        .where('status', '==', 'active')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .where('planType', '==', 'yearly')
        .get(),

      // BUG RM-2 FIX: subscriptions already in the grace-period queue
      db.collection('subscriptions')
        .where('status', '==', 'past_due')
        .where('isActive', '==', true)
        .where('trialUsed', '==', 1)
        .get(),
    ]);

    return {
      subscriptionsDueToday: subscriptionsTodaySnap.docs.length,
      subscriptionsDueTomorrow: subscriptionsTomorrowSnap.docs.length,
      monthlySubscriptionsDue: monthlySnap.docs.length,
      yearlySubscriptionsDue: yearlySnap.docs.length,
      pastDueCount: pastDueSnap.docs.length,  // FIX: now visible in dashboard
    };
  } catch (error) {
    console.error('❌ Error getting renewal statistics:', error);
    return {
      subscriptionsDueToday: 0,
      subscriptionsDueTomorrow: 0,
      monthlySubscriptionsDue: 0,
      yearlySubscriptionsDue: 0,
      pastDueCount: 0,
    };
  }
}
