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
exports.createOrUpdateUserDocument = exports.getUserData = exports.updateUserState = exports.updateUserLanguage = exports.getPracticeTests = exports.getTheoryModules = exports.getTrafficRuleTopics = exports.getQuizQuestions = exports.contentGetQuizTopics = exports.getQuizTopics = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
// Initialize Firebase Admin
admin.initializeApp();
// Get Firestore reference
const db = admin.firestore();
// Content functions
exports.getQuizTopics = functions.https.onCall(async (data, context) => {
    try {
        console.log('getQuizTopics called with data:', data);
        // Validate required parameters
        const { language, state, limit = 10 } = data;
        if (!language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: language and state are required');
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
    }
    catch (error) {
        console.error('Error in getQuizTopics:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to fetch quiz topics: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Alternative function name with content prefix (in case the mapping expects this)
exports.contentGetQuizTopics = functions.https.onCall(async (data, context) => {
    try {
        console.log('contentGetQuizTopics called with data:', data);
        // Validate required parameters
        const { language, state, limit = 10 } = data;
        if (!language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: language and state are required');
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
    }
    catch (error) {
        console.error('Error in contentGetQuizTopics:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to fetch quiz topics: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Quiz Questions function
exports.getQuizQuestions = functions.https.onCall(async (data, context) => {
    try {
        console.log('getQuizQuestions called with data:', data);
        // Validate required parameters
        const { topicId, language, state } = data;
        if (!topicId || !language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: topicId, language, and state are required');
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
        }
        catch (indexError) {
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
                imagePath: data.imagePath || null,
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
    }
    catch (error) {
        console.error('Error in getQuizQuestions:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to fetch quiz questions: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Traffic Rule Topics function
exports.getTrafficRuleTopics = functions.https.onCall(async (data, context) => {
    try {
        console.log('getTrafficRuleTopics called with data:', data);
        // Validate required parameters
        const { language, state, limit = 10 } = data;
        if (!language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: language and state are required');
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
                content: data.content || '',
                language: data.language,
                state: data.state,
                order: data.order || 0
            };
        });
        console.log(`Returning ${topics.length} processed traffic rule topics`);
        return topics;
    }
    catch (error) {
        console.error('Error in getTrafficRuleTopics:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to fetch traffic rule topics: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Theory Modules function
exports.getTheoryModules = functions.https.onCall(async (data, context) => {
    try {
        console.log('getTheoryModules called with data:', data);
        // Validate required parameters
        const { licenseType, language, state } = data;
        if (!licenseType || !language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: licenseType, language, and state are required');
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
        }
        catch (indexError) {
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
    }
    catch (error) {
        console.error('Error in getTheoryModules:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to fetch theory modules: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Practice Tests function
exports.getPracticeTests = functions.https.onCall(async (data, context) => {
    try {
        console.log('getPracticeTests called with data:', data);
        // Validate required parameters
        const { licenseType, language, state, limit = 10 } = data;
        if (!licenseType || !language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: licenseType, language, and state are required');
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
    }
    catch (error) {
        console.error('Error in getPracticeTests:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to fetch practice tests: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// User Management Functions
// Update user language preference
exports.updateUserLanguage = functions.https.onCall(async (data, context) => {
    try {
        console.log('updateUserLanguage called with data:', data);
        // Validate authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to update language');
        }
        const userId = context.auth.uid;
        const { language } = data;
        // Validate language parameter
        if (!language) {
            throw new functions.https.HttpsError('invalid-argument', 'Language is required');
        }
        // Validate language code
        const validLanguages = ['en', 'uk', 'ru', 'es', 'pl'];
        if (!validLanguages.includes(language)) {
            throw new functions.https.HttpsError('invalid-argument', `Invalid language code. Must be one of: ${validLanguages.join(', ')}`);
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
    }
    catch (error) {
        console.error('Error in updateUserLanguage:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to update language: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Update user state preference
exports.updateUserState = functions.https.onCall(async (data, context) => {
    try {
        console.log('updateUserState called with data:', data);
        // Validate authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to update state');
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
    }
    catch (error) {
        console.error('Error in updateUserState:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to update state: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Get current user data
exports.getUserData = functions.https.onCall(async (data, context) => {
    try {
        console.log('getUserData called');
        // Validate authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to get user data');
        }
        const userId = context.auth.uid;
        console.log(`Getting user data for user: ${userId}`);
        // Get user document from Firestore
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'User document not found');
        }
        const userData = userDoc.data();
        if (!userData) {
            throw new functions.https.HttpsError('not-found', 'User data is empty');
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
    }
    catch (error) {
        console.error('Error in getUserData:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to get user data: ' + (error instanceof Error ? error.message : String(error)));
    }
});
// Create or update user document
exports.createOrUpdateUserDocument = functions.https.onCall(async (data, context) => {
    try {
        console.log('createOrUpdateUserDocument called with data:', data);
        // Validate authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to create/update user document');
        }
        const userId = context.auth.uid;
        const { name, email, language, state, userId: providedUserId } = data;
        // Ensure user can only update their own document
        if (providedUserId && providedUserId !== userId) {
            throw new functions.https.HttpsError('permission-denied', 'Users can only update their own documents');
        }
        // Validate required fields
        if (!name || !email) {
            throw new functions.https.HttpsError('invalid-argument', 'Name and email are required');
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
        }
        else {
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
    }
    catch (error) {
        console.error('Error in createOrUpdateUserDocument:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', 'Failed to create/update user document: ' + (error instanceof Error ? error.message : String(error)));
    }
});
//# sourceMappingURL=index.js.map