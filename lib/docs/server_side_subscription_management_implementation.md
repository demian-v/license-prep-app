# Server-Side Subscription Management Implementation

## Overview
This document describes the comprehensive implementation of the server-side subscription management system for the License Prep App. The implementation provides automated subscription expiration processing, email notifications, audit logging, and comprehensive monitoring through Firebase Cloud Functions.

## Architecture Overview

### Server-Side Components
The Server-Side Subscription Management system implements a robust architecture that handles subscription lifecycle management automatically:

1. **⏰ Scheduled Processing**: Automated hourly checks for expired subscriptions
2. **📧 Email Notifications**: Multi-language email alerts for subscription changes
3. **📊 Audit Logging**: Comprehensive tracking of all subscription changes
4. **🔍 Monitoring**: System health checks and statistics
5. **🧪 Testing Framework**: Comprehensive test data generation and validation
6. **🎭 Mock Payment System**: Webhook simulation for development and testing

### Data Flow Architecture
```
Scheduled Function → Subscription Processing → Database Updates → Email Notifications → Audit Logging
       ↓                      ↓                     ↓                    ↓                ↓
[Every Hour]           [Expired Detection]      [Status Updates]    [User Alerts]    [System Logs]
       ↓                      ↓                     ↓                    ↓                ↓
[Auto Trigger]         [Trial/Paid Logic]       [Firebase Write]    [Mock Emails]    [Firestore]
       ↓                      ↓                     ↓                    ↓                ↓
[Cloud Scheduler]      [User Segmentation]      [Status: inactive]  [Multi-Language] [Monitoring]
```

### Multi-Tier Server Architecture
```
Cloud Scheduler: Automated triggers every hour
               ↓
Firebase Cloud Functions: Processing logic and business rules
               ↓
Subscription Manager: Core expiration detection and processing
               ↓
Email Templates: Multi-language notification system
               ↓
Database Layer: Firestore updates and audit logging
               ↓
Monitoring System: Health checks and statistics collection
```

## Firebase Functions Architecture

### 1. Deployed Functions Overview
**Purpose**: Complete server-side subscription management through Firebase Cloud Functions

#### Core Subscription Functions
```javascript
// Scheduled function - runs every hour
checkExpiredSubscriptions: {
  trigger: "Cloud Scheduler (every 1 hour)",
  purpose: "Main automated subscription processing",
  timezone: "America/Chicago",
  runtime: "Node.js 18",
  memory: "256MB",
  timeout: "540s"
}

// Manual processing function
processSubscriptionsManualy: {
  trigger: "HTTPS Callable",
  purpose: "Manual testing and emergency processing",
  authentication: "Required",
  runtime: "Node.js 18"
}

// Statistics and monitoring
getSubscriptionStats: {
  trigger: "HTTPS Callable", 
  purpose: "Get upcoming expiration statistics",
  authentication: "Required",
  runtime: "Node.js 18"
}

// System health monitoring
subscriptionSystemHealth: {
  trigger: "HTTPS Callable",
  purpose: "System health check and recent activity",
  authentication: "Required", 
  runtime: "Node.js 18"
}
```

#### Test Data Management Functions
```javascript
// Comprehensive test data generation
generateSubscriptionTestData: {
  trigger: "HTTPS Callable",
  purpose: "Create test users and subscriptions for testing",
  authentication: "Required",
  creates: "10 test users, 11 test subscriptions"
}

// Quick testing scenario
createQuickSubscriptionTest: {
  trigger: "HTTPS Callable", 
  purpose: "Create single expired trial for immediate testing",
  authentication: "Required",
  creates: "1 user + 1 expired subscription"
}

// Test data cleanup
cleanupSubscriptionTestData: {
  trigger: "HTTPS Callable",
  purpose: "Remove all test data from database", 
  authentication: "Required",
  cleanup: "Users, subscriptions, logs marked as test data"
}

// Test data verification
verifySubscriptionTestData: {
  trigger: "HTTPS Callable",
  purpose: "Get statistics about current test data",
  authentication: "Required",
  returns: "Count of test users/subscriptions"
}
```

#### Mock Payment System
```javascript
// Mock payment webhook handler
handleMockPaymentWebhook: {
  trigger: "HTTP Request", 
  purpose: "Simulate App Store/Google Play webhooks",
  method: "POST",
  url: "https://us-central1-licenseprepapp.cloudfunctions.net/handleMockPaymentWebhook",
  events: ["subscription_purchased", "subscription_renewed", "subscription_cancelled", "trial_started", "trial_expired"]
}
```

**Function Deployment Features**:
- **Auto-Scaling**: Functions scale automatically based on demand
- **Error Handling**: Comprehensive error catching and logging
- **Authentication**: All callable functions require user authentication
- **Monitoring**: Built-in Firebase monitoring and logging
- **Cloud Scheduler Integration**: Automatic scheduling with timezone support

### 2. Core Subscription Processing Logic (`functions/src/subscription-manager.ts`)
**Purpose**: Main processing engine for detecting and handling expired subscriptions

#### Main Processing Function
```typescript
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
    // Process expired trials (trialUsed: 0, trialEndsAt <= now, status: active)
    const trialResult = await checkExpiredTrials();
    result.expiredTrials = trialResult.processed;
    result.emailsSent += trialResult.emailsSent;
    result.errors = result.errors.concat(trialResult.errors);

    // Process expired paid subscriptions (trialUsed: 1, nextBillingDate <= now, status: active)  
    const paidResult = await checkExpiredPaidSubscriptions();
    result.expiredPaidSubscriptions = paidResult.processed;
    result.emailsSent += paidResult.emailsSent;
    result.errors = result.errors.concat(paidResult.errors);

    result.totalProcessed = result.expiredTrials + result.expiredPaidSubscriptions;
    
    return result;
  } catch (error) {
    console.error('❌ Critical error in processExpiredSubscriptions:', error);
    result.errors.push(`Critical error: ${error instanceof Error ? error.message : String(error)}`);
    return result;
  }
}
```

#### Expired Trial Processing
```typescript
async function checkExpiredTrials(): Promise<{processed: number, emailsSent: number, errors: string[]}> {
  console.log('🆓 Checking expired trials...');
  const result = { processed: 0, emailsSent: 0, errors: [] };

  try {
    const now = admin.firestore.Timestamp.now();
    
    // Query expired trials: trialEndsAt <= now, trialUsed = 0, status = active
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
        
        // 1. Update subscription status to inactive
        await updateExpiredTrial(subscriptionData);
        
        // 2. Send notification email (MOCK IMPLEMENTATION)
        const emailSent = await sendTrialExpiredNotification(subscriptionData.userId);
        if (emailSent) result.emailsSent++;
        
        // 3. Log the change for audit trail
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
```

#### Database Update Functions
```typescript
// Update expired trial subscription
async function updateExpiredTrial(subscriptionData: SubscriptionData): Promise<void> {
  console.log(`📝 Updating expired trial for subscription: ${subscriptionData.id}`);
  
  const db = getDb();
  await db.collection('subscriptions').doc(subscriptionData.id).update({
    isActive: false,           // Mark as inactive
    status: 'inactive',        // Set status to inactive
    trialUsed: 1,             // Mark trial as used (prevents reprocessing)
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`✅ Trial subscription ${subscriptionData.id} marked as expired`);
}

// Update expired paid subscription
async function updateExpiredPaidSubscription(subscriptionData: SubscriptionData): Promise<void> {
  console.log(`📝 Updating expired paid subscription: ${subscriptionData.id}`);
  
  const db = getDb();
  await db.collection('subscriptions').doc(subscriptionData.id).update({
    isActive: false,           // Mark as inactive
    status: 'inactive',        // Set status to inactive
    // Note: trialUsed stays as 1 (trial was already used)
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`✅ Paid subscription ${subscriptionData.id} marked as expired`);
}
```

**Subscription Manager Features**:
- **Dual Processing Logic**: Separate handling for trial vs. paid subscription expirations
- **Batch Processing**: Processes up to 100 expired subscriptions per run
- **Error Isolation**: Individual subscription errors don't stop batch processing
- **Audit Trail**: All subscription changes logged with timestamps and reasons
- **Performance Monitoring**: Execution time tracking and optimization

### 3. Email Notification System (`functions/src/email-templates.ts`)
**Purpose**: Multi-language email template system for subscription notifications

⚠️ **MOCK IMPLEMENTATION WARNING**: The current email system logs emails to console instead of sending real emails. This needs to be replaced with actual email service integration for production.

#### Email Template Structure
```typescript
interface EmailTemplate {
  subject: string;
  htmlContent: string;
  textContent: string;
}

interface LocalizedEmailTemplates {
  en: EmailTemplate;
  es: EmailTemplate;
  uk: EmailTemplate;
  ru: EmailTemplate;
  pl: EmailTemplate;
}
```

#### Trial Expired Email Templates
```typescript
export const TRIAL_EXPIRED_TEMPLATES: LocalizedEmailTemplates = {
  en: {
    subject: "Your License Prep App trial has expired",
    htmlContent: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
          <h1 style="color: white; margin: 0; font-size: 28px;">Trial Expired</h1>
        </div>
        <div style="background: #f8f9fa; padding: 30px; border-radius: 0 0 10px 10px;">
          <p>Hi there,</p>
          <p>Your 3-day free trial of License Prep App has ended. We hope you enjoyed exploring our comprehensive DMV practice tests and study materials!</p>
          <p><strong>Continue your DMV preparation with full access:</strong></p>
          <ul>
            <li>✅ Unlimited practice tests</li>
            <li>✅ 500+ practice questions</li>  
            <li>✅ Detailed explanations for every answer</li>
            <li>✅ Progress tracking and analytics</li>
            <li>✅ Offline study mode</li>
          </ul>
          <div style="text-align: center; margin: 30px 0;">
            <a href="https://licenseprepapp.com/subscribe" style="background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">Subscribe Now</a>
          </div>
          <p>Choose from flexible plans starting at $9.99/month.</p>
          <p>Best regards,<br>The License Prep App Team</p>
        </div>
      </div>
    `,
    textContent: `
Your License Prep App trial has expired

Hi there,

Your 3-day free trial of License Prep App has ended. We hope you enjoyed exploring our comprehensive DMV practice tests and study materials!

Continue your DMV preparation with full access:
✅ Unlimited practice tests
✅ 500+ practice questions  
✅ Detailed explanations for every answer
✅ Progress tracking and analytics
✅ Offline study mode

Choose from flexible plans starting at $9.99/month.

Subscribe now: https://licenseprepapp.com/subscribe

Best regards,
The License Prep App Team
    `
  },
  
  // Spanish template
  es: {
    subject: "Tu prueba gratuita de License Prep App ha expirado",
    htmlContent: `[Spanish HTML template with similar structure]`,
    textContent: `[Spanish plain text template]`
  },
  
  // Ukrainian template  
  uk: {
    subject: "Ваш безкоштовний пробний період License Prep App закінчився",
    htmlContent: `[Ukrainian HTML template with similar structure]`,
    textContent: `[Ukrainian plain text template]`
  },
  
  // Russian template
  ru: {
    subject: "Ваш бесплатный пробный период License Prep App истек",
    htmlContent: `[Russian HTML template with similar structure]`, 
    textContent: `[Russian plain text template]`
  },
  
  // Polish template
  pl: {
    subject: "Twój bezpłatny okres próbny License Prep App wygasł",
    htmlContent: `[Polish HTML template with similar structure]`,
    textContent: `[Polish plain text template]`
  }
};
```

#### Mock Email Sending Implementation ⚠️
```typescript
// MOCK IMPLEMENTATION - Replace with real email service for production
async function sendTrialExpiredNotification(userId: string): Promise<boolean> {
  try {
    console.log(`📧 Sending trial expired notification to user: ${userId}`);
    
    // Get user data for email personalization
    const userData = await getUserData(userId);
    if (!userData) {
      console.warn(`⚠️ User data not found for ${userId}, skipping email`);
      return false;
    }

    // MOCK EMAIL SENDING - Replace with real implementation
    console.log(`📨 MOCK EMAIL: Trial expired notification sent to ${userData.email}`);
    console.log(`   Subject: Your trial has expired`);
    console.log(`   Language: ${userData.language}`);
    console.log(`   Template: TRIAL_EXPIRED_TEMPLATES.${userData.language}`);
    
    // TODO: Replace with actual email service integration:
    // const template = TRIAL_EXPIRED_TEMPLATES[userData.language] || TRIAL_EXPIRED_TEMPLATES.en;
    // await emailService.sendEmail({
    //   to: userData.email,
    //   subject: template.subject,
    //   html: template.htmlContent,
    //   text: template.textContent
    // });
    
    return true; // Mock successful send
  } catch (error) {
    console.error(`❌ Error sending trial expired email to ${userId}:`, error);
    return false;
  }
}
```

**Email System Features (Current Mock Implementation)**:
- **Multi-Language Support**: Templates for 5 languages (EN, ES, UK, RU, PL)
- **Professional Design**: HTML emails with modern styling and branding
- **Personalization**: User name and language-specific content
- **Fallback Support**: Plain text versions for email clients that don't support HTML
- **Console Logging**: Mock emails logged to console for development testing
- **Error Handling**: Graceful handling of email failures

⚠️ **PRODUCTION REPLACEMENT REQUIRED**: Replace mock email sending with actual email service integration (see Production Considerations section).

### 4. Test Data Generation System (`functions/src/test-data-generator.ts`)
**Purpose**: Comprehensive test data creation for subscription management testing

#### Test Scenario Generation
```typescript
export async function generateAllTestData(): Promise<{
  users: TestUser[];
  subscriptions: TestSubscription[];
  summary: {
    expiredTrials: number;
    expiredPaidSubscriptions: number;
    activeSubscriptions: number;
  };
}> {
  console.log('🧪 Starting test data generation...');
  
  try {
    // Generate 10 test users with different languages
    const testUsers = await generateTestUsers();
    
    // Generate 11 test subscriptions covering various scenarios
    const testSubscriptions = await generateTestSubscriptions(testUsers);
    
    // Calculate summary statistics
    const expiredTrials = testSubscriptions.filter(s => 
      s.trialUsed === 0 && 
      s.trialEndsAt && 
      s.trialEndsAt.toDate() <= new Date()
    ).length;
    
    const expiredPaidSubscriptions = testSubscriptions.filter(s => 
      s.trialUsed === 1 && 
      s.nextBillingDate && 
      s.nextBillingDate.toDate() <= new Date()
    ).length;
    
    const activeSubscriptions = testSubscriptions.filter(s => 
      s.isActive && 
      s.status === 'active' &&
      ((s.trialUsed === 0 && s.trialEndsAt && s.trialEndsAt.toDate() > new Date()) ||
       (s.trialUsed === 1 && s.nextBillingDate && s.nextBillingDate.toDate() > new Date()))
    ).length;
    
    const summary = {
      expiredTrials,
      expiredPaidSubscriptions,
      activeSubscriptions
    };
    
    console.log('✅ Test data generation completed successfully!');
    console.log(`📊 Summary: ${summary.expiredTrials} expired trials, ${summary.expiredPaidSubscriptions} expired subscriptions, ${summary.activeSubscriptions} active`);
    
    return {
      users: testUsers,
      subscriptions: testSubscriptions,
      summary
    };
    
  } catch (error) {
    console.error('❌ Error generating test data:', error);
    throw error;
  }
}
```

#### Test User Creation
```typescript
async function generateTestUsers(): Promise<TestUser[]> {
  const testUsers: TestUser[] = [
    // Expired trial users (different languages for email testing)
    { id: 'test-user-trial-expired-en', name: 'John Trial Expired', email: 'john.trial@test.com', language: 'en' },
    { id: 'test-user-trial-expired-es', name: 'María Prueba Expirada', email: 'maria.prueba@test.com', language: 'es' },
    { id: 'test-user-trial-expired-uk', name: 'Олександр Тест', email: 'oleksandr.test@test.com', language: 'uk' },
    { id: 'test-user-trial-expired-ru', name: 'Александр Тест', email: 'aleksandr.test@test.com', language: 'ru' },
    { id: 'test-user-trial-expired-pl', name: 'Jan Test', email: 'jan.test@test.com', language: 'pl' },
    
    // Expired paid subscription users
    { id: 'test-user-subscription-expired-en', name: 'Jane Subscription Expired', email: 'jane.subscription@test.com', language: 'en' },
    { id: 'test-user-subscription-expired-es', name: 'Carlos Suscripción', email: 'carlos.suscripcion@test.com', language: 'es' },
    
    // Active users (should not be processed)
    { id: 'test-user-active-trial', name: 'Alice Active Trial', email: 'alice.active@test.com', language: 'en' },
    { id: 'test-user-active-subscription', name: 'Bob Active Subscription', email: 'bob.active@test.com', language: 'en' },
    { id: 'test-user-trial-soon-expire', name: 'Charlie Soon Expire', email: 'charlie.soon@test.com', language: 'en' }
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
      state: 'CA', // Default test state
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      isTestUser: true // Mark as test user for easy cleanup
    });
  }

  await batch.commit();
  console.log(`✅ Created ${testUsers.length} test users`);
  
  return testUsers;
}
```

#### Test Subscription Scenarios
```typescript
const testSubscriptions: TestSubscription[] = [
  // Expired trials (should be processed by server)
  {
    userId: 'test-user-trial-expired-en',
    isActive: true,
    status: 'active',
    trialUsed: 0, // Trial not yet marked as used
    trialEndsAt: admin.firestore.Timestamp.fromDate(oneHourAgo), // Expired 1 hour ago
    planType: 'premium',
    packageId: 1,
    createdAt: admin.firestore.Timestamp.fromDate(threeDaysAgo)
  },
  
  // Expired paid subscriptions (should be processed by server)
  {
    userId: 'test-user-subscription-expired-en',
    isActive: true,
    status: 'active',
    trialUsed: 1, // Trial already used
    nextBillingDate: admin.firestore.Timestamp.fromDate(oneHourAgo), // Billing expired 1 hour ago
    planType: 'premium',
    packageId: 1,
    createdAt: admin.firestore.Timestamp.fromDate(thirtyDaysAgo)
  },
  
  // Active subscriptions (should NOT be processed)
  {
    userId: 'test-user-active-trial',
    isActive: true,
    status: 'active',
    trialUsed: 0,
    trialEndsAt: admin.firestore.Timestamp.fromDate(oneDayFromNow), // Still active
    planType: 'premium',
    packageId: 1,
    createdAt: admin.firestore.Timestamp.fromDate(twoDaysAgo)
  }
];
```

**Test Data Features**:
- **Realistic Scenarios**: Covers all subscription states and edge cases
- **Multi-Language Testing**: Users with different language preferences for email testing
- **Time-Based Testing**: Various expiration times (past, present, future)
- **Clean Identification**: All test data marked with `isTestUser: true` and `isTestData: true`
- **Easy Cleanup**: Dedicated cleanup function removes all test data
- **Statistics Validation**: Provides counts of different subscription states

### 5. Monitoring and Health System
**Purpose**: System monitoring, statistics collection, and health checks

#### Subscription Statistics Function
```typescript
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
    const db = getDb();
    
    // Count trials expiring today
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
```

#### System Health Check Function
```typescript
export const subscriptionSystemHealth = functions.https.onCall(async (data, context) => {
  try {
    console.log('🏥 Health check for subscription system');
    
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required for system health check'
      );
    }
    
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    
    // Check recent system logs
    const recentLogs = await db.collection('systemLogs')
      .where('timestamp', '>', admin.firestore.Timestamp.fromDate(oneHourAgo))
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    
    // Check recent subscription logs
    const recentSubscriptionLogs = await db.collection('subscriptionLogs')
      .where('timestamp', '>', admin.firestore.Timestamp.fromDate(oneHourAgo))
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();
    
    // Get subscription statistics
    const stats = await getSubscriptionStatistics();
    
    const healthReport = {
      status: 'healthy',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      systemLogs: {
        count: recentLogs.docs.length,
        recentErrors: recentLogs.docs.filter(doc => doc.data().type?.includes('error')).length
      },
      subscriptionActivity: {
        recentChanges: recentSubscriptionLogs.docs.length,
        upcomingExpirations: stats
      },
      lastCheckedBy: context.auth.uid
    };
    
    console.log('✅ System health check completed');
    
    return {
      success: true,
      health: healthReport
    };
    
  } catch (error) {
    console.error('❌ Error in system health check:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'System health check failed: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});
```

**Monitoring Features**:
- **Proactive Statistics**: Real-time counts of upcoming expirations
- **Health Monitoring**: System status and error tracking
- **Activity Logs**: Recent subscription processing activity
- **Error Detection**: Automatic error counting and reporting
- **Administrative Access**: Authenticated access for system monitoring

## Mock Implementations That Need Production Replacement

### ⚠️ 1. Email Notification System
**Current Mock Implementation**:
```typescript
// MOCK - logs to console instead of sending emails
console.log(`📨 MOCK EMAIL: Trial expired notification sent to ${userData.email}`);
console.log(`   Subject: Your trial has expired`);
console.log(`   Language: ${userData.language}`);
```

**Production Replacement Required**:
```typescript
// Install email service dependency
// npm install nodemailer @sendgrid/mail mailgun-js

// Option A: SendGrid Integration
import * as sgMail from '@sendgrid/mail';
sgMail.setApiKey(process.env.SENDGRID_API_KEY!);

async function sendTrialExpiredNotification(userId: string): Promise<boolean> {
  try {
    const userData = await getUserData(userId);
    if (!userData) return false;
    
    const template = TRIAL_EXPIRED_TEMPLATES[userData.language] || TRIAL_EXPIRED_TEMPLATES.en;
    
    const msg = {
      to: userData.email,
      from: 'noreply@licenseprepapp.com', // Verified sender
      subject: template.subject,
      html: template.htmlContent,
      text: template.textContent
    };

    await sgMail.send(msg);
    console.log(`✅ Email sent to ${userData.email} via SendGrid`);
    return true;
    
  } catch (error) {
    console.error(`❌ Error sending email via SendGrid:`, error);
    return false;
  }
}

// Option B: Mailgun Integration
import * as mailgun from 'mailgun-js';
const mg = mailgun({
  apiKey: process.env.MAILGUN_API_KEY!,
  domain: process.env.MAILGUN_DOMAIN!
});

async function sendTrialExpiredNotification(userId: string): Promise<boolean> {
  try {
    const userData = await getUserData(userId);
    if (!userData) return false;
    
    const template = TRIAL_EXPIRED_TEMPLATES[userData.language] || TRIAL_EXPIRED_TEMPLATES.en;
    
    const data = {
      from: 'License Prep App <noreply@licenseprepapp.com>',
      to: userData.email,
      subject: template.subject,
      html: template.htmlContent,
      text: template.textContent
    };

    await mg.messages().send(data);
    console.log(`✅ Email sent to ${userData.email} via Mailgun`);
    return true;
    
  } catch (error) {
    console.error(`❌ Error sending email via Mailgun:`, error);
    return false;
  }
}

// Option C: Nodemailer with SMTP
import * as nodemailer from 'nodemailer';

const transporter = nodemailer.createTransporter({
  service: 'gmail', // or your SMTP service
  auth: {
    user: process.env.EMAIL_USER!,
    pass: process.env.EMAIL_PASSWORD!
  }
});

async function sendTrialExpiredNotification(userId: string): Promise<boolean> {
  try {
    const userData = await getUserData(userId);
    if (!userData) return false;
    
    const template = TRIAL_EXPIRED_TEMPLATES[userData.language] || TRIAL_EXPIRED_TEMPLATES.en;
    
    const mailOptions = {
      from: 'License Prep App <noreply@licenseprepapp.com>',
      to: userData.email,
      subject: template.subject,
      html: template.htmlContent,
      text: template.textContent
    };

    await transporter.sendMail(mailOptions);
    console.log(`✅ Email sent to ${userData.email} via SMTP`);
    return true;
    
  } catch (error) {
    console.error(`❌ Error sending email via SMTP:`, error);
    return false;
  }
}
```

**Email Service Integration Requirements**:
- **Domain Verification**: Configure SPF, DKIM, and DMARC records for email domain
- **API Keys**: Set up service credentials in Firebase Functions environment variables
- **Rate Limiting**: Implement email rate limiting to avoid service provider limits
- **Bounce Handling**: Monitor email bounces and handle invalid email addresses
- **Unsubscribe Links**: Add mandatory unsubscribe functionality for compliance

### ⚠️ 2. Environment Configuration
**Current Mock Implementation**:
```typescript
// Hardcoded configuration in functions
const createEmailTransporter = () => {
  return nodemailer.createTransporter({
    service: 'gmail',
    auth: {
      user: process.env.EMAIL_USER || 'noreply@yourapp.com',
      pass: process.env.EMAIL_PASSWORD || 'mock-password'
    }
  });
};
```

**Production Replacement Required**:
```bash
# Firebase Functions environment variables
firebase functions:config:set email.service="sendgrid"
firebase functions:config:set email.api_key="your-sendgrid-api-key"
firebase functions:config:set email.from_email="noreply@licenseprepapp.com"
firebase functions:config:set email.from_name="License Prep App"

# Or using .env file for local development
EMAIL_SERVICE=sendgrid
SENDGRID_API_KEY=your-api-key-here
MAILGUN_API_KEY=your-mailgun-key
MAILGUN_DOMAIN=mg.licenseprepapp.com
EMAIL_FROM=noreply@licenseprepapp.com
```

```typescript
// Production environment configuration
const emailConfig = {
  service: functions.config().email?.service || 'sendgrid',
  apiKey: functions.config().email?.api_key || process.env.SENDGRID_API_KEY,
  fromEmail: functions.config().email?.from_email || process.env.EMAIL_FROM,
  fromName: functions.config().email?.from_name || 'License Prep App'
};
```

### ⚠️ 3. Payment Webhook System
**Current Mock Implementation**:
```typescript
// Mock webhook that logs to console
export const handleMockPaymentWebhook = functions.https.onRequest(async (req, res) => {
  console.log('🎭 Mock payment webhook received');
  console.log('Method:', req.method);
  console.log('Headers:', req.headers);
  console.log('Body:', req.body);
  
  // Mock processing without real payment validation
  await db.collection('mockWebhookEvents').add({
    eventType: eventType,
    userId: userId,
    subscriptionData: subscriptionData || {},
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    source: 'mock_webhook'
  });
});
```

**Production Replacement Required**:
```typescript
// Real App Store webhook handler
export const handleAppStoreWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Verify App Store webhook signature
    const isValid = await verifyAppStoreSignature(req);
    if (!isValid) {
      console.error('❌ Invalid App Store webhook signature');
      res.status(401).send('Unauthorized');
      return;
    }

    const notification = req.body;
    const { notificationType, subtype, data } = notification;
    
    console.log(`📱 App Store webhook: ${notificationType} - ${subtype}`);
    
    switch (notificationType) {
      case 'SUBSCRIBED':
        await handleSubscriptionPurchased(data);
        break;
      case 'DID_RENEW':
        await handleSubscriptionRenewed(data);
        break;
      case 'EXPIRED':
        await handleSubscriptionExpired(data);
        break;
      case 'DID_CANCEL':
        await handleSubscriptionCancelled(data);
        break;
      default:
        console.log(`⚠️ Unhandled App Store notification: ${notificationType}`);
    }
    
    res.status(200).send('OK');
    
  } catch (error) {
    console.error('❌ Error processing App Store webhook:', error);
    res.status(500).send('Error');
  }
});

// Real Google Play webhook handler  
export const handleGooglePlayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Verify Google Play webhook signature
    const isValid = await verifyGooglePlaySignature(req);
    if (!isValid) {
      console.error('❌ Invalid Google Play webhook signature');
      res.status(401).send('Unauthorized');
      return;
    }

    const message = req.body.message;
    const data = JSON.parse(Buffer.from(message.data, 'base64').toString());
    const { subscriptionNotification, testNotification } = data;
    
    if (testNotification) {
      console.log('🧪 Google Play test notification received');
      res.status(200).send('OK');
      return;
    }
    
    if (subscriptionNotification) {
      const { notificationType, purchaseToken, subscriptionId } = subscriptionNotification;
      
      console.log(`🤖 Google Play webhook: ${notificationType}`);
      
      switch (notificationType) {
        case 1: // SUBSCRIPTION_RECOVERED
        case 2: // SUBSCRIPTION_RENEWED
          await handleGooglePlayRenewal(purchaseToken, subscriptionId);
          break;
        case 3: // SUBSCRIPTION_CANCELED
          await handleGooglePlayCancellation(purchaseToken, subscriptionId);
          break;
        case 13: // SUBSCRIPTION_EXPIRED
          await handleGooglePlayExpiration(purchaseToken, subscriptionId);
          break;
        default:
          console.log(`⚠️ Unhandled Google Play notification: ${notificationType}`);
      }
    }
    
    res.status(200).send('OK');
    
  } catch (error) {
    console.error('❌ Error processing Google Play webhook:', error);
    res.status(500).send('Error');
  }
});
```

**Webhook Integration Requirements**:
- **Signature Verification**: Validate webhook authenticity using platform-specific signatures
- **Receipt Validation**: Verify purchase receipts with App Store/Google Play APIs
- **Idempotency**: Handle duplicate webhook events gracefully
- **Error Handling**: Retry failed webhook processing with exponential backoff
- **Audit Logging**: Log all webhook events for compliance and debugging

### ⚠️ 4. Audit Logging Enhancement
**Current Mock Implementation**:
```typescript
// Basic console logging
async function logSubscriptionChange(
  subscriptionData: SubscriptionData,
  action: 'trial_expired' | 'subscription_expired'
): Promise<void> {
  try {
    const logEntry = {
      userId: subscriptionData.userId,
      subscriptionId: subscriptionData.id,
      action: action,
      // ... basic log data
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: 'scheduled_function',
      emailSent: true // Mock value
    };

    await db.collection('subscriptionLogs').add(logEntry);
    console.log(`📊 Logged subscription change: ${action} for ${subscriptionData.userId}`);
    
  } catch (error) {
    console.error(`❌ Error logging subscription change:`, error);
  }
}
```

**Production Enhancement Required**:
```typescript
// Enhanced audit logging with compliance features
interface AuditLogEntry {
  // Core identification
  userId: string;
  subscriptionId: string;
  sessionId?: string;
  
  // Action details
  action: 'trial_expired' | 'subscription_expired' | 'manual_update' | 'webhook_processed';
  source: 'scheduled_function' | 'manual_trigger' | 'webhook' | 'admin_panel';
  
  // State changes
  oldStatus: {
    isActive: boolean;
    status: string;
    trialUsed: number;
    expirationDate?: Date;
  };
  newStatus: {
    isActive: boolean;
    status: string;
    trialUsed: number;
    expirationDate?: Date;
  };
  
  // Processing details
  timestamp: admin.firestore.FieldValue;
  processedBy: string;
  processingTime: number;
  
  // Notification results
  emailSent: boolean;
  emailAddress?: string;
  emailLanguage?: string;
  emailError?: string;
  
  // Compliance and security
  ipAddress?: string;
  userAgent?: string;
  adminUserId?: string; // For manual changes
  
  // Technical metadata
  functionVersion: string;
  errorDetails?: string;
  retryCount?: number;
}

async function logSubscriptionChange(
  subscriptionData: SubscriptionData,
  action: AuditLogEntry['action'],
  oldStatus: AuditLogEntry['oldStatus'],
  newStatus: AuditLogEntry['newStatus'],
  processingDetails: {
    processingTime: number;
    emailSent: boolean;
    emailAddress?: string;
    emailLanguage?: string;
    emailError?: string;
  }
): Promise<void> {
  try {
    const logEntry: AuditLogEntry = {
      // Core identification
      userId: subscriptionData.userId,
      subscriptionId: subscriptionData.id,
      
      // Action details
      action: action,
      source: 'scheduled_function',
      
      // State changes
      oldStatus: oldStatus,
      newStatus: newStatus,
      
      // Processing details
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: 'server-side-manager-v1.0',
      processingTime: processingDetails.processingTime,
      
      // Notification results
      emailSent: processingDetails.emailSent,
      emailAddress: processingDetails.emailAddress,
      emailLanguage: processingDetails.emailLanguage,
      emailError: processingDetails.emailError,
      
      // Technical metadata
      functionVersion: process.env.FUNCTION_VERSION || '1.0.0'
    };

    // Store in multiple collections for different purposes
    const batch = db.batch();
    
    // Main audit log
    const auditRef = db.collection('subscriptionAuditLog').doc();
    batch.set(auditRef, logEntry);
    
    // Daily summary for analytics
    const today = new Date().toISOString().split('T')[0];
    const summaryRef = db.collection('dailySubscriptionSummary').doc(today);
    batch.update(summaryRef, {
      [`${action}_count`]: admin.firestore.FieldValue.increment(1),
      [`emails_sent_count`]: admin.firestore.FieldValue.increment(processingDetails.emailSent ? 1 : 0),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    await batch.commit();
    
    console.log(`📊 Enhanced audit log created for ${action}: ${subscriptionData.userId}`);
    
  } catch (error) {
    console.error(`❌ Error creating enhanced audit log:`, error);
    
    // Fallback to basic logging if enhanced logging fails
    try {
      await db.collection('subscriptionLogs').add({
        userId: subscriptionData.userId,
        action: action,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        error: 'Enhanced logging failed, using fallback'
      });
    } catch (fallbackError) {
      console.error(`❌ Fallback logging also failed:`, fallbackError);
    }
  }
}
```

## Database Schema Extensions

### 1. Enhanced Collections Structure
**Purpose**: Production-ready database schema with comprehensive audit trails

#### Subscription Audit Log Collection
```javascript
// Collection: subscriptionAuditLog
{
  userId: "user123",
  subscriptionId: "sub456", 
  action: "trial_expired",
  source: "scheduled_function",
  oldStatus: {
    isActive: true,
    status: "active",
    trialUsed: 0,
    expirationDate: "2025-09-19T21:04:01.722Z"
  },
  newStatus: {
    isActive: false,
    status: "inactive", 
    trialUsed: 1,
    expirationDate: "2025-09-19T21:04:01.722Z"
  },
  timestamp: "2025-09-19T22:15:30.123Z",
  processedBy: "server-side-manager-v1.0",
  processingTime: 245, // milliseconds
  emailSent: true,
  emailAddress: "user@example.com",
  emailLanguage: "en",
  functionVersion: "1.0.0"
}
```

#### Daily Summary Collection  
```javascript
// Collection: dailySubscriptionSummary
// Document ID: YYYY-MM-DD format
{
  date: "2025-09-19",
  trial_expired_count: 15,
  subscription_expired_count: 3,
  emails_sent_count: 17,
  processing_errors: 1,
  total_processing_time: 3420, // milliseconds
  unique_users_affected: 18,
  lastUpdated: "2025-09-19T23:59:45.123Z"
}
```

#### System Health Collection
```javascript
// Collection: systemHealth
// Document ID: timestamp or daily
{
  timestamp: "2025-09-19T22:00:00.000Z",
  functionExecutions: {
    checkExpiredSubscriptions: {
      executionCount: 24, // hourly executions per day
      avgExecutionTime: 1250, // milliseconds
      errorCount: 0,
      lastExecution: "2025-09-19T22:00:00.000Z"
    }
  },
  emailStats: {
    totalSent: 156,
    successRate: 98.7, // percentage
    bounceRate: 1.3,
    languageDistribution: {
      en: 89,
      es: 25,
      uk: 12,
      ru: 18,
      pl: 12
    }
  },
  subscriptionStats: {
    activeTrials: 234,
    activeSubscriptions: 1567,
    expiringSoon: 45 // within 24 hours
  }
}
```

### 2. Required Database Indexes
**Purpose**: Optimized query performance for subscription processing

#### Composite Indexes Required
```javascript
// Index 1: Expired trials query
{
  collectionGroup: "subscriptions",
  queryScope: "COLLECTION", 
  fields: [
    { fieldPath: "trialEndsAt", order: "ASCENDING" },
    { fieldPath: "trialUsed", order: "ASCENDING" },
    { fieldPath: "status", order: "ASCENDING" }
  ]
}

// Index 2: Expired subscriptions query
{
  collectionGroup: "subscriptions",
  queryScope: "COLLECTION",
  fields: [
    { fieldPath: "nextBillingDate", order: "ASCENDING" },
    { fieldPath: "trialUsed", order: "ASCENDING" },
    { fieldPath: "status", order: "ASCENDING" }
  ]
}

// Index 3: Audit log queries
{
  collectionGroup: "subscriptionAuditLog",
  queryScope: "COLLECTION",
  fields: [
    { fieldPath: "timestamp", order: "DESCENDING" },
    { fieldPath: "userId", order: "ASCENDING" }
  ]
}

// Index 4: System health monitoring
{
  collectionGroup: "subscriptionLogs", 
  queryScope: "COLLECTION",
  fields: [
    { fieldPath: "timestamp", order: "DESCENDING" },
    { fieldPath: "processedBy", order: "ASCENDING" }
  ]
}
```

## ProuDdde Dnpemymeed Guede

### 1. Envrirm
**Purpose**: Compl do prmdv pl do nvidin nircnnfiviaiura

#### FicPiasetPrujectation
```bash
# Sd c pcpeobFctisn Fisejesjct
tieiupeoto-rojec-d

# Cfifrisvit-nmen vaireo
fic-bdsfun:ofg:se
# mai.nvcevdgidriabes
fieai.p_kfyyoir nigond-kny
fiemael.f.of_ueasld epy@om
# imai.frm_ime="Ls P A
emweblook._se=r_smmyiurrli-se-peem
e_wklyook.go.gl._plfy_komslymr= googl -y@my-k"yA" \
wesystom.fun.ton_vessr"1.0.0e \
 t=yopem.evpr-mc=duto
  we.hfok.google_plam_key_ey"Li-googl -pay-ky
emDyplem.wit=tlroic-1.0.p ynf-gin"
fipebeyr tep eyo--utnfyffuoductioom" j\prdu
```emwelhook.go.gle_play_keronyme=-googl -peay-kpyA" \

w###eRuqst.edAAaIf and SSevvuic.s
```bash
# Enabon rnqbi_edvGaoglesolrud APIs0e \
rt=yepemnvvoc-sgelnc ddrulf noun.goglpis.com
gclond syrvigopoioebaegclond oud sprh.gligyegpns.coms com  igin"
firebagieovucdnfuoarlbub.googbpps.uum.goglep.om
gueIudgsSSvvcvc nnobln bie ssodc.google pos.coedsflobltoue.googleafnn.goms.com

#tSetgupcdmsieiseplico (cseoslsser)ilos eveae (uhuose one).googl bpps.uum.googleapis.com
##SendGenddGid:chsri:scd dcd.oom/il sepvice (choose one)il service (choose one)
##MngdGndGd: wwwmalgs.m/
# AWS#SES: Mgi.://wsamaz.u/s/wmalgn.m/
 Mig:s://aws.amazon.coh/sts/
#figurd/minwverif#for WmSil en#ig Mails://aws.amazon.cou/sns/w.mailgun.com/
# Add#SPFhrecornigev=tpf1tinclsdi efndgrii.:/wo~.maofor eme/l sedig
# Add#DKIM#rfcgdudoprKvddma#by  Aeil sMRvicoDMA#C1;#p=q acondd e; Rur=vailDoAd`r@yourdCalo.Mnm alert policies
##Add`DMARC`rerdv=DMARC;p=quarante;#rua=#ilto##rc@ynironmari.com"d AtertiinnSetupd Alerpingrostip
```yaml# Cloud "oniror ntnaleptrpciigci
# CloudiMonit_pisgeatplici
####cMonikoiingfn_drplcrpingeostsp
```ygmn
# flnud"nintneprpciigci
sbsct_pros_rrors:
ccondiiil"Ekorat>5%fosissgfuno"
"iyo,fi"cril""mi,ck"
vry:"iic"

ai_ivy_fails:
"mb ae>10%"
 siotiic""mal"
 svrity: "warin"

__time:
ccnniion:"Avegborcon0%>10sons"
 fc"m" otifictin:"mai"
evt"y:"wanig"

aily_pcs_volum
codo:"N 24ho"
notifia:"ema"l,black"funcni _cuton_me:
 svriy"A"crtca"
```
  notiicatin:"mal"
  se2eeStc:c tyuif guai
> 1Pro-aydetmasfuncton__time:
 cnotification"A"nmail"
busewn 0% > cgSncyREnhanmt
  oific:"m"  notification: "email"
ue_vro = '2';
evceicloyd.fir_sopeo{
iem_schl/daaas/{dabs}/documeg_{
     coEoo2oce"lume: ccscorl
cmatcdsubsctip:"osb{sbscpcrI}{
ssedt 4llof aoad:uif rt:s"st.euth!=uml&&a
nuksnio(:"ecure.iida"itAoure.dca.itrId||
**a hsAdmnRrps(rden.a-sh.ued));masues
##o```jrules_'```
lowwr:.uh!=nu&&
*ssrv*cf  ma        ma(reqdi t.ruea.uyd ==dreittfae.datn./{ordc||
rwptionIr}orursSystsmFunctiin(lequwst. u= )a||s.uth != nul&&
   hsAdmiRo(eest.uh.uid));
  }st.auth!=null &&
servicf  me    c   ma(r quest.busc.uidp== re"ource.dsba./{erIdb||
scripcAudtogprtcton
irnImadch}{subsc/ptioddoLog/{ogIo}n{
sselllw laooiahas:dmnRo(eque.auth.uidn|| (itque ".curh.iida"resoure.daa.usrId||
** hn ##o```hrMoouuthRole(oequesw.auth.uid);rite:i sSysmFunction(equest.auth)||
low wr ll:w wiie :sefri SyatemFunsinRo(equs.uh||icf  ma        ma(requ st.busc.uid ==preiource.daon./{erIdc||
rhsAdmnRol(iquyem. enh.ugd;tionId}       isSystemFunctiln(lequwst.auth)a||st.auth != null && 
             hsAdmiRo(equest.auth.uid));
   i}est.auth != null &&
    et Sy|tamhfa  hAmgng
  mtch /yst/mHah/{helhIH}efnctionhsAdmiRol(usId {   llow rad:i hasAdmnRo(eque.auth.uid ||
    n arlow   gd/ ifhhruMonhoeab(gRoo/(uequwat.auth.uu$);.uid);rite: if isSystemFunction(request.auth) ||
at b slhlowswn(du:i. eUsSynermuhng(request.uth);d))daaol == adm;
    }
} 
Helprfnctions
functohasAdmRole(userI functionasMoniongRoe(urI{
rn gyts/ngeab:hea/$(daabbsdocmenas/dmnUss $(sgfrId)).data.ro e(==h'aomin';
atab}oabngRos/(request.auth.ui$);
ase)tabass/low wrade:iin UsSysermuunction(request.auth);d)).data.role == 'admin';
/d}mftnon hssMadoUngRe(sId)({)).daa.l /ner'admin', 'monitor'];unction hasAdminRole(userId) function hasMonitoringRole(userId) {
     }returngut(/ngeabases/$(daeabas/)/$cumentscadminUsersu$(aseId)).ats.ro/in['adman','monUeos'];d)).data.role(==d'admin';
b}
e)/dunctionoisSystemFunction(auth)mftnction hssMonadorUngRose(usrsId)({)).data.role in ['admin', 'monitor'];
   }uunctionatsSyasemF/kc.=o=(nuoh) {
Userebreturneputh.sok/$.aud==e'yur-ctebas-p'ojct&id'&&&
        fireb'et ebasu-anmins k' in puut.toktk;==sdk'di'eauth.i k n;ins k' in auth.tok n;insdk' in auth.token;
    }
  }
}
```

#### FcncteyuCSccerniyiCynfi niatgonat onatgonation
```typescript/xEnhanoed authcntioansto fod adminofsnsbscrs futctions functions
//xEnhanoed authhnti(anst mfod admin huncttmn./fVeri(y adm!n euxtenh)caion
cxnorxuconodinPrhceswSssSubsc/ipns = futctions functions
 c.runWhdm({ timneutt h(n/s: 540g m moryi '512MB'm})540,amemsnyia'512MB' i)d (!admdnD:coxtirtRu|| admesDp.daa()?.le !== 'admin') {
  whttps.otCalp(a.ync (rata, contdbt).=> // Vrrifw('dminmnuthurgication').add({ons();
c  i//fVori(analm!n _ustuoh)ccssi
    if (!chntwxt.muta) {dmin.firesoe.FeldVue.vTimestamp()
#A    shAow/ncw/CunctnolrahttpR.Htt.sEir('unauhenth**Prk', 'AughecticaoiswRlquire);nt('useg-agent')
#}/`Execute`processing`withtadmin contextpescript
iconndb.urnrawaitf('adminUsers').dec(context.abth.cod).ge)();
  })//;Chk admin rl```//Logaminaction
a.ceosn('dmiaDoc=mnwug b.collci (''minnu').sc(coctxt.ounh.u_d).gst();ing'
#A##on (! dmdnDPcoxlirtRi||amsp.daa()?.le!== 'admin') {
**Pur ohrowsncw uuncesonA.hgvps.HttpsEeren('ptrm ss oc-otniee'ni'AdmiwRroleurequirein);et('useg-agent')alyticsgCount: number;
}# );ey Persormancn InTicmeorsu(KPIs)
```pesceipt
rntf//aLsg admina/Execcte psgcmesingiwinnemincntxt
 errawamtrb.urn wai('dminAcdLg').ad({ons();
});admnIt.uh.ui
```aatib'manoal_[key:Estring_pR:cnssing'
tmsampadmin.sirnsot.FeriVue.vTmbet;()
###3.pAndess Aconlxt.awReqiect.ip
**turausCtAgenenscenvext. nwRequemm.gnt('uumg-agnt') SystemBhnaethrics
naEpn);atytmc:tUttCountnunumber;er;
 lertCount: number;
###}//`Execut`rcessg`withtamin conttpcrip
nteturnrawit/pai esPExpctIaSl();
tn});
```
PxIcrtlclast calculateDaitiKPIs =onunct ts.pububexport const calculateDailyKPIs = functions.pubsub
## /3./.sche'uingla('PAna*'/*ilt 1 AM
**Purimsm**mrcempe(hia/iv'gsymmonR(ainghcndob(sPnrecianalynixs=Ct:umr; const today = new Date();
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000);
    KyPersomncITcmrsu(KPIs
    ype/ceiptCalculate processing metrics
rnt ocnbscripsionKPs{
  //ePrtcessingr errocs
rohourlyProcsssingCgunt:rnuebtr;
Ri vgProcess=ngTamnnmbet;
  rrRcal: numb;

c//EmaulmPtricr
ecigDsve(yRyumeer;
 rmaB;ucRnumb;
/languageDistribuin:/{[key:Estrngm:numerm;lDivyRa:umbr;
emi BounaeRate:eeumbar;metrics
 c//lBuninsssam trics
ngtriaDEepirmirenRatt:cbu= et;
 {[key: strinnRetegta:wRaie: number;ber };
c cvrciltFmTrialREtnummlr;Metrics(yesterday);

////SysemBnathrics
EprunaonUpumb:nub;
pnabsePeemn:m:umb; Systmheah    const businessMetrics = await calculateBusinessMetrics(yesterday);
  atUttCuntnunmer;er;
 rtCun: mbr;
}    // Store KPIs
//aicKoKcalculatdfuncin(yesterday.toISOString().split('T')[0]).set({
 xIc tdnlas.scolcueateDaimiKars=onctts.pububport cmnsaic:lc latmDMietKPI  =alculateds.pubsub
At.ache'ul0('0d1.* * *') //1Drt*y*i/ 1 AMDValy at 1 AMe.serverTimestamp()
  .mnm Zc)('Amrica/Ch'ca')
 .Run(asnc(ont) => {
    ct today = new Date();
    censtdy steddayy= nrw Dote(today.rttT mt() - 24 * 60 * 60 * 1000);keholders
 te 
    // CalnulatD Rpocossing met(pcc
sii constepsocssstngMitriccs=awatlulProcessngMtics(yterday);
    );
   // Caclae emalmtric
#is conse emmilMeric=awaicculatEmalMetics(yrday);
  
`   // Calculatepbusnssmtics
   cotbusssMtric=waicculateBusnessMercs(yesday);
 
    // Soe KPI
    rwat tsb.cnnloctifi('dailyKPos'). oc(ysteerdmy.oISOString().plit('T')[0]).e({
    dt:amfirestore imALEamp._romDaTH(yL t{ra),
process:Op_ocIss0, MLtOUcs,E_RATE: 0.10, // 10%
NPENsoemail:iemgilMtics,
     bsinssbusinssMcs,
      cculate:admifisoe.FeldVusvrTimemp()
  };
    
    Sedailyrporto takholrs
    waendDilyReporprocssngMecs, emiMeics, busissMetrics;
  });
async function checkSystemHealth(): Promise<void> {
  const now = new Date();
  c#oAogntingeSy ttm(now.getTime() - 60 * 60 * 1000);
```typescipt
// Arttrshols annotiiasysm
ons ALERT_THRESHOLDS={
  ERROR_RATE: 0.05, // 5%  // Check recent errors
nrPROCESrING_TIME: 10000, // 10 srcond = await db.collection('subscriptionAuditLog')
  EMAIL_BOUNCE_RATE: 0.10, // 10%ere('timestamp', '>', admin.firestore.Timestamp.fromDate(oneHourAgo))
  NO_PRO ESSING_HOURS: 4 // 4e(orrsDwithtutiprocel'ing
};
!=', null)
asyn efntonytemHealth(): Pomse<vod> {
  ct now = nw Dae();
 cns eHourAgo  new Dat(ow.geTime() - 60 * 60 * 000);
    
  // Chnckt errorRercsrsize / Math.max(1, recentErrors.size);
   nstrentErr =awadb.cole('sbipndAlAuditLt(')
  H_.wRAr'('tim samp', '>', adm.    etore.Timrstamp.oromDate(: eHourAro))
  R.we('rroDeal','!=',nl)
    .get();   threshold: ALERT_THRESHOLDS.ERROR_RATE,
        timeWindow: '1 hour'
}ct rrrRat=rntErros.s /M.max(1,rnErrrs.sz);
  
  if (rrorRe >ALERT_THRESHOLDS.ERROR_RAT) {
   awaiseArt('HIGH_ERROR_RATE', {
     errorRe: rrorR,
    theol: ALERT_THRESHOLDS.ERROR_RATE,
      cimeWknd w:r'1nh ui'
    });
  }
  
  //iCckpocsingativiy
 strectPrcessg = awai db.collsctien('sobsccipssinAuditLog')
  .t.whirn('sumectamp', '>',radmii.firtstone.TimAsuamp.fdomD(oeHourAgo))    .where('timestamp', '>', admin.firestore.Timestamp.fromDate(oneHourAgo))
 e.gt();

  if (enPig.pty){  if (recentProcessing.empty) {
    await sendAlert('NO_RECENT_PROCESSING', {
      lastProcessing: oneHourAgo,
      threshold: ALERT_THRESHOLDS.NO_PROCESSING_HOURS
    });
  }
}

async function sendAlert(alertType: string, details: any): Promise<void> {
  // Send to monitoring service (e.g., PagerDuty, Slack, email)
  const alertData = {
    type: alertType,
    severity: 'high',
    details: details,
    timestamp: new Date().toISOString(),
    service: 'subscription-management'
  };
  
  // Store alert for tracking
  await db.collection('systemAlerts').add(alertData);
  
  // Send notifications (implement based on your notification system)
  await sendSlackAlert(alertData);
  await sendEmailAlert(alertData);
}
```

## Testing and Validation

### 1. Comprehensive Testing Strategy
**Purpose**: Ensure system reliability through thorough testing

#### Unit Test Coverage
```typescript
// Test file: functions/test/subscription-manager.test.ts
import { processExpiredSubscriptions, checkExpiredTrials } from '../src/subscription-manager';
import * as admin from 'firebase-admin';
import { expect } from 'chai';

describe('Subscription Manager', () => {
  let testApp: admin.app.App;
  let db: admin.firestore.Firestore;

  beforeEach(async () => {
    // Initialize test Firebase app
    testApp = admin.initializeApp({
      projectId: 'test-project'
    }, 'test');
    db = testApp.firestore();
  });

  afterEach(async () => {
    // Cleanup
    await testApp.delete();
  });

  describe('processExpiredSubscriptions', () => {
    it('should process expired trials correctly', async () => {
      // Create test data
      await createTestSubscription({
        userId: 'test-user-1',
        trialEndsAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000)), // 1 hour ago
        trialUsed: 0,
        status: 'active',
        isActive: true
      });

      // Execute processing
      const result = await processExpiredSubscriptions();

      // Verify results
      expect(result.expiredTrials).to.equal(1);
      expect(result.totalProcessed).to.equal(1);
      expect(result.emailsSent).to.equal(1);
      expect(result.errors).to.be.empty;

      // Verify database changes
      const updatedSubscription = await db.collection('subscriptions')
        .where('userId', '==', 'test-user-1')
        .get();
      
      const subData = updatedSubscription.docs[0].data();
      expect(subData.isActive).to.be.false;
      expect(subData.status).to.equal('inactive');
      expect(subData.trialUsed).to.equal(1);
    });

    it('should handle processing errors gracefully', async () => {
      // Create malformed test data
      await createMalformedTestSubscription();

      // Execute processing
      const result = await processExpiredSubscriptions();

      // Verify error handling
      expect(result.errors).to.not.be.empty;
      expect(result.errors[0]).to.contain('Error processing');
    });

    it('should not process active subscriptions', async () => {
      // Create active subscription
      await createTestSubscription({
        userId: 'test-user-2',
        trialEndsAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 86400000)), // 1 day in future
        trialUsed: 0,
        status: 'active',
        isActive: true
      });

      // Execute processing
