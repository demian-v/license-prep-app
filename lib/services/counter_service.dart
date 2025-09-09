import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CounterService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates next user-specific report ID in format: user_{userId}_report_{number}
  Future<String> getNextUserReportId(String userId) async {
    final counterDocId = 'user_${userId}_reports';
    print('CounterService: Attempting to get next ID for user: $userId');
    print('CounterService: Counter document ID: $counterDocId');
    
    // Retry logic with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('CounterService: Starting transaction attempt $attempt');
        final reportId = await _db.runTransaction<String>((transaction) async {
          print('CounterService: Transaction attempt $attempt started');
          final counterRef = _db.collection('counters').doc(counterDocId);
          final counterDoc = await transaction.get(counterRef);
          
          int nextValue = 1;
          if (counterDoc.exists) {
            final data = counterDoc.data();
            final currentValue = (data?['value'] ?? 0) as int;
            nextValue = currentValue + 1;
            print('CounterService: Existing counter value: $currentValue, next: $nextValue');
          } else {
            print('CounterService: Creating new counter document with value: $nextValue');
          }
          
          // Update counter with new value
          transaction.set(counterRef, {
            'value': nextValue,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userId': userId,
          }, SetOptions(merge: true));
          
          final generatedId = 'user_${userId}_report_$nextValue';
          print('CounterService: Generated ID: $generatedId');
          return generatedId;
        });
        
        print('CounterService: Transaction successful: $reportId');
        return reportId;
      } on FirebaseException catch (e) {
        print('CounterService: Firebase error on attempt $attempt: ${e.code} - ${e.message}');
        
        if (attempt == 3) {
          print('CounterService: All attempts failed, using fallback ID');
          return _generateFallbackId(userId);
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * pow(2, attempt - 1).toInt()));
      } catch (e) {
        print('CounterService: Unexpected error on attempt $attempt: $e');
        
        if (attempt == 3) {
          print('CounterService: All attempts failed, using fallback ID');
          return _generateFallbackId(userId);
        }
        
        await Future.delayed(Duration(milliseconds: 100 * pow(2, attempt - 1).toInt()));
      }
    }
    
    // Should never reach here, but just in case
    print('CounterService: Unexpected fallthrough, using fallback ID');
    return _generateFallbackId(userId);
  }

  /// Convenience method that gets userId from current auth user
  Future<String> getNextReportId() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to generate report ID');
    }
    
    return await getNextUserReportId(user.uid);
  }

  /// Generates fallback ID when transaction fails
  String _generateFallbackId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(1000).toString().padLeft(3, '0');
    return 'user_${userId}_report_${timestamp}_$randomSuffix';
  }

  /// Gets current counter value for a user (useful for debugging)
  Future<int> getCurrentCounterValue(String userId) async {
    try {
      final counterDocId = 'user_${userId}_reports';
      final doc = await _db.collection('counters').doc(counterDocId).get();
      
      if (doc.exists) {
        final data = doc.data();
        return (data?['value'] ?? 0) as int;
      }
      return 0;
    } catch (e) {
      print('CounterService: Error getting counter value: $e');
      return 0;
    }
  }

  /// Query all reports for a specific user
  Future<List<QueryDocumentSnapshot>> getUserReports(String userId) async {
    try {
      final querySnapshot = await _db.collection('reports')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'user_${userId}_report_')
        .where(FieldPath.documentId, isLessThan: 'user_${userId}_report_z')
        .orderBy(FieldPath.documentId, descending: true)
        .get();
      
      return querySnapshot.docs;
    } catch (e) {
      print('CounterService: Error querying user reports: $e');
      return [];
    }
  }

  /// Reset counter for a user (admin function)
  Future<void> resetUserCounter(String userId, {int newValue = 0}) async {
    try {
      final counterDocId = 'user_${userId}_reports';
      await _db.collection('counters').doc(counterDocId).set({
        'value': newValue,
        'lastUpdated': FieldValue.serverTimestamp(),
        'userId': userId,
        'resetAt': FieldValue.serverTimestamp(),
      });
      
      print('CounterService: Reset counter for user $userId to $newValue');
    } catch (e) {
      print('CounterService: Error resetting counter: $e');
      rethrow;
    }
  }
}
