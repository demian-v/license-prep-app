import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CounterService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generates next global report ID in format: {globalId}_user_{userId}_report_{userNumber}
  Future<String> getNextGlobalReportId(String userId) async {
    final globalCounterRef = _db.collection('counters').doc('global_report_counter');
    final userCounterRef = _db.collection('counters').doc('user_${userId}_reports');
    
    print('CounterService: Attempting to get next global ID for user: $userId');
    print('CounterService: Global counter ref: global_report_counter');
    print('CounterService: User counter ref: user_${userId}_reports');
    
    // Retry logic with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print('CounterService: Starting dual transaction attempt $attempt');
        final reportId = await _db.runTransaction<String>((transaction) async {
          print('CounterService: Dual transaction attempt $attempt started');
          
          // Read both counters
          final globalDoc = await transaction.get(globalCounterRef);
          final userDoc = await transaction.get(userCounterRef);
          
          // Calculate next values
          int nextGlobalValue = 1;
          int nextUserValue = 1;
          
          if (globalDoc.exists) {
            final globalData = globalDoc.data();
            final currentGlobalValue = (globalData?['value'] ?? 0) as int;
            nextGlobalValue = currentGlobalValue + 1;
            print('CounterService: Existing global counter value: $currentGlobalValue, next: $nextGlobalValue');
          } else {
            print('CounterService: Creating new global counter document with value: $nextGlobalValue');
          }
          
          if (userDoc.exists) {
            final userData = userDoc.data();
            final currentUserValue = (userData?['value'] ?? 0) as int;
            nextUserValue = currentUserValue + 1;
            print('CounterService: Existing user counter value: $currentUserValue, next: $nextUserValue');
          } else {
            print('CounterService: Creating new user counter document with value: $nextUserValue');
          }
          
          // Update global counter
          transaction.set(globalCounterRef, {
            'value': nextGlobalValue,
            'lastUpdated': FieldValue.serverTimestamp(),
            'description': 'Global sequential counter for all reports',
          }, SetOptions(merge: true));
          
          // Update user counter
          transaction.set(userCounterRef, {
            'value': nextUserValue,
            'lastUpdated': FieldValue.serverTimestamp(),
            'userId': userId,
          }, SetOptions(merge: true));
          
          // Generate combined ID: {globalId}_user_{userId}_report_{userNumber}
          final generatedId = '${nextGlobalValue}_user_${userId}_report_$nextUserValue';
          print('CounterService: Generated global report ID: $generatedId');
          print('CounterService: Global counter: $nextGlobalValue, User counter: $nextUserValue');
          return generatedId;
        });
        
        print('CounterService: Dual transaction successful: $reportId');
        return reportId;
      } on FirebaseException catch (e) {
        print('CounterService: Firebase error on attempt $attempt: ${e.code} - ${e.message}');
        
        if (attempt == 3) {
          print('CounterService: All attempts failed, using fallback ID');
          return _generateGlobalFallbackId(userId);
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * pow(2, attempt - 1).toInt()));
      } catch (e) {
        print('CounterService: Unexpected error on attempt $attempt: $e');
        
        if (attempt == 3) {
          print('CounterService: All attempts failed, using fallback ID');
          return _generateGlobalFallbackId(userId);
        }
        
        await Future.delayed(Duration(milliseconds: 100 * pow(2, attempt - 1).toInt()));
      }
    }
    
    // Should never reach here, but just in case
    print('CounterService: Unexpected fallthrough, using fallback ID');
    return _generateGlobalFallbackId(userId);
  }

  /// Generates next user-specific report ID in format: user_{userId}_report_{number}
  /// [DEPRECATED] Use getNextGlobalReportId instead for new implementations
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
    
    // Use new global ID generation instead of user-specific
    return await getNextGlobalReportId(user.uid);
  }

  /// Generates fallback ID with global format when transaction fails
  String _generateGlobalFallbackId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(1000).toString().padLeft(3, '0');
    // Include global prefix even in fallback (using timestamp as global ID)
    return '${timestamp}_user_${userId}_report_fallback_$randomSuffix';
  }

  /// Generates fallback ID when transaction fails (legacy format)
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

  /// Gets current global counter value (useful for debugging)
  Future<int> getCurrentGlobalCounterValue() async {
    try {
      final doc = await _db.collection('counters').doc('global_report_counter').get();
      
      if (doc.exists) {
        final data = doc.data();
        return (data?['value'] ?? 0) as int;
      }
      return 0;
    } catch (e) {
      print('CounterService: Error getting global counter value: $e');
      return 0;
    }
  }

  /// Initialize global counter based on existing reports count (migration utility)
  Future<void> initializeGlobalCounterFromExistingReports() async {
    try {
      print('CounterService: Starting global counter initialization...');
      
      // Count all existing reports
      final reportsSnapshot = await _db.collection('reports').get();
      final existingReportsCount = reportsSnapshot.docs.length;
      
      print('CounterService: Found $existingReportsCount existing reports');
      
      // Set global counter to existing count (new reports will start from count + 1)
      await _db.collection('counters').doc('global_report_counter').set({
        'value': existingReportsCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'description': 'Global sequential counter for all reports',
        'initializedFrom': 'existing_reports_count',
        'initialCount': existingReportsCount,
      });
      
      print('CounterService: Global counter initialized with value: $existingReportsCount');
    } catch (e) {
      print('CounterService: Error initializing global counter: $e');
      rethrow;
    }
  }

  /// Query all reports for a specific user (supports both old and new formats)
  Future<List<QueryDocumentSnapshot>> getUserReports(String userId) async {
    try {
      // Query for both old format (user_{userId}_report_*) and new format (*_user_{userId}_report_*)
      final List<QueryDocumentSnapshot> allReports = [];
      
      // Query old format reports
      final oldFormatQuery = await _db.collection('reports')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: 'user_${userId}_report_')
        .where(FieldPath.documentId, isLessThan: 'user_${userId}_report_z')
        .get();
      
      allReports.addAll(oldFormatQuery.docs);
      
      // Query new format reports (this is more complex due to the global prefix)
      // We'll get all reports and filter in memory for now
      // TODO: Consider adding a userId field to reports for more efficient querying
      final allReportsQuery = await _db.collection('reports').get();
      
      final newFormatReports = allReportsQuery.docs.where((doc) {
        final id = doc.id;
        // Check if it matches the new format: {number}_user_{userId}_report_{number}
        final regex = RegExp(r'^\d+_user_' + userId + r'_report_\d+$');
        return regex.hasMatch(id);
      }).toList();
      
      allReports.addAll(newFormatReports);
      
      // Sort by document ID in descending order
      allReports.sort((a, b) => b.id.compareTo(a.id));
      
      // Remove duplicates (shouldn't happen, but just in case)
      final uniqueReports = <String, QueryDocumentSnapshot>{};
      for (final doc in allReports) {
        uniqueReports[doc.id] = doc;
      }
      
      return uniqueReports.values.toList();
    } catch (e) {
      print('CounterService: Error querying user reports: $e');
      return [];
    }
  }

  /// Reset global counter (admin function)
  Future<void> resetGlobalCounter({int newValue = 0}) async {
    try {
      await _db.collection('counters').doc('global_report_counter').set({
        'value': newValue,
        'lastUpdated': FieldValue.serverTimestamp(),
        'resetAt': FieldValue.serverTimestamp(),
        'description': 'Global sequential counter for all reports',
      });
      
      print('CounterService: Reset global counter to $newValue');
    } catch (e) {
      print('CounterService: Error resetting global counter: $e');
      rethrow;
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
