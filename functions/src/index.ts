import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
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
import {
  generateAllTestData,
  cleanupTestData,
  createQuickTestScenario,
  verifyTestData
} from './test-data-generator';
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
    await db.collection('users').doc(userId).update({
      language: language,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    
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
    await db.collection('users').doc(userId).update({
      state: state || null,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    });
    
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
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
        itemIds: admin.firestore.FieldValue.arrayUnion(questionId),
        [`order.${questionId}`]: Date.now(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      });
      
    } else {
      // Create new document
      const savedQuestionData = {
        userId: userId,
        itemIds: [questionId],
        order: { [questionId]: Date.now() },
        savedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
      itemIds: admin.firestore.FieldValue.arrayRemove(questionId),
      [`order.${questionId}`]: admin.firestore.FieldValue.delete(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
    
    // Step 3: Check if user document exists
    console.log(`Checking if user document exists for: ${userId}`);
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.warn(`User document not found for: ${userId}, but proceeding with auth deletion`);
    } else {
      console.log(`User document found for: ${userId}, proceeding with deletion`);
    }
    
    // Step 4: Delete related user data
    const batch = db.batch();
    
    // Delete user document
    if (userDoc.exists) {
      batch.delete(db.collection('users').doc(userId));
      console.log(`Added user document deletion to batch for: ${userId}`);
    }
    
    // Delete saved questions document if it exists
    try {
      const savedQuestionsDoc = await db.collection('savedQuestions').doc(userId).get();
      if (savedQuestionsDoc.exists) {
        batch.delete(db.collection('savedQuestions').doc(userId));
        console.log(`Added saved questions deletion to batch for: ${userId}`);
      }
    } catch (savedQuestionsError) {
      console.warn(`Error checking saved questions for user ${userId}:`, savedQuestionsError);
      // Continue with account deletion even if saved questions check fails
    }
    
    // Step 5: Execute Firestore batch deletion
    try {
      await batch.commit();
      console.log(`Successfully deleted Firestore documents for user: ${userId}`);
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
      userId: userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
export const checkExpiredSubscriptions = functions.pubsub
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
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
    } catch (error) {
      console.error('❌ Critical error in scheduled subscription check:', error);
      
      // Log error to Firestore for monitoring
      try {
        await db.collection('systemLogs').add({
          type: 'scheduled_subscription_check_error',
          error: error instanceof Error ? error.message : String(error),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
  try {
    console.log('🧪 Manual subscription processing triggered');
    
    // Optional: Add admin authentication check here
    // For now, we'll allow any authenticated user to trigger this for testing
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
      timestamp: admin.firestore.FieldValue.serverTimestamp()
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
  try {
    console.log('📊 Getting subscription statistics');
    
    // Optional: Add admin authentication check here
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
      timestamp: admin.firestore.FieldValue.serverTimestamp()
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
 * Mock payment webhook handler for testing subscription events
 * Simulates webhooks from App Store and Google Play
 */
export const handleMockPaymentWebhook = functions.https.onRequest(async (req, res) => {
  try {
    console.log('🎭 Mock payment webhook received');
    console.log('Method:', req.method);
    console.log('Headers:', req.headers);
    console.log('Body:', req.body);
    
    if (req.method !== 'POST') {
      res.status(405).json({
        error: 'Method not allowed',
        message: 'This endpoint only accepts POST requests'
      });
      return;
    }
    
    const { eventType, userId, subscriptionData } = req.body;
    
    if (!eventType || !userId) {
      res.status(400).json({
        error: 'Missing required fields',
        message: 'eventType and userId are required'
      });
      return;
    }
    
    console.log(`Processing mock webhook: ${eventType} for user ${userId}`);
    
    // Log the mock webhook event
    await db.collection('mockWebhookEvents').add({
      eventType: eventType,
      userId: userId,
      subscriptionData: subscriptionData || {},
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source: 'mock_webhook'
    });
    
    // Here you would normally process different event types:
    // - subscription_purchased
    // - subscription_renewed  
    // - subscription_cancelled
    // - trial_started
    // - trial_expired
    
    console.log(`✅ Mock webhook processed: ${eventType}`);
    
    res.status(200).json({
      success: true,
      message: `Mock webhook ${eventType} processed successfully`,
      eventType: eventType,
      userId: userId,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error processing mock webhook:', error);
    
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : String(error)
    });
  }
});

/**
 * Health check function for subscription management system
 * Returns system status and recent activity
 */
export const subscriptionSystemHealth = functions.https.onCall(async (data, context) => {
  try {
    console.log('🏥 Health check for subscription system');
    
    // Optional: Add admin authentication check
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

// =============================================================================
// TEST DATA MANAGEMENT FUNCTIONS
// =============================================================================

/**
 * Generate comprehensive test data for subscription management testing
 * Creates users and subscriptions with various expiration scenarios
 */
export const generateSubscriptionTestData = functions.https.onCall(async (data, context) => {
  try {
    console.log('🧪 Generating subscription test data');
    
    // Optional: Add admin authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required to generate test data'
      );
    }
    
    console.log(`Test data generation triggered by user: ${context.auth.uid}`);
    
    const result = await generateAllTestData();
    
    console.log('✅ Test data generation completed successfully');
    
    return {
      success: true,
      result: result,
      generatedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error generating test data:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Test data generation failed: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

/**
 * Clean up all test data from the database
 * Removes all users and subscriptions marked as test data
 */
export const cleanupSubscriptionTestData = functions.https.onCall(async (data, context) => {
  try {
    console.log('🧹 Cleaning up subscription test data');
    
    // Optional: Add admin authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required to clean up test data'
      );
    }
    
    console.log(`Test data cleanup triggered by user: ${context.auth.uid}`);
    
    const result = await cleanupTestData();
    
    console.log('✅ Test data cleanup completed successfully');
    
    return {
      success: true,
      result: result,
      cleanedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error cleaning up test data:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Test data cleanup failed: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

/**
 * Create a quick test scenario for immediate testing
 * Creates 1 user with 1 expired trial for quick verification
 */
export const createQuickSubscriptionTest = functions.https.onCall(async (data, context) => {
  try {
    console.log('🚀 Creating quick subscription test scenario');
    
    // Optional: Add admin authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required to create test scenario'
      );
    }
    
    console.log(`Quick test scenario creation triggered by user: ${context.auth.uid}`);
    
    const result = await createQuickTestScenario();
    
    console.log('✅ Quick test scenario created successfully');
    
    return {
      success: true,
      result: result,
      createdBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error creating quick test scenario:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Quick test scenario creation failed: ' + (error instanceof Error ? error.message : String(error))
    );
  }
});

/**
 * Verify current test data in the database
 * Returns statistics about existing test data
 */
export const verifySubscriptionTestData = functions.https.onCall(async (data, context) => {
  try {
    console.log('🔍 Verifying subscription test data');
    
    // Optional: Add admin authentication check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required to verify test data'
      );
    }
    
    console.log(`Test data verification triggered by user: ${context.auth.uid}`);
    
    const result = await verifyTestData();
    
    console.log('✅ Test data verification completed successfully');
    
    return {
      success: true,
      statistics: result,
      verifiedBy: context.auth.uid,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('❌ Error verifying test data:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Test data verification failed: ' + (error instanceof Error ? error.message : String(error))
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
export const renewActiveSubscriptions = functions.pubsub
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
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };
      
    } catch (error) {
      console.error('❌ Critical error in scheduled subscription renewal:', error);
      
      // Log error to Firestore for monitoring
      try {
        await db.collection('systemLogs').add({
          type: 'scheduled_subscription_renewal_error',
          error: error instanceof Error ? error.message : String(error),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
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
  try {
    console.log('📊 Getting renewal statistics');
    
    // Optional: Add admin authentication check here
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
      timestamp: admin.firestore.FieldValue.serverTimestamp()
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

// Creates a trial subscription server-side on new user signup.
// Replaces the client-side _createInitialTrialSubscription in direct_auth_service.dart.
// Fixes the 2017-date bug — timestamps are set server-side.
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

  // Dedupe #1 — per userId
  const existing = await db.collection('subscriptions')
    .where('userId', '==', userId).limit(1).get();
  if (!existing.empty) throw new functions.https.HttpsError('already-exists', 'Subscription exists');

  // Dedupe #2 — per device fingerprint
  const deviceRef = db.collection('trialDevices').doc(deviceIdHash);
  const deviceSnap = await deviceRef.get();
  if (deviceSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'trial-already-used-on-device');
  }

  const trialEnd = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000); // 3 days
  const subRef = db.collection('subscriptions').doc();

  const batch = db.batch();
  batch.set(subRef, {
    id: subRef.id, userId,
    packageId: 3, status: 'active', isActive: true,
    planType: 'trial', duration: 3, price: 0, trialUsed: 0,
    trialEndsAt: admin.firestore.Timestamp.fromDate(trialEnd),
    nextBillingDate: admin.firestore.Timestamp.fromDate(trialEnd),
    deviceIdHash,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(deviceRef, {
    firstUserId: userId,
    firstSubscriptionId: subRef.id,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();

  return { subscriptionId: subRef.id };
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true, isActive: shouldStayActive };
});

// Upgrades an active monthly subscription to yearly (free proration for existing subscribers).
// Server validates planType === 'monthly' before allowing upgrade.
export const upgradeSubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Not logged in');
  const userId = context.auth.uid;
  const { targetPlanType, packageId } = data;

  if (targetPlanType !== 'yearly') {
    throw new functions.https.HttpsError('invalid-argument', 'Only monthly→yearly upgrade supported');
  }

  // Must already be a paying monthly subscriber (not trial)
  const snap = await db.collection('subscriptions')
    .where('userId', '==', userId)
    .where('isActive', '==', true)
    .where('planType', '==', 'monthly')
    .limit(1).get();
  if (snap.empty) throw new functions.https.HttpsError('not-found', 'No active monthly subscription');

  const sub = snap.docs[0].data();
  const currentNextBilling = sub.nextBillingDate.toDate() as Date;
  const now = new Date();

  // Prorate: preserve remaining days from current monthly period
  const remainingDays = Math.max(0, Math.ceil(
    (currentNextBilling.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
  ));
  const newBillingDate = new Date(now.getTime() + (365 + remainingDays) * 24 * 60 * 60 * 1000);

  await snap.docs[0].ref.update({
    packageId, planType: 'yearly', duration: 365,
    nextBillingDate: admin.firestore.Timestamp.fromDate(newBillingDate),
    status: 'active', isActive: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { success: true, newBillingDate: newBillingDate.toISOString() };
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
    const snap = await db.collection('subscriptions')
      .where('originalTransactionId', '==', originalTransactionId)
      .limit(1).get();

    if (snap.empty) {
      // Existing subscriber: originalTransactionId not yet stored (pre-deployment purchase).
      // Will self-heal on their next purchase through validatePurchaseReceipt.
      console.warn(`⚠️ appStoreWebhook: No subscription found for txn ${originalTransactionId}. ` +
        'Existing subscriber without originalTransactionId — will self-heal on next purchase.');
      await db.collection('processedWebhooks').doc(notificationUUID).set({
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationType,
        subtype: subtype ?? null,
        originalTransactionId,
        result: 'subscription_not_found',
      });
      res.status(200).json({ received: true });
      return;
    }

    const subRef = snap.docs[0].ref;
    const subData = snap.docs[0].data();
    const userId = subData.userId as string;
    const userRef = db.collection('users').doc(userId);
    const now = admin.firestore.FieldValue.serverTimestamp();
    // expiresDate is Unix milliseconds per JWSTransactionDecodedPayload
    const expiresTimestamp = expiresDate
      ? admin.firestore.Timestamp.fromMillis(expiresDate)
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
    batch.update(subRef, subUpdates);
    if (userUpdates) {
      batch.set(userRef, userUpdates, { merge: true });
    }
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
    // Always return 200 — non-200 causes Apple to retry for our own bugs
    res.status(200).json({ received: true });
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
    try {
      const dataStr = Buffer.from(message.data, 'base64').toString('utf-8');
      const notification = JSON.parse(dataStr);

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
      const alreadyProcessed = await db.collection('processedWebhooks').doc(`gp_${messageId}`).get();
      if (alreadyProcessed.exists) {
        console.log(`⏭️ handleGooglePlayNotifications: Already processed ${messageId}`);
        return;
      }

      const subSnap = await db.collection('subscriptions')
        .where('androidPurchaseToken', '==', purchaseToken)
        .limit(1).get();

      if (subSnap.empty) {
        // Existing subscriber: androidPurchaseToken not yet stored (pre-deployment purchase).
        // Will self-heal on their next purchase through validatePurchaseReceipt.
        console.warn('⚠️ handleGooglePlayNotifications: No subscription found for purchaseToken. ' +
          'Existing subscriber without androidPurchaseToken — will self-heal on next purchase.');
        await db.collection('processedWebhooks').doc(`gp_${messageId}`).set({
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          notificationType,
          result: 'subscription_not_found',
        });
        return;
      }

      const subRef = subSnap.docs[0].ref;
      const subData = subSnap.docs[0].data();
      const userId = subData.userId as string;
      const userRef = db.collection('users').doc(userId);
      const now = admin.firestore.FieldValue.serverTimestamp();

      // Notification type integers from Google Play Developer API:
      // 1=RECOVERED, 2=RENEWED, 3=CANCELED, 4=PURCHASED, 5=ON_HOLD,
      // 6=IN_GRACE_PERIOD, 7=RESTARTED, 8=PAUSE_SCHEDULE_CHANGED, 12=REVOKED, 13=EXPIRED
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let subUpdates: Record<string, any> = { updatedAt: now };
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let userUpdates: Record<string, any> | null = null;
      let logAction = `google_play_${notificationType}`;

      // BUG B4 FIX: For renewal events, fetch the real expiryTime from the Google Play Developer API.
      // Without this, nextBillingDate stays in the past and the 6-hour renewal scheduler re-enters
      // grace period every run, creating a permanent active→past_due flip-flop for Android users.
      let newBillingDate: admin.firestore.Timestamp | null = null;
      if ([1, 2, 4, 7].includes(notificationType as number)) {
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
              newBillingDate = admin.firestore.Timestamp.fromMillis(expiryMs);
            }
          }
        } catch (apiErr) {
          console.warn('⚠️ handleGooglePlayNotifications: Could not fetch expiry from Play API, ' +
            'falling back to heuristic extension:', apiErr);
          // Heuristic fallback: advance nextBillingDate by one billing cycle so the renewal
          // scheduler does not immediately re-enter grace period before the real date is known.
          const currentDate = (subData.nextBillingDate as admin.firestore.Timestamp | undefined)
            ?.toDate() ?? new Date();
          const billingDuration = (subData.duration as number | undefined) ?? 30;
          const extended = new Date(Math.max(currentDate.getTime(), Date.now()));
          extended.setDate(extended.getDate() + billingDuration);
          newBillingDate = admin.firestore.Timestamp.fromDate(extended);
        }
      }

      switch (notificationType as number) {
        case 1: case 2: case 4: case 7: // RECOVERED, RENEWED, PURCHASED, RESTARTED
          subUpdates = {
            ...subUpdates,
            isActive: true,
            status: 'active',
            renewalAttempts: 0,
            ...(newBillingDate && { nextBillingDate: newBillingDate }),
          };
          userUpdates = {
            isActive: true,
            ...(newBillingDate && { nextBillingDate: newBillingDate }),
            lastUpdated: now,
          };
          logAction = 'google_renewed';
          break;
        case 3: // CANCELED — access continues until nextBillingDate
          subUpdates = { ...subUpdates, status: 'canceled' };
          logAction = 'google_cancel_requested';
          break;
        case 5: case 6: // ON_HOLD, IN_GRACE_PERIOD
          subUpdates = { ...subUpdates, status: 'past_due' };
          break;
        case 12: case 13: // REVOKED, EXPIRED
          subUpdates = { ...subUpdates, isActive: false, status: 'inactive' };
          userUpdates = { isActive: false, lastUpdated: now };
          logAction = 'google_expired';
          break;
        default:
          console.log(`ℹ️ handleGooglePlayNotifications: Unhandled type ${notificationType}`);
          await db.collection('processedWebhooks').doc(`gp_${messageId}`).set({
            processedAt: now, notificationType, result: 'unhandled_type',
          });
          return;
      }

      const batch = db.batch();
      batch.update(subRef, subUpdates);
      if (userUpdates) {
        batch.set(userRef, userUpdates, { merge: true });
      }
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
      // Do NOT rethrow — Pub/Sub retries on thrown errors
    }
  });
