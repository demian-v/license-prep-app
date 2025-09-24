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
  expiredPaidSubscriptions: number;
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
    expiredPaidSubscriptions: 0,
    emailsSent: 0,
    errors: []
  };

  try {
    // Process expired trials
    const trialResult = await checkExpiredTrials();
    result.expiredTrials = trialResult.processed;
    result.emailsSent += trialResult.emailsSent;
    result.errors = result.errors.concat(trialResult.errors);

    // Process expired paid subscriptions
    const paidResult = await checkExpiredPaidSubscriptions();
    result.expiredPaidSubscriptions = paidResult.processed;
    result.emailsSent += paidResult.emailsSent;
    result.errors = result.errors.concat(paidResult.errors);

    result.totalProcessed = result.expiredTrials + result.expiredPaidSubscriptions;

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
    
    // Query expired trials
    const db = getDb();
    const expiredTrialsQuery = await db.collection('subscriptions')
      .where('trialEndsAt', '<=', now)
      .where('trialUsed', '==', 0)
      .where('status', '==', 'active')
      .limit(100) // Process in batches
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
        
        // Log the change
        await logSubscriptionChange(subscriptionData, 'trial_expired');
        
        result.processed++;
        console.log(`✅ Processed expired trial for user: ${subscriptionData.userId}`);
        
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
 * Check and process expired paid subscriptions
 */
async function checkExpiredPaidSubscriptions(): Promise<{processed: number, emailsSent: number, errors: string[]}> {
  console.log('💳 Checking expired paid subscriptions...');
  const result: {processed: number, emailsSent: number, errors: string[]} = { processed: 0, emailsSent: 0, errors: [] };

  try {
    const now = admin.firestore.Timestamp.now();
    
    // Query expired paid subscriptions
    const db = getDb();
    const expiredPaidQuery = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', now)
      .where('trialUsed', '==', 1)
      .where('status', '==', 'active')
      .limit(100) // Process in batches
      .get();

    console.log(`Found ${expiredPaidQuery.docs.length} expired paid subscriptions to process`);

    // Process each expired paid subscription
    for (const doc of expiredPaidQuery.docs) {
      try {
        const subscriptionData = { id: doc.id, ...doc.data() } as SubscriptionData;
        
        // Update subscription status
        await updateExpiredPaidSubscription(subscriptionData);
        
        // Send notification email
        const emailSent = await sendSubscriptionExpiredNotification(subscriptionData.userId);
        if (emailSent) result.emailsSent++;
        
        // Log the change
        await logSubscriptionChange(subscriptionData, 'subscription_expired');
        
        result.processed++;
        console.log(`✅ Processed expired subscription for user: ${subscriptionData.userId}`);
        
      } catch (error) {
        const errorMsg = `Error processing subscription ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
        console.error(`❌ ${errorMsg}`);
        result.errors.push(errorMsg);
      }
    }

    return result;
  } catch (error) {
    const errorMsg = `Error in checkExpiredPaidSubscriptions: ${error instanceof Error ? error.message : String(error)}`;
    console.error(`❌ ${errorMsg}`);
    result.errors.push(errorMsg);
    return result;
  }
}

/**
 * Update expired trial subscription in database
 */
async function updateExpiredTrial(subscriptionData: SubscriptionData): Promise<void> {
  console.log(`📝 Updating expired trial for subscription: ${subscriptionData.id}`);
  
  const db = getDb();
  await db.collection('subscriptions').doc(subscriptionData.id).update({
    isActive: false,
    status: 'inactive',
    trialUsed: 1, // Mark trial as used
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`✅ Trial subscription ${subscriptionData.id} marked as expired`);
}

/**
 * Update expired paid subscription in database
 */
async function updateExpiredPaidSubscription(subscriptionData: SubscriptionData): Promise<void> {
  console.log(`📝 Updating expired paid subscription: ${subscriptionData.id}`);
  
  const db = getDb();
  await db.collection('subscriptions').doc(subscriptionData.id).update({
    isActive: false,
    status: 'inactive',
    // Note: trialUsed stays as 1 (already used trial)
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`✅ Paid subscription ${subscriptionData.id} marked as expired`);
}

/**
 * Send trial expired notification email
 */
async function sendTrialExpiredNotification(userId: string): Promise<boolean> {
  try {
    console.log(`📧 Sending trial expired notification to user: ${userId}`);
    
    // Get user data for email
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // For now, we'll mock the email sending
    // In production, replace with actual email implementation
    console.log(`📨 MOCK EMAIL: Trial expired notification sent to ${userData.email}`);
    console.log(`   Subject: Your trial has expired`);
    console.log(`   Language: ${userData.language}`);
    
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
    console.log(`📧 Sending subscription expired notification to user: ${userId}`);
    
    // Get user data for email
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // For now, we'll mock the email sending
    // In production, replace with actual email implementation
    console.log(`📨 MOCK EMAIL: Subscription expired notification sent to ${userData.email}`);
    console.log(`   Subject: Your subscription has expired`);
    console.log(`   Language: ${userData.language}`);
    
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
 * Log subscription change for audit trail
 */
async function logSubscriptionChange(
  subscriptionData: SubscriptionData,
  action: 'trial_expired' | 'subscription_expired'
): Promise<void> {
  try {
    const logEntry = {
      userId: subscriptionData.userId,
      subscriptionId: subscriptionData.id,
      action: action,
      oldStatus: {
        isActive: subscriptionData.isActive,
        status: subscriptionData.status,
        trialUsed: subscriptionData.trialUsed
      },
      newStatus: {
        isActive: false,
        status: 'inactive',
        trialUsed: action === 'trial_expired' ? 1 : subscriptionData.trialUsed
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: 'scheduled_function',
      emailSent: true // We'll update this based on actual email result
    };

    const db = getDb();
    await db.collection('subscriptionLogs').add(logEntry);
    console.log(`📊 Logged subscription change: ${action} for ${subscriptionData.userId}`);
    
  } catch (error) {
    console.error(`❌ Error logging subscription change:`, error);
    // Don't throw error - logging failure shouldn't stop processing
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
  subscriptionsExpiringToday: number;
  subscriptionsExpiringTomorrow: number;
}> {
  const now = new Date();
  const today = admin.firestore.Timestamp.fromDate(now);
  const tomorrow = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000));
  
  try {
    // Count trials expiring today
    const db = getDb();
    const trialsToday = await db.collection('subscriptions')
      .where('trialEndsAt', '<=', today)
      .where('trialUsed', '==', 0)
      .where('status', '==', 'active')
      .get();

    // Count trials expiring tomorrow
    const trialsTomorrow = await db.collection('subscriptions')
      .where('trialEndsAt', '<=', tomorrow)
      .where('trialEndsAt', '>', today)
      .where('trialUsed', '==', 0)
      .where('status', '==', 'active')
      .get();

    // Count subscriptions expiring today
    const subscriptionsToday = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', today)
      .where('trialUsed', '==', 1)
      .where('status', '==', 'active')
      .get();

    // Count subscriptions expiring tomorrow
    const subscriptionsTomorrow = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', tomorrow)
      .where('nextBillingDate', '>', today)
      .where('trialUsed', '==', 1)
      .where('status', '==', 'active')
      .get();

    return {
      trialsExpiringToday: trialsToday.docs.length,
      trialsExpiringTomorrow: trialsTomorrow.docs.length,
      subscriptionsExpiringToday: subscriptionsToday.docs.length,
      subscriptionsExpiringTomorrow: subscriptionsTomorrow.docs.length
    };
  } catch (error) {
    console.error('❌ Error getting subscription statistics:', error);
    return {
      trialsExpiringToday: 0,
      trialsExpiringTomorrow: 0,
      subscriptionsExpiringToday: 0,
      subscriptionsExpiringTomorrow: 0
    };
  }
}
