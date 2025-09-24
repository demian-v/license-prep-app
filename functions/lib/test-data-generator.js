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
exports.verifyTestData = exports.createQuickTestScenario = exports.cleanupTestData = exports.generateAllTestData = exports.generateTestSubscriptions = exports.generateTestUsers = void 0;
const admin = __importStar(require("firebase-admin"));
// Function to get Firestore instance (ensures Firebase is initialized)
function getDb() {
    return admin.firestore();
}
/**
 * Generate test users for subscription testing
 */
async function generateTestUsers() {
    const testUsers = [
        {
            id: 'test-user-trial-expired-en',
            name: 'John Trial Expired',
            email: 'john.trial@test.com',
            language: 'en'
        },
        {
            id: 'test-user-trial-expired-es',
            name: 'María Prueba Expirada',
            email: 'maria.prueba@test.com',
            language: 'es'
        },
        {
            id: 'test-user-trial-expired-uk',
            name: 'Олександр Тест',
            email: 'oleksandr.test@test.com',
            language: 'uk'
        },
        {
            id: 'test-user-trial-expired-ru',
            name: 'Александр Тест',
            email: 'aleksandr.test@test.com',
            language: 'ru'
        },
        {
            id: 'test-user-trial-expired-pl',
            name: 'Jan Test',
            email: 'jan.test@test.com',
            language: 'pl'
        },
        {
            id: 'test-user-subscription-expired-en',
            name: 'Jane Subscription Expired',
            email: 'jane.subscription@test.com',
            language: 'en'
        },
        {
            id: 'test-user-subscription-expired-es',
            name: 'Carlos Suscripción',
            email: 'carlos.suscripcion@test.com',
            language: 'es'
        },
        {
            id: 'test-user-active-trial',
            name: 'Alice Active Trial',
            email: 'alice.active@test.com',
            language: 'en'
        },
        {
            id: 'test-user-active-subscription',
            name: 'Bob Active Subscription',
            email: 'bob.active@test.com',
            language: 'en'
        },
        {
            id: 'test-user-trial-soon-expire',
            name: 'Charlie Soon Expire',
            email: 'charlie.soon@test.com',
            language: 'en'
        }
    ];
    console.log('Creating test users...');
    const db = getDb();
    const batch = db.batch();
    for (const user of testUsers) {
        const userRef = db.collection('users').doc(user.id);
        batch.set(userRef, {
            name: user.name,
            email: user.email,
            language: user.language,
            state: 'CA',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            isTestUser: true // Mark as test user for easy cleanup
        });
    }
    await batch.commit();
    console.log(`✅ Created ${testUsers.length} test users`);
    return testUsers;
}
exports.generateTestUsers = generateTestUsers;
/**
 * Generate test subscriptions with various expiration scenarios
 */
async function generateTestSubscriptions(testUsers) {
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
    const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);
    const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const oneWeekFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    const testSubscriptions = [
        // Expired trials (should be processed)
        {
            userId: 'test-user-trial-expired-en',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(oneHourAgo),
            planType: 'premium',
            packageId: 1,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000))
        },
        {
            userId: 'test-user-trial-expired-es',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(oneDayAgo),
            planType: 'premium',
            packageId: 1,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000))
        },
        {
            userId: 'test-user-trial-expired-uk',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(twoDaysAgo),
            planType: 'premium',
            packageId: 2,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000))
        },
        {
            userId: 'test-user-trial-expired-ru',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(oneHourAgo),
            planType: 'premium',
            packageId: 1,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000))
        },
        {
            userId: 'test-user-trial-expired-pl',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(oneDayAgo),
            planType: 'premium',
            packageId: 3,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 4 * 24 * 60 * 60 * 1000))
        },
        // Expired paid subscriptions (should be processed)
        {
            userId: 'test-user-subscription-expired-en',
            isActive: true,
            status: 'active',
            trialUsed: 1,
            nextBillingDate: admin.firestore.Timestamp.fromDate(oneHourAgo),
            planType: 'premium',
            packageId: 1,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000))
        },
        {
            userId: 'test-user-subscription-expired-es',
            isActive: true,
            status: 'active',
            trialUsed: 1,
            nextBillingDate: admin.firestore.Timestamp.fromDate(oneDayAgo),
            planType: 'premium',
            packageId: 2,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000))
        },
        // Active trial (should NOT be processed)
        {
            userId: 'test-user-active-trial',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(oneDayFromNow),
            planType: 'premium',
            packageId: 1,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000))
        },
        // Active paid subscription (should NOT be processed)
        {
            userId: 'test-user-active-subscription',
            isActive: true,
            status: 'active',
            trialUsed: 1,
            nextBillingDate: admin.firestore.Timestamp.fromDate(oneWeekFromNow),
            planType: 'premium',
            packageId: 2,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 45 * 24 * 60 * 60 * 1000))
        },
        // Trial expiring soon (should NOT be processed yet, but good for monitoring)
        {
            userId: 'test-user-trial-soon-expire',
            isActive: true,
            status: 'active',
            trialUsed: 0,
            trialEndsAt: admin.firestore.Timestamp.fromDate(oneHourFromNow),
            planType: 'premium',
            packageId: 1,
            createdAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000))
        }
    ];
    console.log('Creating test subscriptions...');
    const db = getDb();
    const batch = db.batch();
    for (const subscription of testSubscriptions) {
        // Generate unique subscription ID
        const subscriptionRef = db.collection('subscriptions').doc();
        batch.set(subscriptionRef, {
            ...subscription,
            id: subscriptionRef.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            isTestData: true // Mark as test data for easy cleanup
        });
    }
    await batch.commit();
    console.log(`✅ Created ${testSubscriptions.length} test subscriptions`);
    return testSubscriptions;
}
exports.generateTestSubscriptions = generateTestSubscriptions;
/**
 * Generate test data for subscription management system
 * Creates users and subscriptions with various expiration scenarios
 */
async function generateAllTestData() {
    console.log('🧪 Starting test data generation...');
    try {
        // Generate test users
        const testUsers = await generateTestUsers();
        // Generate test subscriptions
        const testSubscriptions = await generateTestSubscriptions(testUsers);
        // Calculate summary statistics
        const expiredTrials = testSubscriptions.filter(s => s.trialUsed === 0 &&
            s.trialEndsAt &&
            s.trialEndsAt.toDate() <= new Date()).length;
        const expiredPaidSubscriptions = testSubscriptions.filter(s => s.trialUsed === 1 &&
            s.nextBillingDate &&
            s.nextBillingDate.toDate() <= new Date()).length;
        const activeSubscriptions = testSubscriptions.filter(s => s.isActive &&
            s.status === 'active' &&
            ((s.trialUsed === 0 && s.trialEndsAt && s.trialEndsAt.toDate() > new Date()) ||
                (s.trialUsed === 1 && s.nextBillingDate && s.nextBillingDate.toDate() > new Date()))).length;
        const summary = {
            expiredTrials,
            expiredPaidSubscriptions,
            activeSubscriptions
        };
        console.log('✅ Test data generation completed successfully!');
        console.log('📊 Summary:');
        console.log(`   - Users created: ${testUsers.length}`);
        console.log(`   - Total subscriptions: ${testSubscriptions.length}`);
        console.log(`   - Expired trials: ${summary.expiredTrials}`);
        console.log(`   - Expired paid subscriptions: ${summary.expiredPaidSubscriptions}`);
        console.log(`   - Active subscriptions: ${summary.activeSubscriptions}`);
        return {
            users: testUsers,
            subscriptions: testSubscriptions,
            summary
        };
    }
    catch (error) {
        console.error('❌ Error generating test data:', error);
        throw error;
    }
}
exports.generateAllTestData = generateAllTestData;
/**
 * Clean up all test data from the database
 * Removes all users and subscriptions marked as test data
 */
async function cleanupTestData() {
    console.log('🧹 Starting test data cleanup...');
    try {
        let usersDeleted = 0;
        let subscriptionsDeleted = 0;
        let logsDeleted = 0;
        // Clean up test users
        console.log('Deleting test users...');
        const db = getDb();
        const testUsers = await db.collection('users')
            .where('isTestUser', '==', true)
            .get();
        if (!testUsers.empty) {
            const batch1 = db.batch();
            for (const doc of testUsers.docs) {
                batch1.delete(doc.ref);
                usersDeleted++;
            }
            await batch1.commit();
        }
        // Clean up test subscriptions
        console.log('Deleting test subscriptions...');
        const testSubscriptions = await db.collection('subscriptions')
            .where('isTestData', '==', true)
            .get();
        if (!testSubscriptions.empty) {
            const batch2 = db.batch();
            for (const doc of testSubscriptions.docs) {
                batch2.delete(doc.ref);
                subscriptionsDeleted++;
            }
            await batch2.commit();
        }
        // Clean up test subscription logs (optional)
        console.log('Deleting test subscription logs...');
        const testLogs = await db.collection('subscriptionLogs')
            .where('processedBy', '==', 'scheduled_function')
            .limit(100) // Limit to avoid timeout
            .get();
        if (!testLogs.empty) {
            const batch3 = db.batch();
            for (const doc of testLogs.docs) {
                batch3.delete(doc.ref);
                logsDeleted++;
            }
            await batch3.commit();
        }
        console.log('✅ Test data cleanup completed successfully!');
        console.log(`📊 Cleanup summary:`);
        console.log(`   - Users deleted: ${usersDeleted}`);
        console.log(`   - Subscriptions deleted: ${subscriptionsDeleted}`);
        console.log(`   - Logs deleted: ${logsDeleted}`);
        return {
            usersDeleted,
            subscriptionsDeleted,
            logsDeleted
        };
    }
    catch (error) {
        console.error('❌ Error cleaning up test data:', error);
        throw error;
    }
}
exports.cleanupTestData = cleanupTestData;
/**
 * Create a specific test scenario for immediate testing
 * Creates 1 user with 1 expired trial for quick verification
 */
async function createQuickTestScenario() {
    console.log('🚀 Creating quick test scenario...');
    const userId = `quick-test-user-${Date.now()}`;
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    // Create test user
    const db = getDb();
    await db.collection('users').doc(userId).set({
        name: 'Quick Test User',
        email: 'quick.test@test.com',
        language: 'en',
        state: 'CA',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        isTestUser: true
    });
    // Create expired trial subscription
    const subscriptionRef = db.collection('subscriptions').doc();
    await subscriptionRef.set({
        id: subscriptionRef.id,
        userId: userId,
        isActive: true,
        status: 'active',
        trialUsed: 0,
        trialEndsAt: admin.firestore.Timestamp.fromDate(oneHourAgo),
        planType: 'premium',
        packageId: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isTestData: true
    });
    console.log('✅ Quick test scenario created!');
    console.log(`   - User ID: ${userId}`);
    console.log(`   - Subscription ID: ${subscriptionRef.id}`);
    console.log(`   - Trial expired: ${oneHourAgo.toISOString()}`);
    return {
        userId,
        subscriptionId: subscriptionRef.id
    };
}
exports.createQuickTestScenario = createQuickTestScenario;
/**
 * Verify test data was created correctly
 * Returns statistics about current test data in the database
 */
async function verifyTestData() {
    console.log('🔍 Verifying test data...');
    const now = new Date();
    // Count total users
    const db = getDb();
    const allUsers = await db.collection('users').get();
    const totalUsers = allUsers.docs.length;
    // Count test users
    const testUsers = await db.collection('users')
        .where('isTestUser', '==', true)
        .get();
    const testUsersCount = testUsers.docs.length;
    // Count total subscriptions
    const allSubscriptions = await db.collection('subscriptions').get();
    const totalSubscriptions = allSubscriptions.docs.length;
    // Count test subscriptions
    const testSubscriptions = await db.collection('subscriptions')
        .where('isTestData', '==', true)
        .get();
    const testSubscriptionsCount = testSubscriptions.docs.length;
    // Count expired trials ready for processing
    const expiredTrials = await db.collection('subscriptions')
        .where('trialEndsAt', '<=', admin.firestore.Timestamp.fromDate(now))
        .where('trialUsed', '==', 0)
        .where('status', '==', 'active')
        .get();
    const expiredTrialsReady = expiredTrials.docs.length;
    // Count expired paid subscriptions ready for processing
    const expiredPaidSubscriptions = await db.collection('subscriptions')
        .where('nextBillingDate', '<=', admin.firestore.Timestamp.fromDate(now))
        .where('trialUsed', '==', 1)
        .where('status', '==', 'active')
        .get();
    const expiredSubscriptionsReady = expiredPaidSubscriptions.docs.length;
    const stats = {
        totalUsers,
        testUsers: testUsersCount,
        totalSubscriptions,
        testSubscriptions: testSubscriptionsCount,
        expiredTrialsReady,
        expiredSubscriptionsReady
    };
    console.log('📊 Test data verification results:');
    console.log(`   - Total users: ${stats.totalUsers} (${stats.testUsers} test users)`);
    console.log(`   - Total subscriptions: ${stats.totalSubscriptions} (${stats.testSubscriptions} test subscriptions)`);
    console.log(`   - Expired trials ready: ${stats.expiredTrialsReady}`);
    console.log(`   - Expired subscriptions ready: ${stats.expiredSubscriptionsReady}`);
    return stats;
}
exports.verifyTestData = verifyTestData;
//# sourceMappingURL=test-data-generator.js.map