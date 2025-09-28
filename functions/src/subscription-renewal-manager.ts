import * as admin from 'firebase-admin';

// Function to get Firestore instance (ensures Firebase is initialized)
function getDb() {
  return admin.firestore();
}

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
}

interface RenewalResult {
  totalProcessed: number;
  successfulRenewals: number;
  failedRenewals: number;
  emailsSent: number;
  errors: string[];
}

interface MockPaymentResult {
  success: boolean;
  failureReason?: string;
  transactionId: string;
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
 * Check and process subscriptions due for renewal
 */
async function checkSubscriptionRenewals(): Promise<{
  processed: number, 
  successful: number, 
  failed: number, 
  emailsSent: number, 
  errors: string[]
}> {
  console.log('🔄 Checking subscriptions due for renewal...');
  const result: {
    processed: number;
    successful: number;
    failed: number;
    emailsSent: number;
    errors: string[];
  } = { processed: 0, successful: 0, failed: 0, emailsSent: 0, errors: [] };

  try {
    const now = admin.firestore.Timestamp.now();
    
    // Query subscriptions due for renewal
    const db = getDb();
    const subscriptionsDueQuery = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', now)
      .where('status', '==', 'active')
      .where('isActive', '==', true)
      .where('trialUsed', '==', 1) // Past trial period
      .limit(100) // Process in batches
      .get();

    console.log(`Found ${subscriptionsDueQuery.docs.length} subscriptions due for renewal`);

    // Process each subscription
    for (const doc of subscriptionsDueQuery.docs) {
      try {
        const subscriptionData = { id: doc.id, ...doc.data() } as SubscriptionData;
        
        // Attempt renewal
        const renewalSuccess = await renewSubscription(subscriptionData);
        
        if (renewalSuccess) {
          result.successful++;
          
          // Send success notification
          const emailSent = await sendRenewalSuccessNotification(subscriptionData.userId);
          if (emailSent) result.emailsSent++;
          
          // Log successful renewal
          await logRenewalActivity(subscriptionData, 'subscription_renewed' as const, true);
        } else {
          result.failed++;
          
          // Send failure notification
          const emailSent = await sendRenewalFailureNotification(subscriptionData.userId);
          if (emailSent) result.emailsSent++;
          
          // Log failed renewal
          await logRenewalActivity(subscriptionData, 'subscription_renewal_failed' as const, false);
        }
        
        result.processed++;
        console.log(`✅ Processed renewal for user: ${subscriptionData.userId}, success: ${renewalSuccess}`);
        
      } catch (error) {
        const errorMsg = `Error processing renewal ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
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
 * Process individual subscription renewal
 */
async function renewSubscription(subscriptionData: SubscriptionData): Promise<boolean> {
  try {
    console.log(`💳 Processing renewal for subscription: ${subscriptionData.id}`);
    
    // 1. Mock payment processing
    const paymentResult = await mockRenewalPayment(subscriptionData);
    
  if (paymentResult.success) {
      // 2. Calculate new billing date
      const currentBillingDate = subscriptionData.nextBillingDate.toDate();
      const newBillingDate = calculateNextBillingDate(currentBillingDate, subscriptionData.planType);
      const newBillingTimestamp = admin.firestore.Timestamp.fromDate(newBillingDate);
      
      // 3. Update both subscription and user collections using batch
      const db = getDb();
      const batch = db.batch();
      
      // Update subscription document
      const subscriptionRef = db.collection('subscriptions').doc(subscriptionData.id);
      batch.update(subscriptionRef, {
        nextBillingDate: newBillingTimestamp,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Update user document with same nextBillingDate
      const userRef = db.collection('users').doc(subscriptionData.userId);
      batch.update(userRef, {
        nextBillingDate: newBillingTimestamp,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Commit both updates atomically
      await batch.commit();
      
      console.log(`✅ Subscription ${subscriptionData.id} renewed successfully. Next billing: ${newBillingDate.toISOString()}`);
      console.log(`✅ User ${subscriptionData.userId} nextBillingDate updated to: ${newBillingDate.toISOString()}`);
      return true;
    } else {
      console.log(`❌ Payment failed for subscription ${subscriptionData.id}: ${paymentResult.failureReason}`);
      return false;
    }
    
  } catch (error) {
    console.error(`❌ Error renewing subscription ${subscriptionData.id}:`, error);
    return false;
  }
}

/**
 * Mock payment processing function
 * Simulates different payment outcomes for testing
 */
async function mockRenewalPayment(subscriptionData: SubscriptionData): Promise<MockPaymentResult> {
  console.log(`🎭 Mock payment processing for subscription: ${subscriptionData.id}`);
  
  // Simulate processing delay
  await new Promise(resolve => setTimeout(resolve, 100));
  
  // Generate predictable results based on subscription ID
  const lastDigit = parseInt(subscriptionData.id.slice(-1), 16) % 10;
  
  if (lastDigit <= 7) { // 80% success rate
    return {
      success: true,
      transactionId: `mock_renewal_${Date.now()}_${subscriptionData.id.slice(-4)}`
    };
  } else if (lastDigit === 8) { // 10% payment failure
    return {
      success: false,
      failureReason: 'insufficient_funds',
      transactionId: `failed_${Date.now()}_${subscriptionData.id.slice(-4)}`
    };
  } else { // 10% network error
    return {
      success: false,
      failureReason: 'network_error',
      transactionId: `error_${Date.now()}_${subscriptionData.id.slice(-4)}`
    };
  }
}

/**
 * Calculate next billing date based on plan type
 */
function calculateNextBillingDate(currentDate: Date, planType: string): Date {
  const newDate = new Date(currentDate);
  
  if (planType === 'monthly') {
    // Add 1 month
    newDate.setMonth(newDate.getMonth() + 1);
    
    // Handle edge cases (e.g., Jan 31 -> Feb 28/29)
    if (newDate.getDate() !== currentDate.getDate()) {
      // If day changed due to month having fewer days, set to last day of month
      newDate.setDate(0);
    }
  } else if (planType === 'yearly') {
    // Add 1 year
    newDate.setFullYear(newDate.getFullYear() + 1);
    
    // Handle leap year edge case (Feb 29 -> Feb 28)
    if (newDate.getDate() !== currentDate.getDate()) {
      newDate.setDate(0);
    }
  } else {
    console.warn(`Unknown plan type: ${planType}, defaulting to monthly`);
    newDate.setMonth(newDate.getMonth() + 1);
  }
  
  return newDate;
}

/**
 * Send renewal success notification email
 */
async function sendRenewalSuccessNotification(userId: string): Promise<boolean> {
  try {
    console.log(`📧 Sending renewal success notification to user: ${userId}`);
    
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // Mock email sending - replace with actual implementation
    console.log(`📨 MOCK EMAIL: Renewal success notification sent to ${userData.email}`);
    console.log(`   Subject: Your subscription has been renewed`);
    console.log(`   Language: ${userData.language}`);
    console.log(`   Template: RENEWAL_SUCCESS_TEMPLATES.${userData.language}`);
    
    return true;
  } catch (error) {
    console.error(`❌ Error sending renewal success email to ${userId}:`, error);
    return false;
  }
}

/**
 * Send renewal failure notification email
 */
async function sendRenewalFailureNotification(userId: string): Promise<boolean> {
  try {
    console.log(`📧 Sending renewal failure notification to user: ${userId}`);
    
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // Mock email sending - replace with actual implementation
    console.log(`📨 MOCK EMAIL: Renewal failure notification sent to ${userData.email}`);
    console.log(`   Subject: Action required: Subscription renewal failed`);
    console.log(`   Language: ${userData.language}`);
    console.log(`   Template: RENEWAL_FAILURE_TEMPLATES.${userData.language}`);
    
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

// Define the action type explicitly
type RenewalAction = 'subscription_renewed' | 'subscription_renewal_failed';

/**
 * Log renewal activity for audit trail
 */
async function logRenewalActivity(
  subscriptionData: SubscriptionData,
  action: RenewalAction,
  success: boolean
): Promise<void> {
  try {
    const currentBillingDate = subscriptionData.nextBillingDate.toDate();
    const newBillingDate = success ? calculateNextBillingDate(currentBillingDate, subscriptionData.planType) : currentBillingDate;
    
    const logEntry = {
      userId: subscriptionData.userId,
      subscriptionId: subscriptionData.id,
      action: action,
      oldStatus: {
        nextBillingDate: subscriptionData.nextBillingDate,
        status: subscriptionData.status,
        isActive: subscriptionData.isActive
      },
      newStatus: {
        nextBillingDate: admin.firestore.Timestamp.fromDate(newBillingDate),
        status: 'active', // Status remains active regardless of renewal outcome
        isActive: true
      },
      renewalDetails: {
        planType: subscriptionData.planType,
        packageId: subscriptionData.packageId,
        renewalSuccess: success
      },
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: 'renewal_function',
      emailSent: true // Will be updated based on actual email result
    };

    const db = getDb();
    await db.collection('subscriptionLogs').add(logEntry);
    console.log(`📊 Logged renewal activity: ${action} for ${subscriptionData.userId}`);
    
  } catch (error) {
    console.error(`❌ Error logging renewal activity:`, error);
    // Don't throw error - logging failure shouldn't stop processing
  }
}

/**
 * Get statistics about subscription renewals for monitoring
 */
export async function getRenewalStatistics(): Promise<{
  subscriptionsDueToday: number;
  subscriptionsDueTomorrow: number;
  monthlySubscriptionsDue: number;
  yearlySubscriptionsDue: number;
}> {
  const now = new Date();
  const today = admin.firestore.Timestamp.fromDate(now);
  const tomorrow = admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000));
  
  try {
    const db = getDb();
    
    // Count subscriptions due today
    const subscriptionsToday = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', today)
      .where('status', '==', 'active')
      .where('isActive', '==', true)
      .where('trialUsed', '==', 1)
      .get();

    // Count subscriptions due tomorrow
    const subscriptionsTomorrow = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', tomorrow)
      .where('nextBillingDate', '>', today)
      .where('status', '==', 'active')
      .where('isActive', '==', true)
      .where('trialUsed', '==', 1)
      .get();

    // Count monthly subscriptions due
    const monthlySubscriptions = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', today)
      .where('status', '==', 'active')
      .where('isActive', '==', true)
      .where('trialUsed', '==', 1)
      .where('planType', '==', 'monthly')
      .get();

    // Count yearly subscriptions due
    const yearlySubscriptions = await db.collection('subscriptions')
      .where('nextBillingDate', '<=', today)
      .where('status', '==', 'active')
      .where('isActive', '==', true)
      .where('trialUsed', '==', 1)
      .where('planType', '==', 'yearly')
      .get();

    return {
      subscriptionsDueToday: subscriptionsToday.docs.length,
      subscriptionsDueTomorrow: subscriptionsTomorrow.docs.length,
      monthlySubscriptionsDue: monthlySubscriptions.docs.length,
      yearlySubscriptionsDue: yearlySubscriptions.docs.length
    };
  } catch (error) {
    console.error('❌ Error getting renewal statistics:', error);
    return {
      subscriptionsDueToday: 0,
      subscriptionsDueTomorrow: 0,
      monthlySubscriptionsDue: 0,
      yearlySubscriptionsDue: 0
    };
  }
}
