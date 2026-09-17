import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
// firebase-tools' Functions emulator stubs `firebase-admin` behind a Proxy and
// returns `admin.firestore` through Function.prototype.bind, which drops the
// statics hanging off it (FieldValue, Timestamp, FieldPath). Every
// `admin.firestore.FieldValue.serverTimestamp()` therefore threw "Cannot read
// properties of undefined" under the emulator while working fine in production,
// so local signup never wrote a user document. The modular import below is the
// same object in both places and is not proxied.
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { requireEntitledUser, requireAdmin } from './entitlement';
import { applyToAllMatches } from './webhook-fanout';
import { mapPlayNotification, PLAY_NOTIFICATION } from './play-notifications';
import { recordWebhookFailure } from './webhook-dead-letter';
import { anonymizeTrialDevicesForUser } from './trial-devices';
import { collectUserDataForDeletion, applyDeletionPlan, assertRecentLogin } from './account-deletion';
import { readContentVersion } from './content-version';
import { sweepPaginated, SWEEP_TIME_BUDGET_MS } from './sweep';
import {
  retentionCutoff,
  isRetentionEnabled,
  WEBHOOK_DEDUP_RETENTION_DAYS,
  SUBSCRIPTION_LOG_RETENTION_DISABLED,
} from './retention';
import * as fs from 'fs';
import * as path from 'path';
import { defineInt, defineSecret } from 'firebase-functions/params';
import {
  SignedDataVerifier,
  Environment,
  NotificationTypeV2,
  AutoRenewStatus,
} from '@apple/app-store-server-library';
import { google } from 'googleapis';
import { 
  processExpiredSubscriptions, 
  testSubscriptionProcessing,
  getSubscriptionStatistics 
} from './subscription-manager';
import { 
  processActiveSubscriptionRenewals,
  getRenewalStatistics 
} from './subscription-renewal-manager';
import { validatePurchaseReceipt } from './receipt-validation';

// Initialize Firebase Admin
admin.initializeApp();

// Get Firestore reference
const db = admin.firestore();

// Google credentials secret — same secret used by receipt-validation.ts
const googleCredentials = defineSecret('GOOGLE_CREDENTIALS');

// Apple numeric App ID — set via: firebase functions:params:set APPLE_APP_ID="YOUR_NUMERIC_ID"
// Found in: App Store Connect → Your App → General → App Information → Apple ID
const appleAppId = defineInt('APPLE_APP_ID', { default: 0 });

// Risk #40 — how many days of subscriptionLogs to keep. Zero (the default)
// keeps everything. This is the money-state audit trail and risk #4 was a job
// that deleted rows out of it by accident, so pruning it is opt-in and the
// number is an operator's decision, not a default anyone inherits.
const subscriptionLogRetentionDays = defineInt('SUBSCRIPTION_LOG_RETENTION_DAYS', {
  default: SUBSCRIPTION_LOG_RETENTION_DISABLED,
});

// VERIFY this bundle ID matches App Store Connect before deploying.
// If wrong, ALL webhook verifications fail silently (caught → 200, no processing).
const APPLE_BUNDLE_ID = 'com.driveusa.app';

// ⚠️  Path: __dirname = functions/lib at runtime (tsconfig outDir:"lib", rootDir:"src")
// functions/lib/../certs/ = functions/certs/  — ONE "../" not two "../../"
const appleRootCAs: Buffer[] = [
  fs.readFileSync(path.join(__dirname, '../certs/AppleRootCA-G3.cer')),
];

// Content functions
export const getQuizTopics = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('getQuizTopics called with data:', data);
    
    // Validate required parameters
    const { language, state, limit = 10 } = data;
    
    if (!language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: language and state are required'
      );
    }

    console.log(`Fetching quiz topics for language: ${language}, state: ${state}, limit: ${limit}`);

    // Query Firestore for quiz topics
    let query = db.collection('quizTopics')
      .where('language', '==', language)
      .where('state', '==', state)
      .orderBy('order');

    if (limit && limit > 0) {
      query = query.limit(limit);
    }

    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.docs.length} quiz topics`);

    // Process results
    const topics = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: data.id || doc.id,
        title: data.title || 'Untitled Topic',
        questionCount: data.questionCount || 0,
        progress: data.progress || 0.0,
        questionIds: data.questionIds || [],
        language: data.language,
        state: data.state,
        order: data.order || 0
      };
    });

    console.log(`Returning ${topics.length} processed topics`);
    return topics;

  } catch (error) {
    console.error('Error in getQuizTopics:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch quiz topics: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Alternative function name with content prefix (in case the mapping expects this)
export const contentGetQuizTopics = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('contentGetQuizTopics called with data:', data);
    
    // Validate required parameters
    const { language, state, limit = 10 } = data;
    
    if (!language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: language and state are required'
      );
    }

    console.log(`Fetching quiz topics for language: ${language}, state: ${state}, limit: ${limit}`);

    // Query Firestore for quiz topics
    let query = db.collection('quizTopics')
      .where('language', '==', language)
      .where('state', '==', state)
      .orderBy('order');

    if (limit && limit > 0) {
      query = query.limit(limit);
    }

    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.docs.length} quiz topics`);

    // Process results
    const topics = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: data.id || doc.id,
        title: data.title || 'Untitled Topic',
        questionCount: data.questionCount || 0,
        progress: data.progress || 0.0,
        questionIds: data.questionIds || [],
        language: data.language,
        state: data.state,
        order: data.order || 0
      };
    });

    console.log(`Returning ${topics.length} processed topics`);
    return topics;

  } catch (error) {
    console.error('Error in contentGetQuizTopics:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch quiz topics: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Quiz Questions function
export const getQuizQuestions = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('getQuizQuestions called with data:', data);
    
    // Validate required parameters
    const { topicId, language, state } = data;
    
    if (!topicId || !language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: topicId, language, and state are required'
      );
    }

    console.log(`Fetching quiz questions for topicId: ${topicId}, language: ${language}, state: ${state}`);

    // First try with all filters, then fall back if composite index is missing
    let snapshot;
    try {
      // Try the most specific query first
      snapshot = await db.collection('quizQuestions')
        .where('topicId', '==', topicId)
        .where('language', '==', language)
        .where('state', '==', state)
        .get();
    } catch (indexError) {
      console.log('Trying fallback query strategy due to index error:', indexError);
      
      // Fallback: query by topicId only, then filter manually
      snapshot = await db.collection('quizQuestions')
        .where('topicId', '==', topicId)
        .get();
    }
    
    console.log(`Found ${snapshot.docs.length} quiz questions before filtering`);

    // Process and filter results
    const questions = snapshot.docs
      .map(doc => {
        const data = doc.data();
        
        // Handle different correct answer field names in Firestore
        let correctAnswer = data.correctAnswer;
        if (!correctAnswer && data.correctAnswerString) {
          correctAnswer = data.correctAnswerString;
        }
        if (!correctAnswer && data.correctAnswers) {
          correctAnswer = data.correctAnswers;
        }
        
        // Ensure we have a valid correct answer
        if (!correctAnswer) {
          console.warn(`Question ${data.id || doc.id} has no correct answer!`);
        }
        
        return {
          id: data.id || doc.id,
          topicId: data.topicId,
          questionText: data.questionText || '',
          options: data.options || [],
          correctAnswer: correctAnswer,
          explanation: data.explanation || '',
          ruleReference: data.ruleReference || '',
          imagePath: data.imagePath || null, // Allow null for missing images
          type: data.type || 'singleChoice',
          language: data.language,
          state: data.state,
          order: data.order || 0
        };
      })
      .filter(question => {
        // Manual filtering to ensure exact matches
        const languageMatch = question.language === language;
        const stateMatch = question.state === state || question.state === 'ALL';
        console.log(`Question ${question.id}: language=${question.language} (${languageMatch}), state=${question.state} (${stateMatch})`);
        return languageMatch && stateMatch;
      })
      .sort((a, b) => (a.order || 0) - (b.order || 0)); // Sort by order manually

    console.log(`Returning ${questions.length} processed and filtered questions`);
    return questions;

  } catch (error) {
    console.error('Error in getQuizQuestions:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch quiz questions: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Traffic Rule Topics function
export const getTrafficRuleTopics = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('getTrafficRuleTopics called with data:', data);
    
    // Validate required parameters
    const { language, state, limit = 10 } = data;
    
    if (!language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: language and state are required'
      );
    }

    console.log(`Fetching traffic rule topics for language: ${language}, state: ${state}`);

    // Query Firestore for traffic rule topics
    let query = db.collection('trafficRuleTopics')
      .where('language', '==', language)
      .where('state', '==', state)
      .orderBy('order');

    if (limit && limit > 0) {
      query = query.limit(limit);
    }

    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.docs.length} traffic rule topics`);

    // Process results
    const topics = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: data.id || doc.id,
        title: data.title || 'Untitled Topic',
        content: data.content || '',  // Keep for compatibility
        sections: data.sections || [],  // ✅ ADD sections field
        language: data.language,
        state: data.state,
        licenseId: data.licenseId || 'driver',  // ✅ ADD licenseId field
        order: data.order || 0
      };
    });

    console.log(`Returning ${topics.length} processed traffic rule topics`);
    return topics;

  } catch (error) {
    console.error('Error in getTrafficRuleTopics:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch traffic rule topics: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Theory Modules function
export const getTheoryModules = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('getTheoryModules called with data:', data);
    
    // Validate required parameters
    const { licenseType, language, state } = data;
    
    if (!licenseType || !language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: licenseType, language, and state are required'
      );
    }

    console.log(`Fetching theory modules for licenseType: ${licenseType}, language: ${language}, state: ${state}`);

    // First try with all filters, then fall back if composite index is missing
    let snapshot;
    try {
      // Try the most specific query first
      snapshot = await db.collection('theoryModules')
        .where('licenseId', '==', licenseType)
        .where('language', '==', language)
        .where('state', 'in', [state, 'ALL'])
        .get();
    } catch (indexError) {
      console.log('Trying fallback query strategy due to index error:', indexError);
      
      // Fallback: query by licenseId and language only, then filter manually
      snapshot = await db.collection('theoryModules')
        .where('licenseId', '==', licenseType)
        .where('language', '==', language)
        .get();
    }
    
    console.log(`Found ${snapshot.docs.length} theory modules before filtering`);

    // Process and filter results
    const modules = snapshot.docs
      .map(doc => {
        const data = doc.data();
        
        return {
          id: data.id || doc.id,
          licenseId: data.licenseId,
          title: data.title || 'Untitled Module',
          description: data.description || '',
          estimatedTime: data.estimatedTime || 30,
          topics: data.topics || [],
          language: data.language,
          state: data.state,
          icon: data.icon || 'menu_book',
          type: data.type || 'module',
          order: data.order || 0,
          theory_modules_count: data.theory_modules_count || '0' // Add module count from database
        };
      })
      .filter(module => {
        // Manual filtering to ensure exact matches
        const languageMatch = module.language === language;
        const stateMatch = module.state === state || module.state === 'ALL';
        return languageMatch && stateMatch;
      })
      .sort((a, b) => (a.order || 0) - (b.order || 0)); // Sort by order manually

    console.log(`Returning ${modules.length} processed and filtered theory modules`);
    return modules;

  } catch (error) {
    console.error('Error in getTheoryModules:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch theory modules: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Practice Questions function
export const getPracticeQuestions = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('getPracticeQuestions called with data:', data);
    
    // Validate required parameters
    const { language, state, count = 40 } = data;
    
    if (!language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: language and state are required'
      );
    }

    console.log(`Fetching practice questions for language: ${language}, state: ${state}, count: ${count}`);

    // Query Firestore for practice questions
    let snapshot;
    try {
      // Try the most specific query first
      snapshot = await db.collection('quizQuestions')
        .where('language', '==', language)
        .where('state', 'in', [state, 'ALL'])
        .get();
    } catch (indexError) {
      console.log('Trying fallback query strategy due to index error:', indexError);
      
      // Fallback: query by language only, then filter manually
      snapshot = await db.collection('quizQuestions')
        .where('language', '==', language)
        .get();
    }
    
    console.log(`Found ${snapshot.docs.length} questions before filtering and shuffling`);

    // Process and filter results
    const allQuestions = snapshot.docs
      .map(doc => {
        const data = doc.data();
        
        // Handle different correct answer field names in Firestore
        let correctAnswer = data.correctAnswer;
        if (!correctAnswer && data.correctAnswerString) {
          correctAnswer = data.correctAnswerString;
        }
        if (!correctAnswer && data.correctAnswers) {
          correctAnswer = data.correctAnswers;
        }
        
        // Ensure we have a valid correct answer
        if (!correctAnswer) {
          console.warn(`Question ${data.id || doc.id} has no correct answer!`);
        }
        
        return {
          id: data.id || doc.id,
          topicId: data.topicId || '',
          questionText: data.questionText || '',
          options: data.options || [],
          correctAnswer: correctAnswer,
          correctAnswerString: data.correctAnswerString, // Keep for compatibility
          explanation: data.explanation || '',
          ruleReference: data.ruleReference || '',
          imagePath: data.imagePath || null,
          type: data.type || 'singleChoice',
          language: data.language,
          state: data.state
        };
      })
      .filter(question => {
        // Manual filtering to ensure exact matches
        const languageMatch = question.language === language;
        const stateMatch = question.state === state || question.state === 'ALL';
        return languageMatch && stateMatch;
      });

    console.log(`After filtering: ${allQuestions.length} questions available`);

    // Server-side shuffle for better randomization
    const shuffled = allQuestions.sort(() => 0.5 - Math.random());
    
    // Limit to requested count
    const limited = shuffled.slice(0, Math.min(count, shuffled.length));
    
    console.log(`Returning ${limited.length} questions after shuffle and limit`);
    return limited;

  } catch (error) {
    console.error('Error in getPracticeQuestions:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch practice questions: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Practice Tests function
export const getPracticeTests = functions.https.onCall(async (data, context) => {
  // Risk #3 — server-side entitlement gate. Placed before the try block
  // so its HttpsError cannot be reshaped by the catch below.
  await requireEntitledUser(context);

  try {
    console.log('getPracticeTests called with data:', data);
    
    // Validate required parameters
    const { licenseType, language, state, limit = 10 } = data;
    
    if (!licenseType || !language || !state) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required parameters: licenseType, language, and state are required'
      );
    }

    console.log(`Fetching practice tests for licenseType: ${licenseType}, language: ${language}, state: ${state}`);

    // Query Firestore for practice tests
    let query = db.collection('practiceTests')
      .where('licenseId', '==', licenseType)
      .where('language', '==', language)
      .where('state', 'in', [state, 'ALL'])
      .orderBy('order');

    if (limit && limit > 0) {
      query = query.limit(limit);
    }

    const snapshot = await query.get();
    
    console.log(`Found ${snapshot.docs.length} practice tests`);

    // Process results
    const tests = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: data.id || doc.id,
        licenseId: data.licenseId,
        title: data.title || 'Untitled Test',
        description: data.description || '',
        questionCount: data.questionCount || 0,
        duration: data.duration || 60,
        language: data.language,
        state: data.state,
        order: data.order || 0
      };
    });

    console.log(`Returning ${tests.length} processed practice tests`);
    return tests;

  } catch (error) {
    console.error('Error in getPracticeTests:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch practice tests: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// User Management Functions

// Update user language preference
export const updateUserLanguage = functions.https.onCall(async (data, context) => {
  try {
    console.log('updateUserLanguage called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to update language'
      );
    }
    
    const userId = context.auth.uid;
    const { language } = data;
    
    // Validate language parameter
    if (!language) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Language is required'
      );
    }
    
    // Validate language code
    const validLanguages = ['en', 'uk', 'ru', 'es', 'pl'];
    if (!validLanguages.includes(language)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid language code. Must be one of: ${validLanguages.join(', ')}`
      );
    }
    
    console.log(`Updating language for user ${userId} to: ${language}`);
    
    // Update user document in Firestore
    // Risk #23 — set/merge, not update(): update() throws NOT_FOUND on a
    // missing document, which is what made an orphaned account permanently
    // stuck. This heals accounts orphaned before the auth trigger existed.
    await db.collection('users').doc(userId).set({
      language: language,
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log(`Successfully updated language for user ${userId} to: ${language}`);
    
    return { 
      success: true, 
      message: 'Language updated successfully',
      language: language 
    };
    
  } catch (error) {
    console.error('Error in updateUserLanguage:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update language: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Update user state preference
export const updateUserState = functions.https.onCall(async (data, context) => {
  try {
    console.log('updateUserState called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to update state'
      );
    }
    
    const userId = context.auth.uid;
    const { state } = data;
    
    console.log(`Updating state for user ${userId} to: ${state || 'null'}`);
    
    // Update user document in Firestore (state can be null)
    // Risk #23 — set/merge, not update(). See updateUserLanguage above.
    await db.collection('users').doc(userId).set({
      state: state || null,
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });
    
    console.log(`Successfully updated state for user ${userId} to: ${state || 'null'}`);
    
    return { 
      success: true, 
      message: 'State updated successfully',
      state: state || null
    };
    
  } catch (error) {
    console.error('Error in updateUserState:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update state: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Get current user data
export const getUserData = functions.https.onCall(async (data, context) => {
  try {
    console.log('getUserData called');
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to get user data'
      );
    }
    
    const userId = context.auth.uid;
    console.log(`Getting user data for user: ${userId}`);
    
    // Get user document from Firestore
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User document not found'
      );
    }
    
    const userData = userDoc.data();
    if (!userData) {
      throw new functions.https.HttpsError(
        'not-found',
        'User data is empty'
      );
    }
    
    // Return user data with proper field mapping
    const result = {
      id: userId,
      name: userData.name || '',
      email: userData.email || context.auth.token.email || '',
      language: userData.language || 'en',
      state: userData.state || null,
    };
    
    console.log(`Successfully retrieved user data for user: ${userId}`);
    return result;
    
  } catch (error) {
    console.error('Error in getUserData:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get user data: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Create or update user document
export const createOrUpdateUserDocument = functions.https.onCall(async (data, context) => {
  try {
    console.log('createOrUpdateUserDocument called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to create/update user document'
      );
    }
    
    const userId = context.auth.uid;
    const { name, email, language, state, userId: providedUserId } = data;
    
    // Ensure user can only update their own document
    if (providedUserId && providedUserId !== userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Users can only update their own documents'
      );
    }
    
    // Validate required fields
    if (!name || !email) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Name and email are required'
      );
    }
    
    console.log(`Creating/updating user document for user: ${userId}`);
    
    // Check if document exists
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (userDoc.exists) {
      // Update existing document
      const updateData = {
        name: name,
        email: email,
        language: language || 'en',
        state: state || null,
        lastUpdated: FieldValue.serverTimestamp(),
      };
      await db.collection('users').doc(userId).update(updateData);
      console.log(`Successfully updated user document for user: ${userId}`);
    } else {
      // Create new document
      const createData = {
        name: name,
        email: email,
        language: language || 'en',
        state: state || null,
        createdAt: FieldValue.serverTimestamp(),
        lastUpdated: FieldValue.serverTimestamp(),
      };
      await db.collection('users').doc(userId).set(createData);
      console.log(`Successfully created user document for user: ${userId}`);
    }
    
    return { 
      success: true, 
      message: 'User document created/updated successfully',
      userId: userId
    };
    
  } catch (error) {
    console.error('Error in createOrUpdateUserDocument:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create/update user document: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Saved Questions Functions

// Add a saved question (Updated for single-document structure)
export const addSavedQuestion = functions.https.onCall(async (data, context) => {
  try {
    console.log('addSavedQuestion called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to save questions'
      );
    }
    
    const userId = context.auth.uid;
    const { questionId } = data;
    
    // Validate required parameters
    if (!questionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Question ID is required'
      );
    }
    
    console.log(`Adding saved question for user ${userId}: ${questionId}`);
    
    // Use userId as document ID for single-document structure
    const docRef = db.collection('savedQuestions').doc(userId);
    const userDoc = await docRef.get();
    
    if (userDoc.exists) {
      // Update existing document
      const data = userDoc.data();
      const itemIds = data?.itemIds || [];
      
      // Check if question is already saved
      if (itemIds.includes(questionId)) {
        console.log(`Question ${questionId} already saved for user ${userId}`);
        return { 
          success: true, 
          message: 'Question already saved',
          questionId: questionId,
          alreadyExists: true
        };
      }
      
      // Add question to array and update order
      await docRef.update({
        itemIds: FieldValue.arrayUnion(questionId),
        [`order.${questionId}`]: Date.now(),
        lastUpdated: FieldValue.serverTimestamp(),
      });
      
    } else {
      // Create new document
      const savedQuestionData = {
        userId: userId,
        itemIds: [questionId],
        order: { [questionId]: Date.now() },
        savedAt: FieldValue.serverTimestamp(),
        lastUpdated: FieldValue.serverTimestamp(),
      };
      
      await docRef.set(savedQuestionData);
    }
    
    console.log(`Successfully saved question ${questionId} for user ${userId}`);
    
    return { 
      success: true, 
      message: 'Question saved successfully',
      questionId: questionId,
      alreadyExists: false
    };
    
  } catch (error) {
    console.error('Error in addSavedQuestion:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to save question: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Remove a saved question (Updated for single-document structure)
export const removeSavedQuestion = functions.https.onCall(async (data, context) => {
  try {
    console.log('removeSavedQuestion called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to remove saved questions'
      );
    }
    
    const userId = context.auth.uid;
    const { questionId } = data;
    
    // Validate required parameters
    if (!questionId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Question ID is required'
      );
    }
    
    console.log(`Removing saved question for user ${userId}: ${questionId}`);
    
    // Use userId as document ID for single-document structure
    const docRef = db.collection('savedQuestions').doc(userId);
    const userDoc = await docRef.get();
    
    if (!userDoc.exists) {
      console.log(`No saved questions document found for user ${userId}`);
      return { 
        success: true, 
        message: 'Question was not saved',
        questionId: questionId,
        wasNotSaved: true
      };
    }
    
    const docData = userDoc.data();
    const itemIds = docData?.itemIds || [];
    
    // Check if question is in the saved list
    if (!itemIds.includes(questionId)) {
      console.log(`Question ${questionId} not found in saved questions for user ${userId}`);
      return { 
        success: true, 
        message: 'Question was not saved',
        questionId: questionId,
        wasNotSaved: true
      };
    }
    
    // Remove question from array and order map
    await docRef.update({
      itemIds: FieldValue.arrayRemove(questionId),
      [`order.${questionId}`]: FieldValue.delete(),
      lastUpdated: FieldValue.serverTimestamp(),
    });
    
    console.log(`Successfully removed saved question ${questionId} for user ${userId}`);
    
    return { 
      success: true, 
      message: 'Question removed successfully',
      questionId: questionId,
      wasNotSaved: false
    };
    
  } catch (error) {
    console.error('Error in removeSavedQuestion:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to remove saved question: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Get all saved questions for a user (Updated for single-document structure)
export const getSavedQuestions = functions.https.onCall(async (data, context) => {
  try {
    console.log('getSavedQuestions called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to get saved questions'
      );
    }
    
    const userId = context.auth.uid;
    
    console.log(`Getting saved questions for user: ${userId}`);
    
    // Get single document for this user
    const userDoc = await db.collection('savedQuestions').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`No saved questions document found for user ${userId}`);
      return {
        success: true,
        savedQuestions: [],
        count: 0
      };
    }
    
    const docData = userDoc.data();
    const itemIds = docData?.itemIds || [];
    const orderMap = docData?.order || {};
    
    // Sort by order (newest first)
    const sortedQuestionIds = itemIds.sort((a: string, b: string) => (orderMap[b] || 0) - (orderMap[a] || 0));
    
    console.log(`Returning ${sortedQuestionIds.length} saved question IDs`);
    
    return {
      success: true,
      savedQuestions: sortedQuestionIds,
      count: sortedQuestionIds.length
    };
    
  } catch (error) {
    console.error('Error in getSavedQuestions:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get saved questions: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Get saved questions with content (Optimized for direct question loading)
export const getSavedQuestionsWithContent = functions.https.onCall(async (data, context) => {
  try {
    console.log('getSavedQuestionsWithContent called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to get saved questions'
      );
    }
    
    const userId = context.auth.uid;
    
    console.log(`Getting saved questions with content for user: ${userId}`);
    
    // Get single document for this user
    const userDoc = await db.collection('savedQuestions').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`No saved questions document found for user ${userId}`);
      return {
        success: true,
        questions: [],
        count: 0
      };
    }
    
    const docData = userDoc.data();
    const itemIds = docData?.itemIds || [];
    const orderMap = docData?.order || {};
    
    if (itemIds.length === 0) {
      console.log(`No saved questions found for user ${userId}`);
      return {
        success: true,
        questions: [],
        count: 0
      };
    }
    
    console.log(`Found ${itemIds.length} saved question IDs, fetching content...`);
    
    // Query individual questions directly by document ID
    const questionPromises = itemIds.map((questionId: string) => 
      db.collection('quizQuestions').doc(questionId).get()
    );
    
    const questionDocs = await Promise.all(questionPromises);
    
    // Process and return questions
    const questions = questionDocs
      .filter(doc => doc.exists)
      .map(doc => {
        const data = doc.data();
        
        // Handle different correct answer field names in Firestore
        let correctAnswer = data?.correctAnswer;
        if (!correctAnswer && data?.correctAnswerString) {
          correctAnswer = data.correctAnswerString;
        }
        if (!correctAnswer && data?.correctAnswers) {
          correctAnswer = data.correctAnswers;
        }
        
        return {
          id: data?.id || doc.id,
          topicId: data?.topicId || '',
          questionText: data?.questionText || '',
          options: data?.options || [],
          correctAnswer: correctAnswer,
          explanation: data?.explanation || '',
          ruleReference: data?.ruleReference || '',
          imagePath: data?.imagePath || null,
          type: data?.type || 'singleChoice',
          language: data?.language || 'en',
          state: data?.state || 'ALL',
          order: data?.order || 0
        };
      });
    
    // Sort by saved order (newest first)
    questions.sort((a, b) => (orderMap[b.id] || 0) - (orderMap[a.id] || 0));
    
    console.log(`Returning ${questions.length} saved questions with content`);
    
    return {
      success: true,
      questions: questions,
      count: questions.length
    };
    
  } catch (error) {
    console.error('Error in getSavedQuestionsWithContent:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get saved questions with content: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Update user profile (combined name, language, state update)
export const updateProfile = functions.https.onCall(async (data, context) => {
  try {
    console.log('updateProfile called with data:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to update profile'
      );
    }
    
    const userId = context.auth.uid;
    const { name, language, state } = data;
    
    console.log(`Updating profile for user ${userId}: name=${name}, language=${language}, state=${state}`);
    
    // Build update data object
    const updateData: any = {
      lastUpdated: FieldValue.serverTimestamp(),
    };
    
    // Add name if provided
    if (name !== undefined && name !== null) {
      if (typeof name !== 'string' || name.trim().length === 0) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Name must be a non-empty string'
        );
      }
      updateData.name = name.trim();
    }
    
    // Add language if provided
    if (language !== undefined && language !== null) {
      const validLanguages = ['en', 'uk', 'ru', 'es', 'pl'];
      if (!validLanguages.includes(language)) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Invalid language code. Must be one of: ${validLanguages.join(', ')}`
        );
      }
      updateData.language = language;
    }
    
    // Add state if provided (can be null to clear state)
    if (state !== undefined) {
      // Handle state conversion if needed - convert full state names to IDs
      let stateId = state;
      if (state && typeof state === 'string' && state.length > 2 && state !== 'ALL') {
        // This might be a full state name, but we'll accept it as-is
        // The client should handle state name to ID conversion
        stateId = state;
      }
      updateData.state = stateId;
    }
    
    console.log(`Update data prepared:`, updateData);
    
    // Update user document in Firestore
    await db.collection('users').doc(userId).update(updateData);
    
    console.log(`Successfully updated profile for user ${userId}`);
    
    // Get updated user document to return complete user data
    const updatedUserDoc = await db.collection('users').doc(userId).get();
    
    if (!updatedUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User document not found after update'
      );
    }
    
    const userData = updatedUserDoc.data();
    if (!userData) {
      throw new functions.https.HttpsError(
        'not-found',
        'User data is empty after update'
      );
    }
    
    // Return user data in expected format
    const result = {
      id: userId,
      name: userData.name || '',
      email: userData.email || context.auth.token.email || '',
      language: userData.language || 'en',
      state: userData.state || null,
    };
    
    console.log(`Returning updated user data:`, result);
    return result;
    
  } catch (error) {
    console.error('Error in updateProfile:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update profile: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// Account Management Functions

// Delete user account with comprehensive error handling and logging
export const deleteUserAccount = functions.https.onCall(async (data, context) => {
  try {
    console.log('deleteUserAccount called with data:', data);
    
    // Step 1: Validate authentication
    if (!context.auth) {
      console.error('Unauthenticated request to deleteUserAccount');
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to delete account'
      );
    }
    
    const userId = context.auth.uid;
    const { userId: requestedUserId } = data;
    
    console.log(`Account deletion requested for user: ${userId}`);
    
    // Step 2: Security validation - ensure user can only delete their own account
    if (requestedUserId && requestedUserId !== userId) {
      console.error(`User ${userId} attempted to delete account ${requestedUserId}`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'Users can only delete their own account'
      );
    }
    
    // Risk #14 — require a recent login. admin.auth().deleteUser() bypasses
    // Firebase's own requires-recent-login entirely, so nothing enforced this:
    // a borrowed or stolen unlocked phone could destroy an account hours after
    // the real user last authenticated. Deletion is irreversible; it deserves
    // the same bar as changing a password.
    try {
      assertRecentLogin(context.auth.token?.auth_time);
    } catch (e) {
      const reason = e instanceof Error ? e.message : String(e);
      console.warn(`deleteUserAccount: refused for ${userId} — ${reason}`);
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Please sign in again before deleting your account.',
        { reason },
      );
    }

    // Risk #13 — enumerate EVERY location holding this user's data. The old
    // implementation deleted two of at least eight, while privacy_policy.md
    // promised "your account and all associated data".
    const targets = await collectUserDataForDeletion(db, userId);
    console.log(
      `deleteUserAccount: ${targets.length} target(s) for ${userId}: ` +
      targets.map((t) => `${t.collection}:${t.action}`).join(', '),
    );

    // Risk #26 — trialDevices is anonymised rather than deleted; removing it
    // would make account deletion a way to farm unlimited free trials.
    const trialDeviceBatch = db.batch();
    let anonymizedDevices = 0;
    try {
      anonymizedDevices = await anonymizeTrialDevicesForUser(trialDeviceBatch, userId, db);
    } catch (trialDeviceError) {
      console.warn(`Error anonymising trialDevices for user ${userId}:`, trialDeviceError);
    }

    // Step 5: Apply the plan, chunked — a long history exceeds Firestore's
    // 500-write batch limit, which the previous single batch would have hit.
    let applied;
    try {
      applied = await applyDeletionPlan(db, targets, `deleted_${userId.slice(0, 8)}`);
      if (anonymizedDevices > 0) await trialDeviceBatch.commit();
      console.log(
        `deleteUserAccount: deleted ${applied.deleted}, anonymised ` +
        `${applied.anonymized} + ${anonymizedDevices} device record(s) for ${userId}`,
      );
    } catch (firestoreError) {
      console.error(`Failed to delete Firestore documents for user ${userId}:`, firestoreError);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to delete user data from database'
      );
    }

    // Step 6: Delete Firebase Auth user
    try {
      console.log(`Deleting Firebase Auth user: ${userId}`);
      await admin.auth().deleteUser(userId);
      console.log(`Successfully deleted Firebase Auth user: ${userId}`);
    } catch (authError: unknown) {
      console.error(`Failed to delete Firebase Auth user ${userId}:`, authError);
      
      // Check for specific auth errors
      if (authError && typeof authError === 'object' && 'code' in authError && authError.code === 'auth/user-not-found') {
        console.warn(`Firebase Auth user ${userId} not found, but Firestore data was deleted`);
        // Continue - user data is cleaned up even if auth user doesn't exist
      } else {
        throw new functions.https.HttpsError(
          'internal',
          'Failed to delete user authentication record'
        );
      }
    }
    
    console.log(`Account deletion completed successfully for user: ${userId}`);
    
    // Step 7: Return success response
    return {
      success: true,
      message: 'Account deleted successfully',
      // Risk #14 — deleting the account does NOT cancel an App Store or Google
      // Play subscription. Only the store can do that, and only the user can
      // ask it to. Saying nothing meant people kept being charged for an
      // account that no longer existed.
      storeSubscriptionWarning:
        'Deleting your account does not cancel an active App Store or Google Play '
        + 'subscription. Cancel it in your device subscription settings, or you will '
        + 'continue to be charged.',
      userId: userId,
      timestamp: FieldValue.serverTimestamp(),
    };
    
  } catch (error) {
    console.error('Error in deleteUserAccount:', error);
    
    // Re-throw HttpsError instances as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Wrap other errors
    throw new functions.https.HttpsError(
      'internal',
      'Account deletion failed: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// =============================================================================
// SUBSCRIPTION MANAGEMENT FUNCTIONS
// =============================================================================

/**
 * Scheduled function that runs every hour to check for expired subscriptions
 * This is the main server-side subscription management function
 */
export const checkExpiredSubscriptions = functions
  // Risk #25 — the sweeps are cursor-paginated now and need room to drain a
  // backlog. The default 60s timeout would kill them mid-sweep; the sweep's own
  // time budget stops it well before this ceiling and reports what is left.
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub
  .schedule('every 1 hours')
  .timeZone('America/Chicago')
  .onRun(async (context) => {
    try {
      console.log('🔄 Scheduled subscription check started at:', new Date().toISOString());
      
      const result = await processExpiredSubscriptions();
      
      console.log('✅ Scheduled subscription check completed successfully');
      console.log(`📊 Summary: ${result.totalProcessed} subscriptions processed`);
      console.log(`📧 Emails sent: ${result.emailsSent}`);
      console.log(`❌ Errors: ${result.errors.length}`);
      
      if (result.errors.length > 0) {
        console.warn('⚠️ Some errors occurred during processing:', result.errors);
      }
      
      return {
        success: true,
        result: result,
        timestamp: FieldValue.serverTimestamp()
      };
      
    } catch (error) {
      console.error('❌ Critical error in scheduled subscription check:', error);
      
      // Log error to Firestore for monitoring
      try {
        await db.collection('systemLogs').add({
          type: 'scheduled_subscription_check_error',
          error: error instanceof Error ? error.message : String(error),
          timestamp: FieldValue.serverTimestamp(),
          context: context
        });
      } catch (logError) {
        console.error('Failed to log error to Firestore:', logError);
      }
      
      throw error;
    }
  });

/**
 * Manual trigger function for testing subscription processing
 * Can be called directly from Firebase Console or client app (admin only)
 */
export const processSubscriptionsManualy = functions.https.onCall(async (data, context) => {
  // Risk #18 — administrator gate, before the try so its HttpsError
  // cannot be reshaped into 'internal' by the catch below. The
  // `if (!context.auth)` check further down is now redundant at
  // runtime but is kept: it is what narrows `context.auth` for
  // TypeScript at the `context.auth.uid` uses below.
  await requireAdmin(context);

  try {
    console.log('🧪 Manual subscription processing triggered');
    
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required for manual subscription processing'
      );
    }
    
    console.log(`Manual trigger by user: ${context.auth.uid}`);
    
    const result = await testSubscriptionProcessing();
    
    console.log('✅ Manual subscription processing completed');
    
    return {
      success: true,
      result: result,
      triggeredBy: context.auth.uid,
      timestamp: FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error in manual subscription processing:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Manual subscription processing failed: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

/**
 * Get subscription statistics for monitoring dashboard
 * Returns information about upcoming expirations
 */
export const getSubscriptionStats = functions.https.onCall(async (data, context) => {
  // Risk #18 — administrator gate, before the try so its HttpsError
  // cannot be reshaped into 'internal' by the catch below. The
  // `if (!context.auth)` check further down is now redundant at
  // runtime but is kept: it is what narrows `context.auth` for
  // TypeScript at the `context.auth.uid` uses below.
  await requireAdmin(context);

  try {
    console.log('📊 Getting subscription statistics');
    
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required for subscription statistics'
      );
    }
    
    const stats = await getSubscriptionStatistics();
    
    console.log('✅ Subscription statistics retrieved successfully');
    
    return {
      success: true,
      statistics: stats,
      retrievedBy: context.auth.uid,
      timestamp: FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error getting subscription statistics:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get subscription statistics: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});


/**
 * Health check function for subscription management system
 * Returns system status and recent activity
 */
export const subscriptionSystemHealth = functions.https.onCall(async (data, context) => {
  // Risk #18 — administrator gate, before the try so its HttpsError
  // cannot be reshaped into 'internal' by the catch below. The
  // `if (!context.auth)` check further down is now redundant at
  // runtime but is kept: it is what narrows `context.auth` for
  // TypeScript at the `context.auth.uid` uses below.
  await requireAdmin(context);

  try {
    console.log('🏥 Health check for subscription system');
    
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
      .where('timestamp', '>', Timestamp.fromDate(oneHourAgo))
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();
    
    // Check recent subscription logs
    const recentSubscriptionLogs = await db.collection('subscriptionLogs')
      .where('timestamp', '>', Timestamp.fromDate(oneHourAgo))
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();
    
    // Get subscription statistics
    const stats = await getSubscriptionStatistics();
    
    const healthReport = {
      status: 'healthy',
      timestamp: FieldValue.serverTimestamp(),
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





// =============================================================================
// SUBSCRIPTION RENEWAL FUNCTIONS
// =============================================================================

/**
 * Scheduled function that runs every 6 hours to renew active subscriptions
 * This is the main server-side subscription renewal function
 */
export const renewActiveSubscriptions = functions
  // Risk #25 — the sweeps are cursor-paginated now and need room to drain a
  // backlog. The default 60s timeout would kill them mid-sweep; the sweep's own
  // time budget stops it well before this ceiling and reports what is left.
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub
  .schedule('every 6 hours')
  .timeZone('America/Chicago')
  .onRun(async (context) => {
    try {
      console.log('🔄 Scheduled subscription renewal started at:', new Date().toISOString());
      
      const result = await processActiveSubscriptionRenewals();
      
      console.log('✅ Scheduled subscription renewal completed successfully');
      console.log(`📊 Summary: ${result.totalProcessed} subscriptions processed`);
      console.log(`💳 Successful renewals: ${result.successfulRenewals}`);
      console.log(`❌ Failed renewals: ${result.failedRenewals}`);
      console.log(`📧 Emails sent: ${result.emailsSent}`);
      
      if (result.errors.length > 0) {
        console.warn('⚠️ Some errors occurred during renewal processing:', result.errors);
      }
      
      return {
        success: true,
        result: result,
        timestamp: FieldValue.serverTimestamp()
      };
      
    } catch (error) {
      console.error('❌ Critical error in scheduled subscription renewal:', error);
      
      // Log error to Firestore for monitoring
      try {
        await db.collection('systemLogs').add({
          type: 'scheduled_subscription_renewal_error',
          error: error instanceof Error ? error.message : String(error),
          timestamp: FieldValue.serverTimestamp(),
          context: context
        });
      } catch (logError) {
        console.error('Failed to log error to Firestore:', logError);
      }
      
      throw error;
    }
  });

/**
 * Get renewal statistics for monitoring dashboard
 * Returns information about upcoming renewals
 */
export const getRenewalStats = functions.https.onCall(async (data, context) => {
  // Risk #18 — administrator gate, before the try so its HttpsError
  // cannot be reshaped into 'internal' by the catch below. The
  // `if (!context.auth)` check further down is now redundant at
  // runtime but is kept: it is what narrows `context.auth` for
  // TypeScript at the `context.auth.uid` uses below.
  await requireAdmin(context);

  try {
    console.log('📊 Getting renewal statistics');
    
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required for renewal statistics'
      );
    }
    
    const stats = await getRenewalStatistics();
    
    console.log('✅ Renewal statistics retrieved successfully');
    
    return {
      success: true,
      statistics: stats,
      retrievedBy: context.auth.uid,
      timestamp: FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error getting renewal statistics:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Failed to get renewal statistics: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

// =============================================================================
// RECEIPT VALIDATION FUNCTION
// =============================================================================

// Export receipt validation function (imported from receipt-validation.ts)
export { validatePurchaseReceipt };

// =============================================================================
// SUBSCRIPTION SECURITY FUNCTIONS
// =============================================================================

/**
 * Provision users/{uid} when an Auth account is created (risk #23).
 *
 * Provisioning used to be entirely client-initiated: the app created the Auth
 * user, then wrote the document itself. If that second write failed — network
 * drop, app killed mid-signup, a permission hiccup — the Auth account existed
 * with no document and nothing ever created one. The account was then
 * unrecoverable from inside the app, because the updaters called `.update()`,
 * which throws NOT_FOUND on a missing document.
 *
 * An auth trigger cannot be skipped by a client that dies halfway, so the
 * document now exists before the app asks for it.
 *
 * merge:true and no overwrite of client-owned fields: the client may well have
 * written its own document first with a name, language and state the user
 * actually chose. This fills gaps, it does not win races.
 */
export const provisionUserDocument = functions.auth.user().onCreate(async (user) => {
  const ref = db.collection('users').doc(user.uid);

  try {
    const existing = await ref.get();
    if (existing.exists) {
      console.log(`provisionUserDocument: ${user.uid} already has a document, leaving it alone`);
      return;
    }

    await ref.set({
      email: user.email ?? null,
      name: user.displayName ?? '',
      language: 'en',
      state: null,
      createdAt: FieldValue.serverTimestamp(),
      lastLoginAt: FieldValue.serverTimestamp(),
      provisionedBy: 'auth-trigger',
    }, { merge: true });

    console.log(`provisionUserDocument: created users/${user.uid}`);
  } catch (error) {
    // Never throw: a failure here must not break account creation itself. The
    // set/merge recovery in the updaters below is the second line of defence.
    console.error(`provisionUserDocument: could not provision ${user.uid}:`, error);
  }
});

// Creates a trial subscription server-side on new user signup.
// Replaces the client-side _createInitialTrialSubscription in direct_auth_service.dart.
// Fixes the 2017-date bug — timestamps are set server-side.
// Risk #47 — the content cache-bust signal. One integer the client compares
// against the version it cached; if they differ it drops cached content and
// refetches, regardless of TTL. Bumping the document is a content-operations
// step, not a deploy.
//
// Deliberately NOT entitlement-gated. A lapsed user who resubscribes must not
// be left holding content cached before a correction, and the value discloses
// nothing — it is one integer, no content of any kind.
export const getContentVersion = functions.https.onCall(async (_data: any, context: any) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Not logged in');
  }
  return { version: await readContentVersion(db) };
});

// Risk #40 — both of these collections grow forever: one document per store
// notification, one row per validation attempt, webhook and scheduler action.
// Nothing ever removed either, and no TTL policy was configured anywhere.
//
// Only the dedup records are pruned by default. subscriptionLogs is the audit
// trail and is left alone unless SUBSCRIPTION_LOG_RETENTION_DAYS is set.
export const cleanupExpiredRecords = functions
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .pubsub
  .schedule('every 24 hours')
  .timeZone('America/Chicago')
  .onRun(async () => {
    const deadline = Date.now() + SWEEP_TIME_BUDGET_MS;

    const dedupCutoff = retentionCutoff(WEBHOOK_DEDUP_RETENTION_DAYS);
    const dedupSweep = await sweepPaginated({
      label: 'processedWebhooks-retention',
      // orderBy is what makes the cursor meaningful, and the inequality field
      // has to be ordered first in Firestore anyway.
      baseQuery: db.collection('processedWebhooks')
        .where('processedAt', '<', admin.firestore.Timestamp.fromDate(dedupCutoff))
        .orderBy('processedAt'),
      deadline,
      handle: async (doc) => { await doc.ref.delete(); },
    });

    let logsDeleted = 0;
    let logsRemaining = false;
    let logErrors: string[] = [];
    const retentionDays = subscriptionLogRetentionDays.value();

    if (isRetentionEnabled(retentionDays)) {
      const logCutoff = retentionCutoff(retentionDays);
      console.log(
        `🧹 subscriptionLogs retention is ON at ${retentionDays} days; ` +
        `pruning rows older than ${logCutoff.toISOString()}`,
      );
      const logSweep = await sweepPaginated({
        label: 'subscriptionLogs-retention',
        baseQuery: db.collection('subscriptionLogs')
          .where('timestamp', '<', admin.firestore.Timestamp.fromDate(logCutoff))
          .orderBy('timestamp'),
        deadline,
        handle: async (doc) => { await doc.ref.delete(); },
      });
      logsDeleted = logSweep.processed;
      logsRemaining = logSweep.moreRemaining;
      logErrors = logSweep.errors;
    } else {
      console.log('🧹 subscriptionLogs retention is OFF; the audit trail is kept in full.');
    }

    const summary = {
      processedWebhooksDeleted: dedupSweep.processed,
      processedWebhooksRemaining: dedupSweep.moreRemaining,
      subscriptionLogsDeleted: logsDeleted,
      subscriptionLogsRemaining: logsRemaining,
      errors: [...dedupSweep.errors, ...logErrors],
    };
    console.log(`🧹 cleanupExpiredRecords: ${JSON.stringify(summary)}`);
    return summary;
  });

export const createTrialSubscription = functions.https.onCall(async (data: any, context: any) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not logged in');
  const userId = context.auth.uid;

  const deviceIdHash: string | undefined = data?.deviceIdHash;
  const isPhysicalDevice: boolean | undefined = data?.isPhysicalDevice;

  if (!deviceIdHash || typeof deviceIdHash !== 'string' || deviceIdHash.length !== 64) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid deviceIdHash');
  }
  if (isPhysicalDevice !== true) {
    throw new functions.https.HttpsError('failed-precondition', 'Trial unavailable on this device');
  }

  // NOTE (risk #12): email verification is deliberately NOT required here.
  // Product decision, owner 2026-09-16: a registered user gets the 3-day trial
  // immediately and is blocked only when it expires. Verification is a step in
  // the signup flow, not a gate on the trial.
  //
  // The cost is that the trial is only as scarce as email addresses are, which
  // is the trial-farming exposure risk #12 describes. The durable fix for that
  // is device attestation (App Check + DeviceCheck / Play Integrity) rather
  // than blocking new users at the door — see SESSION.md.

  const trialEnd = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // 3 days
  const deviceRef = db.collection('trialDevices').doc(deviceIdHash);

  // Risk #26 — both dedupe checks used to be read-then-write OUTSIDE any
  // transaction: two reads, then a separate batch commit. Two signups racing on
  // one device both passed their reads before either wrote, and both were
  // granted a trial. The reads and the writes now share one transaction, so
  // Firestore retries the loser on contention and it sees the winner's write.
  const subscriptionId = await db.runTransaction(async (tx) => {
    // Dedupe #1 — per userId
    const existing = await tx.get(
      db.collection('subscriptions').where('userId', '==', userId).limit(1),
    );
    if (!existing.empty) {
      throw new functions.https.HttpsError('already-exists', 'Subscription exists');
    }

    // Dedupe #2 — per device fingerprint
    const deviceSnap = await tx.get(deviceRef);
    if (deviceSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'trial-already-used-on-device');
    }

    const subRef = db.collection('subscriptions').doc();
    tx.set(subRef, {
    id: subRef.id, userId,
    packageId: 3, status: 'active', isActive: true,
    planType: 'trial', duration: 3, price: 0, trialUsed: 0,
    trialEndsAt: Timestamp.fromDate(trialEnd),
    nextBillingDate: Timestamp.fromDate(trialEnd),
    deviceIdHash,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.set(deviceRef, {
      firstUserId: userId,
      firstSubscriptionId: subRef.id,
      createdAt: FieldValue.serverTimestamp(),
    });
  // Mirror entitlement onto the user document, exactly as the purchase path does
  // (receipt-validation.ts syncUserDocument) and the schedulers expect.
  // Trials were the one path that never wrote it, so `users.isActive` was false
  // for every trial user — which made the flag unusable as a security-rules gate
  // and left trial users looking inactive to any server logic keyed on it.
    tx.set(
      db.collection('users').doc(userId),
      {
        isActive: true,
        nextBillingDate: Timestamp.fromDate(trialEnd),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return subRef.id;
  });

  return { subscriptionId };
});

// Cancels the user's active subscription server-side.
// Preserves isActive=true until nextBillingDate (user keeps access for paid days remaining).
export const cancelSubscription = functions.https.onCall(async (_data: any, context: any) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not logged in');
  const userId = context.auth.uid;

  const snap = await db.collection('subscriptions')
    .where('userId', '==', userId).where('isActive', '==', true).limit(1).get();
  if (snap.empty) throw new functions.https.HttpsError('not-found', 'No active subscription');

  const sub = snap.docs[0].data();
  const now = new Date();
  const nextBilling: Date | undefined = sub.nextBillingDate?.toDate();
  const shouldStayActive = nextBilling != null && now < nextBilling;

  await snap.docs[0].ref.update({
    status: 'canceled',
    isActive: shouldStayActive,
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { success: true, isActive: shouldStayActive };
});


// =============================================================================
// WEBHOOK HANDLERS
// =============================================================================

/**
 * Apple App Store Server Notifications webhook.
 *
 * Receives real-time subscription events (renewals, cancellations, expirations)
 * directly from Apple. Verifies the JWS signature, decodes the payload, and
 * updates Firestore atomically.
 *
 * Register URL in App Store Connect → Your App → App Store Server Notifications:
 *   https://us-central1-licenseprepapp.cloudfunctions.net/appStoreWebhook
 *
 * IMPORTANT: Always returns HTTP 200 — non-200 triggers Apple retries for our own bugs.
 */
export const appStoreWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') { res.status(405).send('Method Not Allowed'); return; }

  const { signedPayload } = req.body;
  if (!signedPayload) { res.status(200).json({ received: true }); return; }

  // Captured for the dead letter (risk #9): the real values are parsed inside
  // the try and are therefore out of scope in the catch.
  let dlKey: string | undefined;
  let dlType = 'unknown';

  try {
    const appId = appleAppId.value();

    // Try to verify against the correct environment.
    // Apple sends sandbox notifications (sandbox purchases, sandbox test button) signed with
    // the sandbox cert chain. Production notifications are signed with the production chain.
    // VerificationException status 4 = ENVIRONMENT_MISMATCH — retry with the other environment.
    const makeVerifier = (env: Environment) => new SignedDataVerifier(
      appleRootCAs,
      true,                          // enableOnlineChecks (OCSP)
      env,
      APPLE_BUNDLE_ID,
      appId > 0 ? appId : undefined  // required for Production; optional for Sandbox
    );

    let verifier: SignedDataVerifier;
    let notification: Awaited<ReturnType<SignedDataVerifier['verifyAndDecodeNotification']>>;
    try {
      // In emulator always use sandbox. In production try production first.
      const primaryEnv = process.env.FUNCTIONS_EMULATOR ? Environment.SANDBOX : Environment.PRODUCTION;
      verifier = makeVerifier(primaryEnv);
      notification = await verifier.verifyAndDecodeNotification(signedPayload);
    } catch (e: any) {
      if (e?.status === 4 && !process.env.FUNCTIONS_EMULATOR) {
        // ENVIRONMENT_MISMATCH — this is a sandbox notification sent to the production endpoint
        // (sandbox purchases, App Store Connect "Send test notification" sandbox button)
        console.log('ℹ️ appStoreWebhook: Production verification failed with ENVIRONMENT_MISMATCH — retrying as Sandbox');
        verifier = makeVerifier(Environment.SANDBOX);
        notification = await verifier.verifyAndDecodeNotification(signedPayload);
      } else {
        throw e;
      }
    }
    const { notificationType, subtype, data, notificationUUID } = notification;
    dlKey = notificationUUID as string | undefined;
    dlType = String(notificationType ?? 'unknown');

    // Apple sends this when you click "Send test notification" in App Store Connect
    if (notificationType === NotificationTypeV2.TEST) {
      console.log('✅ appStoreWebhook: Test notification received');
      res.status(200).json({ received: true });
      return;
    }

    if (!data?.signedTransactionInfo) {
      console.log(`ℹ️ appStoreWebhook: No transaction info for ${notificationType}`);
      res.status(200).json({ received: true });
      return;
    }

    const transaction = await verifier.verifyAndDecodeTransaction(data.signedTransactionInfo);
    const { originalTransactionId, expiresDate, productId } = transaction;

    // Decode renewalInfo — needed for DID_CHANGE_RENEWAL_STATUS autoRenewStatus branching (Bug B2 fix)
    let renewalInfo: Awaited<ReturnType<typeof verifier.verifyAndDecodeRenewalInfo>> | null = null;
    if (data.signedRenewalInfo) {
      renewalInfo = await verifier.verifyAndDecodeRenewalInfo(data.signedRenewalInfo);
    }

    // Idempotency: notificationUUID is Apple's own dedup key — same UUID on every retry
    if (!notificationUUID) {
      console.warn('⚠️ appStoreWebhook: Missing notificationUUID, skipping');
      res.status(200).json({ received: true });
      return;
    }

    const alreadyProcessed = await db.collection('processedWebhooks').doc(notificationUUID).get();
    if (alreadyProcessed.exists) {
      console.log(`⏭️ appStoreWebhook: Already processed ${notificationUUID}`);
      res.status(200).json({ received: true });
      return;
    }

    // Look up subscription by originalTransactionId
    // No .limit(1): a receipt bound to several accounts (risk #5, possible in
    // data created before the binding guard) must at least be visible. Only
    // docs[0] is updated below — fanning the update out to every match is
    // risk #22's job, not this one — but a silent miss becomes a loud warning.
    const snap = await db.collection('subscriptions')
      .where('originalTransactionId', '==', originalTransactionId)
      .get();

    if (snap.size > 1) {
      console.error(
        `🚨 appStoreWebhook: ${snap.size} subscriptions share originalTransactionId ` +
        `${originalTransactionId} (users: ${snap.docs.map((d) => d.get('userId')).join(', ')}). ` +
        'Only the first is being updated — see risk #5 / #22.',
      );
    }

    if (snap.empty) {
      // Existing subscriber: originalTransactionId not yet stored (pre-deployment purchase).
      // Will self-heal on their next purchase through validatePurchaseReceipt.
      console.warn(`⚠️ appStoreWebhook: No subscription found for txn ${originalTransactionId}. ` +
        'Existing subscriber without originalTransactionId — will self-heal on next purchase.');
      await db.collection('processedWebhooks').doc(notificationUUID).set({
        processedAt: FieldValue.serverTimestamp(),
        notificationType,
        subtype: subtype ?? null,
        originalTransactionId,
        result: 'subscription_not_found',
      });
      res.status(200).json({ received: true });
      return;
    }

    const subData = snap.docs[0].data();
    const userId = subData.userId as string;
    const now = FieldValue.serverTimestamp();
    // expiresDate is Unix milliseconds per JWSTransactionDecodedPayload
    const expiresTimestamp = expiresDate
      ? Timestamp.fromMillis(expiresDate)
      : null;

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let subUpdates: Record<string, any> = { updatedAt: now };
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    let userUpdates: Record<string, any> | null = null;
    let logAction = notificationType as string;

    switch (notificationType) {
      case NotificationTypeV2.DID_RENEW:
      case NotificationTypeV2.SUBSCRIBED:
        subUpdates = {
          ...subUpdates,
          isActive: true,
          status: 'active',
          renewalAttempts: 0,
          ...(expiresTimestamp && { nextBillingDate: expiresTimestamp }),
        };
        userUpdates = {
          isActive: true,
          ...(expiresTimestamp && { nextBillingDate: expiresTimestamp }),
          lastUpdated: now,
        };
        logAction = 'apple_renewed';
        break;

      case NotificationTypeV2.DID_FAIL_TO_RENEW:
        // Apple's grace period begins — keep access, flag as past_due
        subUpdates = { ...subUpdates, status: 'past_due' };
        logAction = 'apple_billing_failed';
        break;

      case NotificationTypeV2.GRACE_PERIOD_EXPIRED:
      case NotificationTypeV2.EXPIRED:
        subUpdates = { ...subUpdates, isActive: false, status: 'inactive' };
        userUpdates = { isActive: false, lastUpdated: now };
        logAction = 'apple_expired';
        break;

      case NotificationTypeV2.REFUND:
      case NotificationTypeV2.REVOKE:
        subUpdates = { ...subUpdates, isActive: false, status: 'inactive' };
        userUpdates = { isActive: false, lastUpdated: now };
        logAction = 'apple_revoked';
        break;

      case NotificationTypeV2.DID_CHANGE_RENEWAL_STATUS: {
        // BUG B2 FIX: subtype distinguishes enable vs disable — both arrive as this notification type.
        // Original plan set status='canceled' unconditionally, which incorrectly canceled subscriptions
        // when users RE-ENABLED auto-renew. Must check autoRenewStatus from signedRenewalInfo.
        const autoRenewOn = renewalInfo?.autoRenewStatus === AutoRenewStatus.ON;
        if (autoRenewOn) {
          subUpdates = { ...subUpdates, status: 'active' };
          userUpdates = { isActive: true, lastUpdated: now };
          logAction = 'apple_autorenew_enabled';
        } else {
          // User disabled auto-renew — access continues until nextBillingDate
          subUpdates = { ...subUpdates, status: 'canceled' };
          logAction = 'apple_cancel_requested';
        }
        break;
      }

      default:
        console.log(`ℹ️ appStoreWebhook: Unhandled type ${notificationType}, skipping`);
        res.status(200).json({ received: true });
        return;
    }

    // Atomic batch: subscription + users (if needed) + dedup record + audit log
    const batch = db.batch();
    // Risk #22 — apply to EVERY document sharing this receipt, and to each
    // one's own user. Updates are derived from the notification type and
    // expiry, so they are safe to fan out; documents sharing a receipt
    // represent the same store subscription and must converge.
    applyToAllMatches(db, batch, snap.docs, subUpdates, userUpdates);
    batch.set(db.collection('processedWebhooks').doc(notificationUUID), {
      processedAt: now,
      notificationType,
      subtype: subtype ?? null,
      originalTransactionId,
    });
    batch.set(db.collection('subscriptionLogs').doc(), {
      userId,
      subscriptionId: snap.docs[0].id,
      action: logAction,
      oldStatus: { isActive: subData.isActive, status: subData.status },
      newStatus: {
        isActive: subUpdates.isActive !== undefined ? subUpdates.isActive : subData.isActive,
        status: subUpdates.status ?? subData.status,
      },
      timestamp: now,
      source: 'apple_webhook',
      originalTransactionId,
      productId,
    });
    await batch.commit();

    console.log(`✅ appStoreWebhook: ${logAction} for user ${userId}`);
    res.status(200).json({ received: true });

  } catch (err) {
    console.error('❌ appStoreWebhook error:', err);

    // Risk #9 — this used to return 200 unconditionally, so a renewal or a
    // revocation lost to a transient error was lost permanently, with nothing
    // recording that it had arrived. The old comment's worry (Apple retrying
    // our own bugs forever) is handled by bounding the retries instead of
    // refusing them: record the failure, ask Apple to redeliver a few times,
    // then start acking and leave the dead letter for manual replay.
    const { shouldRetry } = await recordWebhookFailure(db, {
      source: 'apple',
      key: dlKey ?? `nouuid_${Date.now()}`,
      notificationType: dlType,
      payload: { signedPayload },
      error: err,
    });

    if (shouldRetry) {
      res.status(500).json({ received: false, retry: true });
    } else {
      res.status(200).json({ received: true, deadLettered: true });
    }
  }
});

/**
 * Google Play Real-Time Developer Notifications handler.
 *
 * Triggered by Pub/Sub topic 'play-rtdn'. Handles subscription lifecycle
 * events: renewals, cancellations, expirations, and billing failures.
 *
 * Setup:
 *   1. GCP Console → Pub/Sub → Create topic: play-rtdn
 *      (originally 'google-play-rtdn' but renamed to comply with GCP naming restrictions)
 *   2. Grant google-play-developer-notifications@system.gserviceaccount.com Publisher role
 *   3. Play Console → Monetization settings → Real-time Developer Notifications
 *      → projects/licenseprepapp/topics/play-rtdn
 *
 * NOTE: Do NOT rethrow errors — Pub/Sub retries on thrown exceptions.
 */
export const handleGooglePlayNotifications = functions
  .runWith({ secrets: [googleCredentials] })
  .pubsub.topic('play-rtdn')
  .onPublish(async (message) => {
    // Captured for the dead letter (risk #9): parsed inside the try, so out of
    // scope in the catch.
    let dlKey: string | undefined;
    let dlType = 'unknown';
    let dlPayload: unknown;

    try {
      const dataStr = Buffer.from(message.data, 'base64').toString('utf-8');
      const notification = JSON.parse(dataStr);
      dlPayload = notification;

      if (notification.testNotification) {
        console.log('✅ handleGooglePlayNotifications: Test notification received');
        return;
      }

      if (!notification.subscriptionNotification) {
        console.log('ℹ️ handleGooglePlayNotifications: Non-subscription notification, skipping');
        return;
      }

      const { notificationType, purchaseToken } = notification.subscriptionNotification;

      // BUG B3 FIX: Pub/Sub guarantees at-least-once delivery — deduplicate using message.messageId.
      // Without this, duplicate deliveries can double-write subscriptionLogs or clobber status
      // if a stale EXPIRED message arrives after a RENEWED message.
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const messageId = (message as any).messageId as string;
      dlKey = messageId;
      dlType = String(notificationType ?? 'unknown');
      const alreadyProcessed = await db.collection('processedWebhooks').doc(`gp_${messageId}`).get();
      if (alreadyProcessed.exists) {
        console.log(`⏭️ handleGooglePlayNotifications: Already processed ${messageId}`);
        return;
      }

      // See the appStoreWebhook note above: surfacing duplicates, not fanning out.
      const subSnap = await db.collection('subscriptions')
        .where('androidPurchaseToken', '==', purchaseToken)
        .get();

      if (subSnap.size > 1) {
        console.error(
          `🚨 handleGooglePlayNotifications: ${subSnap.size} subscriptions share this ` +
          `purchaseToken (users: ${subSnap.docs.map((d) => d.get('userId')).join(', ')}). ` +
          'Only the first is being updated — see risk #5 / #22.',
        );
      }

      if (subSnap.empty) {
        // Existing subscriber: androidPurchaseToken not yet stored (pre-deployment purchase).
        // Will self-heal on their next purchase through validatePurchaseReceipt.
        console.warn('⚠️ handleGooglePlayNotifications: No subscription found for purchaseToken. ' +
          'Existing subscriber without androidPurchaseToken — will self-heal on next purchase.');
        await db.collection('processedWebhooks').doc(`gp_${messageId}`).set({
          processedAt: FieldValue.serverTimestamp(),
          notificationType,
          result: 'subscription_not_found',
        });
        return;
      }

      const subData = subSnap.docs[0].data();
      const userId = subData.userId as string;
      const now = FieldValue.serverTimestamp();

      // Notification types and the state each implies live in
      // play-notifications.ts, named rather than numbered — the comment that
      // used to sit here mislabelled type 8 (risk #8).

      // BUG B4 FIX: For renewal events, fetch the real expiryTime from the Google Play Developer API.
      // Without this, nextBillingDate stays in the past and the 6-hour renewal scheduler re-enters
      // grace period every run, creating a permanent active→past_due flip-flop for Android users.
      let newBillingDate: Timestamp | null = null;
      if ([
        PLAY_NOTIFICATION.RECOVERED, PLAY_NOTIFICATION.RENEWED,
        PLAY_NOTIFICATION.PURCHASED, PLAY_NOTIFICATION.RESTARTED,
      ].includes(notificationType as any)) {
        try {
          const credsRaw = googleCredentials.value();
          const creds = JSON.parse(Buffer.from(credsRaw, 'base64').toString());
          const auth = new google.auth.GoogleAuth({
            credentials: creds,
            scopes: ['https://www.googleapis.com/auth/androidpublisher'],
          });
          const androidPublisher = google.androidpublisher({ version: 'v3', auth });
          const pkgName = (notification.packageName as string | undefined)
            ?? 'com.driveusa.app';
          const subResponse = await androidPublisher.purchases.subscriptionsv2.get({
            packageName: pkgName,
            token: purchaseToken as string,
          });
          // expiryTime is RFC 3339 (e.g. "2026-05-14T19:30:00Z") — NOT milliseconds.
          // parseInt() would parse just the year prefix (2026ms ≈ epoch) and set a 1970 date.
          const expiryTimeStr = ((subResponse.data as any).lineItems?.[0]?.expiryTime as string | undefined);
          if (expiryTimeStr) {
            const expiryMs = new Date(expiryTimeStr).getTime();
            if (!isNaN(expiryMs) && expiryMs > 0) {
              newBillingDate = Timestamp.fromMillis(expiryMs);
            }
          }
        } catch (apiErr) {
          console.warn('⚠️ handleGooglePlayNotifications: Could not fetch expiry from Play API, ' +
            'falling back to heuristic extension:', apiErr);
          // Heuristic fallback: advance nextBillingDate by one billing cycle so the renewal
          // scheduler does not immediately re-enter grace period before the real date is known.
          const currentDate = (subData.nextBillingDate as Timestamp | undefined)
            ?.toDate() ?? new Date();
          const billingDuration = (subData.duration as number | undefined) ?? 30;
          const extended = new Date(Math.max(currentDate.getTime(), Date.now()));
          extended.setDate(extended.getDate() + billingDuration);
          newBillingDate = Timestamp.fromDate(extended);
        }
      }

      const mapping = mapPlayNotification(notificationType as number, { now, newBillingDate });

      if (!mapping.handled) {
        // Loud, not silent: an unmodelled type reaching production is how the
        // pause states went unnoticed (risk #8).
        console.warn(
          `⚠️ handleGooglePlayNotifications: no handler for notification type ` +
          `${notificationType}. Entitlement left unchanged — check whether this ` +
          'type should be modelled in play-notifications.ts.',
        );
        await db.collection('processedWebhooks').doc(`gp_${messageId}`).set({
          processedAt: now, notificationType, result: 'unhandled_type',
        });
        return;
      }

      const { subUpdates, userUpdates, logAction } = mapping;

      const batch = db.batch();
      // Risk #22 — see the appStoreWebhook note above.
      applyToAllMatches(db, batch, subSnap.docs, subUpdates, userUpdates);
      batch.set(db.collection('processedWebhooks').doc(`gp_${messageId}`), {
        processedAt: now,
        notificationType,
        purchaseToken: purchaseToken ?? null,
      });
      batch.set(db.collection('subscriptionLogs').doc(), {
        userId,
        subscriptionId: subSnap.docs[0].id,
        action: logAction,
        oldStatus: { isActive: subData.isActive, status: subData.status },
        newStatus: {
          isActive: subUpdates.isActive !== undefined ? subUpdates.isActive : subData.isActive,
          status: subUpdates.status ?? subData.status,
        },
        timestamp: now,
        source: 'google_play_webhook',
        notificationType,
      });
      await batch.commit();

      console.log(`✅ handleGooglePlayNotifications: ${logAction} for user ${userId}`);
    } catch (err) {
      console.error('❌ handleGooglePlayNotifications error:', err);

      // Risk #9 — this used to swallow every error so Pub/Sub always acked,
      // which lost the notification for good. Retries are now bounded by the
      // dead-letter attempt count, so a persistent failure cannot become an
      // endless redelivery loop.
      const { shouldRetry } = await recordWebhookFailure(db, {
        source: 'play',
        key: String(dlKey ?? `nomsgid_${Date.now()}`),
        notificationType: dlType,
        payload: dlPayload ?? {},
        error: err,
      });

      if (shouldRetry) {
        // Rethrowing nacks the message and Pub/Sub redelivers with backoff.
        throw err;
      }
      // Budget spent: ack so the subscription stops redelivering. The dead
      // letter remains for manual replay.
    }
  });

// ============================================================================
// EMAIL VERIFICATION (risk #12)
// ============================================================================
//
// The trial is deliberately NOT gated on verification — a registered user gets
// the 3-day trial immediately (owner decision, 2026-09-16). These exist so the
// address is confirmed real during signup, not to withhold entitlement.
export {
  sendEmailVerificationCode,
  verifyEmailCode,
  getEmailVerificationStatus,
} from './email/verification-callables';
