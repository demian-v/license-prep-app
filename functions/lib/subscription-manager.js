"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSubscriptionStatistics = exports.testSubscriptionProcessing = exports.processExpiredSubscriptions = void 0;
const admin = __importStar(require("firebase-admin"));
// TODO: Uncomment when implementing real email sending
// import * as nodemailer from 'nodemailer';
// Function to get Firestore instance (ensures Firebase is initialized)
function getDb() {
    return admin.firestore();
}
/**
 * Main function to check and process all expired subscriptions
 * Called by the scheduled Cloud Function
 */
async function processExpiredSubscriptions() {
    console.log('🔍 Starting subscription expiration check...');
    const startTime = Date.now();
    const result = {
        totalProcessed: 0,
        expiredTrials: 0,
        expiredCanceledSubscriptions: 0,
        emailsSent: 0,
        errors: []
    };
    try {
        // Process expired trials
        const trialResult = await checkExpiredTrials();
        result.expiredTrials = trialResult.processed;
        result.emailsSent += trialResult.emailsSent;
        result.errors = result.errors.concat(trialResult.errors);
        // Process expired canceled subscriptions
        const canceledResult = await checkExpiredCanceledSubscriptions();
        result.expiredCanceledSubscriptions = canceledResult.processed;
        result.emailsSent += canceledResult.emailsSent;
        result.errors = result.errors.concat(canceledResult.errors);
        result.totalProcessed = result.expiredTrials + result.expiredCanceledSubscriptions;
        const duration = Date.now() - startTime;
        console.log(`✅ Subscription check completed in ${duration}ms`);
        console.log(`📊 Results: ${result.totalProcessed} processed, ${result.emailsSent} emails sent`);
        return result;
    }
    catch (error) {
        console.error('❌ Critical error in processExpiredSubscriptions:', error);
        result.errors.push(`Critical error: ${error instanceof Error ? error.message : String(error)}`);
        return result;
    }
}
exports.processExpiredSubscriptions = processExpiredSubscriptions;
/**
 * Check and process expired trials
 */
async function checkExpiredTrials() {
    console.log('🆓 Checking expired trials...');
    const result = { processed: 0, emailsSent: 0, errors: [] };
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
                const subscriptionData = { id: doc.id, ...doc.data() };
                // Update subscription status
                await updateExpiredTrial(subscriptionData);
                // Send notification email
                const emailSent = await sendTrialExpiredNotification(subscriptionData.userId);
                if (emailSent)
                    result.emailsSent++;
                // Log the change
                await logSubscriptionChange(subscriptionData, 'trial_expired');
                result.processed++;
                console.log(`✅ Processed expired trial for user: ${subscriptionData.userId}`);
            }
            catch (error) {
                const errorMsg = `Error processing trial ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
                console.error(`❌ ${errorMsg}`);
                result.errors.push(errorMsg);
            }
        }
        return result;
    }
    catch (error) {
        const errorMsg = `Error in checkExpiredTrials: ${error instanceof Error ? error.message : String(error)}`;
        console.error(`❌ ${errorMsg}`);
        result.errors.push(errorMsg);
        return result;
    }
}
/**
 * Check and process expired canceled subscriptions
 */
async function checkExpiredCanceledSubscriptions() {
    console.log('❌ Checking expired canceled subscriptions...');
    const result = { processed: 0, emailsSent: 0, errors: [] };
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
                const subscriptionData = { id: doc.id, ...doc.data() };
                // Update subscription status
                await updateExpiredCanceledSubscription(subscriptionData);
                // Send notification email
                const emailSent = await sendSubscriptionExpiredNotification(subscriptionData.userId);
                if (emailSent)
                    result.emailsSent++;
                // Log the change
                await logSubscriptionChange(subscriptionData, 'canceled_subscription_expired');
                result.processed++;
                console.log(`✅ Processed expired canceled subscription for user: ${subscriptionData.userId}`);
            }
            catch (error) {
                const errorMsg = `Error processing canceled subscription ${doc.id}: ${error instanceof Error ? error.message : String(error)}`;
                console.error(`❌ ${errorMsg}`);
                result.errors.push(errorMsg);
            }
        }
        return result;
    }
    catch (error) {
        const errorMsg = `Error in checkExpiredCanceledSubscriptions: ${error instanceof Error ? error.message : String(error)}`;
        console.error(`❌ ${errorMsg}`);
        result.errors.push(errorMsg);
        return result;
    }
}
/**
 * Update expired trial subscription in database
 */
async function updateExpiredTrial(subscriptionData) {
    console.log(`📝 Updating expired trial for subscription: ${subscriptionData.id}`);
    const db = getDb();
    await db.collection('subscriptions').doc(subscriptionData.id).update({
        isActive: false,
        status: 'inactive',
        trialUsed: 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Trial subscription ${subscriptionData.id} marked as expired`);
}
/**
 * Update expired canceled subscription in database
 */
async function updateExpiredCanceledSubscription(subscriptionData) {
    console.log(`📝 Updating expired canceled subscription: ${subscriptionData.id}`);
    const db = getDb();
    await db.collection('subscriptions').doc(subscriptionData.id).update({
        isActive: false,
        status: 'inactive',
        // Note: trialUsed stays as it was (1 for previously paid subscriptions)
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`✅ Canceled subscription ${subscriptionData.id} marked as expired`);
}
/**
 * Send trial expired notification email
 */
async function sendTrialExpiredNotification(userId) {
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
    }
    catch (error) {
        console.error(`❌ Error sending trial expired email to ${userId}:`, error);
        return false;
    }
}
/**
 * Send subscription expired notification email
 */
async function sendSubscriptionExpiredNotification(userId) {
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
    }
    catch (error) {
        console.error(`❌ Error sending subscription expired email to ${userId}:`, error);
        return false;
    }
}
/**
 * Get user data for email notifications
 */
async function getUserData(userId) {
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
    }
    catch (error) {
        console.error(`❌ Error getting user data for ${userId}:`, error);
        return null;
    }
}
/**
 * Log subscription change for audit trail
 */
async function logSubscriptionChange(subscriptionData, action) {
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
    }
    catch (error) {
        console.error(`❌ Error logging subscription change:`, error);
        // Don't throw error - logging failure shouldn't stop processing
    }
}
/**
 * Manual trigger function for testing
 * Can be called directly to test subscription processing
 */
async function testSubscriptionProcessing() {
    console.log('🧪 Manual test trigger for subscription processing');
    return await processExpiredSubscriptions();
}
exports.testSubscriptionProcessing = testSubscriptionProcessing;
/**
 * Get statistics about upcoming expirations
 * Useful for monitoring and alerts
 */
async function getSubscriptionStatistics() {
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
        // Count canceled subscriptions expiring today
        const canceledToday = await db.collection('subscriptions')
            .where('nextBillingDate', '<=', today)
            .where('status', '==', 'canceled')
            .where('isActive', '==', true)
            .get();
        // Count canceled subscriptions expiring tomorrow
        const canceledTomorrow = await db.collection('subscriptions')
            .where('nextBillingDate', '<=', tomorrow)
            .where('nextBillingDate', '>', today)
            .where('status', '==', 'canceled')
            .where('isActive', '==', true)
            .get();
        return {
            trialsExpiringToday: trialsToday.docs.length,
            trialsExpiringTomorrow: trialsTomorrow.docs.length,
            canceledExpiringToday: canceledToday.docs.length,
            canceledExpiringTomorrow: canceledTomorrow.docs.length
        };
    }
    catch (error) {
        console.error('❌ Error getting subscription statistics:', error);
        return {
            trialsExpiringToday: 0,
            trialsExpiringTomorrow: 0,
            canceledExpiringToday: 0,
            canceledExpiringTomorrow: 0
        };
    }
}
exports.getSubscriptionStatistics = getSubscriptionStatistics;
//# sourceMappingURL=subscription-manager.js.map