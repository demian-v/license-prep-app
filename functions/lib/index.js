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
exports.getPracticeTests = exports.getTheoryModules = exports.getTrafficRuleTopics = exports.getQuizQuestions = exports.contentGetQuizTopics = exports.getQuizTopics = void 0;
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
        const { licenseType, language, state, limit = 10 } = data;
        if (!licenseType || !language || !state) {
            throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters: licenseType, language, and state are required');
        }
        console.log(`Fetching theory modules for licenseType: ${licenseType}, language: ${language}, state: ${state}`);
        // Query Firestore for theory modules
        let query = db.collection('theoryModules')
            .where('licenseId', '==', licenseType)
            .where('language', '==', language)
            .where('state', 'in', [state, 'ALL'])
            .orderBy('order');
        if (limit && limit > 0) {
            query = query.limit(limit);
        }
        const snapshot = await query.get();
        console.log(`Found ${snapshot.docs.length} theory modules`);
        // Process results
        const modules = snapshot.docs.map(doc => {
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
                order: data.order || 0
            };
        });
        console.log(`Returning ${modules.length} processed theory modules`);
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
//# sourceMappingURL=index.js.map