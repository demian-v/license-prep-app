import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { 
  processExpiredSubscriptions, 
  testSubscriptionProcessing,
  getSubscriptionStatistics 
} from './subscription-manager';
import {
  generateAllTestData,
  cleanupTestData,
  createQuickTestScenario,
  verifyTestData
} from './test-data-generator';

// Initialize Firebase Admin
admin.initializeApp();

// Get Firestore reference
const db = admin.firestore();

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
        
        console.log(`Processing question ${data.id || doc.id}: correctAnswer = ${correctAnswer}`);
        
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
        
        console.log(`Processing module ${data.id || doc.id}: state=${data.state}, language=${data.language}`);
        
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
        console.log(`Module ${module.id}: language=${module.language} (${languageMatch}), state=${module.state} (${stateMatch})`);
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
