import * as admin from 'firebase-admin';
// TODO: Uncomment when implementing real email sending
// import * as nodemailer from 'nodemailer';

// Function to get Firestore instance (ensures Firebase is initialized)
function getDb() {
  return admin.firestore();
}

// Email transporter configuration
// TODO: Uncomment and use this function when implementing real email sending
/*
const createEmailTransporter = () => {
  // For production, replace with your actual SMTP settings
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER || 'noreply@yourapp.com',
      pass: process.env.EMAIL_PASSWORD || 'mock-password'
    }
  });
};
*/

// Interface definitions
interface SubscriptionData {
  id: string;
  userId: string;
  isActive: boolean;
  status: string;
  trialUsed: number;
  trialEndsAt?: admin.firestore.Timestamp;
  nextBillingDate?: admin.firestore.Timestamp;
  planType: string;
  packageId: number;
}

interface ProcessingResult {
  totalProcessed: number;
  expiredTrials: number;
  expiredCanceledSubscriptions: number;
  emailsSent: number;
  errors: string[];
}

interface UserData {
  name: string;
  email: string;
  language: string;
}

/**
 * Main function to check and process all expired subscriptions
 * Called by the scheduled Cloud Function
 */
export async function processExpiredSubscriptions(): Promise<ProcessingResult> {
  console.log('🔍 Starting subscription expiration check...');
  const startTime = Date.now();
  
  const result: ProcessingResult = {
    totalProcessed: 0,
    expiredTrials: 0,
    expiredCanceledSubscriptions: 0,
    emailsSent: 0,
    errors: []
  };

  try {
    // PERF-1 FIX: Run both checks in parallel — they query different statuses
    // (planType='trial' vs status='canceled') with zero overlap, so Promise.all
    // is safe and cuts Cloud Function runtime roughly in half.
    const [trialResult, canceledResult] = await Promise.all([
      checkExpiredTrials(),
      checkExpiredCanceledSubscriptions(),
    ]);

    result.expiredTrials = trialResult.processed;
    result.emailsSent += trialResult.emailsSent;
    result.errors = result.errors.concat(trialResult.errors);

    result.expiredCanceledSubscriptions = canceledResult.processed;
    result.emailsSent += canceledResult.emailsSent;
    result.errors = result.errors.concat(canceledResult.errors);

    result.totalProcessed = result.expiredTrials + result.expiredCanceledSubscriptions;

    const duration = Date.now() - startTime;
    console.log(`✅ Subscription check completed in ${duration}ms`);
    console.log(`📊 Results: ${result.totalProcessed} processed, ${result.emailsSent} emails sent`);
    
    return result;
  } catch (error) {
    console.error('❌ Critical error in processExpiredSubscriptions:', error);
    result.errors.push(`Critical error: ${error instanceof Error ? error.message : String(error)}`);
    return result;
  }
}

/**
 * Check and process expired trials
 */
async function checkExpiredTrials(): Promise<{processed: number, emailsSent: number, errors: string[]}> {
  console.log('🆓 Checking expired trials...');
  const result: {processed: number, emailsSent: number, errors: string[]} = { processed: 0, emailsSent: 0, errors: [] };

  try {
    const now = admin.firestore.Timestamp.now();
    
    // Query expired trials.
    // BUG D FIX: added planType == 'trial' filter — without it, any subscription
    // with trialUsed=0 due to data corruption could be incorrectly deactivated.
    const db = getDb();
    // SM-MOD-2 FIX: Added isActive==true guard — consistent with every other
    // query in both files.  Without it, a partially-deactivated subscription
    // (isActive=false but status still 'active' due to a crash mid-update)
    // would be picked up, re-processed, and produce duplicate audit log entries.
    const expiredTrialsQuery = await db.collection('subscriptions')
      .where('planType', '==', 'trial')   // Only actual trial subscriptions
      .where('isActive', '==', true)       // FIX: skip already-deactivated docs
      .where('trialEndsAt', '<=', now)
      .where('trialUsed', '==', 0)
      .where('status', '==', 'active')
      .limit(100)
      .get();

    console.log(`Found ${expiredTrialsQuery.docs.length} expired trials to process`);

    // Process each expired trial
    for (const doc of expiredTrialsQuery.docs) {
      try {
        const subscriptionData = { id: doc.id, ...doc.data() } as SubscriptionData;
        
        // Update subscription status
        await updateExpiredTrial(subscriptionData);
        
        // Send notification email
        const emailSent = await sendTrialExpiredNotification(subscriptionData.userId);
        if (emailSent) result.emailsSent++;
        
        // Log the change — pass actual emailSent result (Bug SM-2 fix)
        await logSubscriptionChange(subscriptionData, 'trial_expired', emailSent);
        
        result.processed++;

      } catch (error) {
        const errorMsg = `Error processing trial ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
        console.error(`❌ ${errorMsg}`);
        result.errors.push(errorMsg);
      }
    }

    return result;
  } catch (error) {
    const errorMsg = `Error in checkExpiredTrials: ${error instanceof Error ? error.message : String(error)}`;
    console.error(`❌ ${errorMsg}`);
    result.errors.push(errorMsg);
    return result;
  }
}


/**
 * Check and process expired canceled subscriptions
 */
async function checkExpiredCanceledSubscriptions(): Promise<{processed: number, emailsSent: number, errors: string[]}> {
  console.log('❌ Checking expired canceled subscriptions...');
  const result: {processed: number, emailsSent: number, errors: string[]} = { processed: 0, emailsSent: 0, errors: [] };

  try {
    const now = admin.firestore.Timestamp.now();
    
    // Query expired canceled subscriptions
    const db = getDb();
    const expiredCanceledQuery = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', now)
      .where('status', '==', 'canceled')
      .where('isActive', '==', true)
      .limit(100) // Process in batches
      .get();

    console.log(`Found ${expiredCanceledQuery.docs.length} expired canceled subscriptions to process`);

    // Process each expired canceled subscription
    for (const doc of expiredCanceledQuery.docs) {
      try {
        const subscriptionData = { id: doc.id, ...doc.data() } as SubscriptionData;
        
        // Update subscription status
        await updateExpiredCanceledSubscription(subscriptionData);
        
        // Send notification email
        const emailSent = await sendSubscriptionExpiredNotification(subscriptionData.userId);
        if (emailSent) result.emailsSent++;
        
        // Log the change — pass actual emailSent result (Bug SM-2 fix)
        await logSubscriptionChange(subscriptionData, 'canceled_subscription_expired', emailSent);
        
        result.processed++;

      } catch (error) {
        const errorMsg = `Error processing canceled subscription ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
        console.error(`❌ ${errorMsg}`);
        result.errors.push(errorMsg);
      }
    }

    return result;
  } catch (error) {
    const errorMsg = `Error in checkExpiredCanceledSubscriptions: ${error instanceof Error ? error.message : String(error)}`;
    console.error(`❌ ${errorMsg}`);
    result.errors.push(errorMsg);
    return result;
  }
}

/**
 * Update expired trial subscription in database.
 * BUG SM-1 FIX: Use a batch write to update BOTH the subscription document AND
 * the user document atomically.  The Flutter app gates premium access via
 * users.isActive — without this fix, expired-trial users kept full access
 * because only subscriptions.isActive was set to false.
 */
async function updateExpiredTrial(subscriptionData: SubscriptionData): Promise<void> {
  const db = getDb();
  const batch = db.batch();

  // 1. Mark subscription inactive and consume the trial slot
  batch.update(db.collection('subscriptions').doc(subscriptionData.id), {
    isActive: false,
    status: 'inactive',
    trialUsed: 1, // Prevent reuse of the trial
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Revoke premium access on the user document.
  // SM-MOD-1 FIX: Use batch.set(..., {merge:true}) instead of batch.update().
  // batch.update() throws NOT_FOUND if the user document doesn't exist (e.g.
  // the user deleted their profile but the subscription survived).  That would
  // cause the entire batch to fail, leaving the trial subscription active and
  // the user with permanent premium access.  set/merge creates the doc if
  // missing and merges if present — always safe.
  batch.set(
    db.collection('users').doc(subscriptionData.userId),
    { isActive: false, lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  await batch.commit();
}


/**
 * Update expired canceled subscription in database.
 * BUG SM-1 FIX: Same batch-update pattern — revoke users.isActive so the
 * app correctly blocks premium access once the paid period ends.
 */
async function updateExpiredCanceledSubscription(subscriptionData: SubscriptionData): Promise<void> {
  const db = getDb();
  const batch = db.batch();

  // 1. Mark subscription inactive
  batch.update(db.collection('subscriptions').doc(subscriptionData.id), {
    isActive: false,
    status: 'inactive',
    // trialUsed stays as-is (already 1 for paid subscriptions)
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 2. Revoke premium access on the user document.
  // SM-MOD-1 FIX: Same set/merge pattern as updateExpiredTrial — prevents
  // NOT_FOUND error if the user document was deleted.
  batch.set(
    db.collection('users').doc(subscriptionData.userId),
    { isActive: false, lastUpdated: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  await batch.commit();
}

/**
 * Send trial expired notification email
 */
async function sendTrialExpiredNotification(userId: string): Promise<boolean> {
  try {
    // Get user data for email
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // For now, we'll mock the email sending
    // In production, replace with actual email implementation
    return true; // Mock successful send
  } catch (error) {
    console.error(`❌ Error sending trial expired email to ${userId}:`, error);
    return false;
  }
}

/**
 * Send subscription expired notification email
 */
async function sendSubscriptionExpiredNotification(userId: string): Promise<boolean> {
  try {
    // Get user data for email
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // For now, we'll mock the email sending
    // In production, replace with actual email implementation
    return true; // Mock successful send
  } catch (error) {
    console.error(`❌ Error sending subscription expired email to ${userId}:`, error);
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

/**
 * Log subscription change for audit trail.
 * BUG SM-2 FIX: `emailSent` is now passed in by the caller (actual value)
 * instead of being hardcoded to `true`, so logs are accurate even when the
 * email service fails or the user document is missing.
 */
async function logSubscriptionChange(
  subscriptionData: SubscriptionData,
  action: 'trial_expired' | 'subscription_expired' | 'canceled_subscription_expired',
  emailSent: boolean  // FIX: actual result from the caller
): Promise<void> {
  try {
    const logEntry = {
      userId: subscriptionData.userId,
      subscriptionId: subscriptionData.id,
      action,
      oldStatus: {
        isActive: subscriptionData.isActive,
        status: subscriptionData.status,
        trialUsed: subscriptionData.trialUsed,
      },
      newStatus: {
        isActive: false,
        status: 'inactive',
        trialUsed: action === 'trial_expired' ? 1 : subscriptionData.trialUsed,
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: 'scheduled_function',
      emailSent,  // FIX: actual value, not hardcoded true
    };

    const db = getDb();
    await db.collection('subscriptionLogs').add(logEntry);
    console.log(`📊 Logged subscription change: ${action} for ${subscriptionData.userId}`);
  } catch (error) {
    console.error('❌ Error logging subscription change:', error);
    // Don't throw — logging failure must not stop subscription processing
  }
}

/**
 * Manual trigger function for testing
 * Can be called directly to test subscription processing
 */
export async function testSubscriptionProcessing(): Promise<ProcessingResult> {
  console.log('🧪 Manual test trigger for subscription processing');
  return await processExpiredSubscriptions();
}

/**
 * Get statistics about upcoming expirations
 * Useful for monitoring and alerts
 */
export async function getSubscriptionStatistics(): Promise<{
  trialsExpiringToday: number;
  trialsExpiringTomorrow: number;
  canceledExpiringToday: number;
  canceledExpiringTomorrow: number;
}> {
  const now = new Date();
  const today = admin.firestore.Timestamp.fromDate(now);
  const tomorrow = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000));
  
  try {
    // PERF-2 FIX: Run all 4 queries in parallel — they are fully independent.
    // Previously they ran sequentially, making the function 4× slower than
    // necessary.  This mirrors the same optimization applied to
    // getRenewalStatistics in subscription-renewal-manager.ts (RM-2 fix).
    const db = getDb();
    const [trialsToday, trialsTomorrow, canceledToday, canceledTomorrow] = await Promise.all([
      // Trials that have already expired (or expire right now)
      db.collection('subscriptions')
        .where('planType', '==', 'trial')   // BUG SM-3 FIX: only real trials
        .where('isActive', '==', true)       // SM-MOD-2 FIX: skip dead docs
        .where('trialEndsAt', '<=', today)
        .where('trialUsed', '==', 0)
        .where('status', '==', 'active')
        .get(),

      // Trials expiring within the next 24 hours
      db.collection('subscriptions')
        .where('planType', '==', 'trial')   // BUG SM-3 FIX
        .where('isActive', '==', true)       // SM-MOD-2 FIX
        .where('trialEndsAt', '<=', tomorrow)
        .where('trialEndsAt', '>', today)
        .where('trialUsed', '==', 0)
        .where('status', '==', 'active')
        .get(),

      // Canceled subscriptions whose paid period has already ended
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', today)
        .where('status', '==', 'canceled')
        .where('isActive', '==', true)
        .get(),

      // Canceled subscriptions ending within the next 24 hours
      db.collection('subscriptions')
        .where('nextBillingDate', '<=', tomorrow)
        .where('nextBillingDate', '>', today)
        .where('status', '==', 'canceled')
        .where('isActive', '==', true)
        .get(),
    ]);

    return {
      trialsExpiringToday: trialsToday.docs.length,
      trialsExpiringTomorrow: trialsTomorrow.docs.length,
      canceledExpiringToday: canceledToday.docs.length,
      canceledExpiringTomorrow: canceledTomorrow.docs.length,
    };
  } catch (error) {
    console.error('❌ Error getting subscription statistics:', error);
    return {
      trialsExpiringToday: 0,
      trialsExpiringTomorrow: 0,
      canceledExpiringToday: 0,
      canceledExpiringTomorrow: 0
    };
  }
}
