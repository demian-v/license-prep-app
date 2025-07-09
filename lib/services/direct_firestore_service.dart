import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Direct Firestore Service for backup operations
/// This service bypasses Firebase Functions and directly interacts with Firestore
/// Used as a fallback when Firebase Functions are not available
class DirectFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Add a saved question directly to Firestore (Updated for single-document structure)
  /// Uses document ID: {userId}
  Future<void> addSavedQuestionDirect(String userId, String questionId) async {
    try {
      debugPrint('🔥 DirectFirestoreService: Adding saved question $questionId for user $userId');
      
      if (userId.isEmpty || questionId.isEmpty) {
        throw 'Invalid parameters: userId="$userId", questionId="$questionId"';
      }
      
      final docRef = _firestore.collection('savedQuestions').doc(userId);
      final userDoc = await docRef.get();
      
      if (userDoc.exists) {
        // Update existing document
        final data = userDoc.data();
        final itemIds = List<String>.from(data?['itemIds'] ?? []);
        
        // Check if question is already saved
        if (itemIds.contains(questionId)) {
          debugPrint('🔥 DirectFirestoreService: Question $questionId already saved for user $userId');
          return; // Already saved, nothing to do
        }
        
        // Add question to array and update order
        await docRef.update({
          'itemIds': FieldValue.arrayUnion([questionId]),
          'order.$questionId': DateTime.now().millisecondsSinceEpoch,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
      } else {
        // Create new document
        final savedQuestionData = {
          'userId': userId,
          'itemIds': [questionId],
          'order': {questionId: DateTime.now().millisecondsSinceEpoch},
          'savedAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        await docRef.set(savedQuestionData);
      }
      
      debugPrint('🔥 DirectFirestoreService: Successfully saved question $questionId for user $userId');
      
    } catch (e) {
      debugPrint('🔥 DirectFirestoreService: Error adding saved question: $e');
      rethrow;
    }
  }
  
  /// Remove a saved question directly from Firestore (Updated for single-document structure)
  /// Uses document ID: {userId}
  Future<void> removeSavedQuestionDirect(String userId, String questionId) async {
    try {
      debugPrint('DirectFirestoreService: Removing saved question $questionId for user $userId');
      
      final docRef = _firestore.collection('savedQuestions').doc(userId);
      final userDoc = await docRef.get();
      
      if (!userDoc.exists) {
        debugPrint('DirectFirestoreService: No saved questions document found for user $userId');
        return; // No document, nothing to do
      }
      
      final data = userDoc.data();
      final itemIds = List<String>.from(data?['itemIds'] ?? []);
      
      // Check if question is in the saved list
      if (!itemIds.contains(questionId)) {
        debugPrint('DirectFirestoreService: Question $questionId not found in saved questions for user $userId');
        return; // Not saved, nothing to do
      }
      
      // Remove question from array and order map
      await docRef.update({
        'itemIds': FieldValue.arrayRemove([questionId]),
        'order.$questionId': FieldValue.delete(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('DirectFirestoreService: Successfully removed saved question $questionId for user $userId');
      
    } catch (e) {
      debugPrint('DirectFirestoreService: Error removing saved question: $e');
      rethrow;
    }
  }
  
  /// Get all saved questions for a user directly from Firestore (Updated for single-document structure)
  /// Returns list of question IDs
  Future<List<String>> getSavedQuestionsDirect(String userId) async {
    try {
      debugPrint('DirectFirestoreService: Getting saved questions for user $userId');
      
      // Get single document for this user
      final userDoc = await _firestore.collection('savedQuestions').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('DirectFirestoreService: No saved questions document found for user $userId');
        return [];
      }
      
      final data = userDoc.data();
      final itemIds = List<String>.from(data?['itemIds'] ?? []);
      final orderMap = Map<String, int>.from(data?['order'] ?? {});
      
      // Sort by order (newest first)
      itemIds.sort((a, b) => (orderMap[b] ?? 0).compareTo(orderMap[a] ?? 0));
      
      debugPrint('DirectFirestoreService: Returning ${itemIds.length} saved question IDs');
      return itemIds;
      
    } catch (e) {
      debugPrint('DirectFirestoreService: Error getting saved questions: $e');
      rethrow;
    }
  }

  /// Get saved questions with timestamps for sorting (Updated for single-document structure)
  /// Returns list of maps with questionId and savedAt timestamp
  Future<List<Map<String, dynamic>>> getSavedQuestionsWithTimestamps(String userId) async {
    try {
      debugPrint('DirectFirestoreService: Getting saved questions with timestamps for user $userId');
      
      // Get single document for this user
      final userDoc = await _firestore.collection('savedQuestions').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('DirectFirestoreService: No saved questions document found for user $userId');
        return [];
      }
      
      final data = userDoc.data();
      final itemIds = List<String>.from(data?['itemIds'] ?? []);
      final orderMap = Map<String, int>.from(data?['order'] ?? {});
      final savedAt = data?['savedAt'] as Timestamp?;
      
      // Create list of maps with questionId and order timestamp
      final savedQuestionsData = itemIds.map((questionId) {
        return {
          'questionId': questionId,
          'savedAt': savedAt, // Document creation timestamp
          'order': orderMap[questionId] ?? 0, // Individual question order
        };
      }).toList();
      
      // Sort by order timestamp (newest first)
      savedQuestionsData.sort((a, b) {
        final aOrder = a['order'] as int;
        final bOrder = b['order'] as int;
        return bOrder.compareTo(aOrder); // Descending order (newest first)
      });
      
      debugPrint('DirectFirestoreService: Returning ${savedQuestionsData.length} saved questions sorted by timestamp');
      return savedQuestionsData;
      
    } catch (e) {
      debugPrint('DirectFirestoreService: Error getting saved questions with timestamps: $e');
      rethrow;
    }
  }
  
  /// Check if a question is saved for a user (Updated for single-document structure)
  /// Returns true if the question is saved, false otherwise
  Future<bool> isQuestionSavedDirect(String userId, String questionId) async {
    try {
      final userDoc = await _firestore.collection('savedQuestions').doc(userId).get();
      
      if (!userDoc.exists) {
        return false;
      }
      
      final data = userDoc.data();
      final itemIds = List<String>.from(data?['itemIds'] ?? []);
      
      return itemIds.contains(questionId);
    } catch (e) {
      debugPrint('DirectFirestoreService: Error checking if question is saved: $e');
      return false; // Default to false on error
    }
  }
  
  /// Get the count of saved questions for a user (Updated for single-document structure)
  Future<int> getSavedQuestionsCountDirect(String userId) async {
    try {
      final userDoc = await _firestore.collection('savedQuestions').doc(userId).get();
      
      if (!userDoc.exists) {
        return 0;
      }
      
      final data = userDoc.data();
      final itemIds = List<String>.from(data?['itemIds'] ?? []);
      
      return itemIds.length;
    } catch (e) {
      debugPrint('DirectFirestoreService: Error getting saved questions count: $e');
      return 0; // Default to 0 on error
    }
  }
}
