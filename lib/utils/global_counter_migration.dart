import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/counter_service.dart';

/// Migration utility for initializing the global report counter
class GlobalCounterMigration {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CounterService _counterService = CounterService();

  /// Initialize the global counter based on existing reports
  Future<void> initializeGlobalCounter() async {
    try {
      print('🚀 GlobalCounterMigration: Starting global counter initialization...');
      
      // Check if global counter already exists
      final existingCounter = await _db.collection('counters')
          .doc('global_report_counter')
          .get();
      
      if (existingCounter.exists) {
        final currentValue = (existingCounter.data()?['value'] ?? 0) as int;
        print('✅ GlobalCounterMigration: Global counter already exists with value: $currentValue');
        print('💡 GlobalCounterMigration: Skipping initialization. If you need to reset, use resetGlobalCounter()');
        return;
      }
      
      // Count all existing reports
      print('📊 GlobalCounterMigration: Counting existing reports...');
      final reportsSnapshot = await _db.collection('reports').get();
      final existingReportsCount = reportsSnapshot.docs.length;
      
      print('📋 GlobalCounterMigration: Found $existingReportsCount existing reports');
      
      // Display some sample existing report IDs for verification
      if (reportsSnapshot.docs.isNotEmpty) {
        print('📝 GlobalCounterMigration: Sample existing report IDs:');
        final sampleCount = reportsSnapshot.docs.length > 5 ? 5 : reportsSnapshot.docs.length;
        for (int i = 0; i < sampleCount; i++) {
          print('   - ${reportsSnapshot.docs[i].id}');
        }
        if (reportsSnapshot.docs.length > 5) {
          print('   ... and ${reportsSnapshot.docs.length - 5} more reports');
        }
      }
      
      // Initialize global counter using CounterService method
      await _counterService.initializeGlobalCounterFromExistingReports();
      
      // Verify initialization
      final newCounterValue = await _counterService.getCurrentGlobalCounterValue();
      print('✅ GlobalCounterMigration: Global counter successfully initialized!');
      print('🔢 GlobalCounterMigration: Current global counter value: $newCounterValue');
      print('📈 GlobalCounterMigration: Next report will have global ID: ${newCounterValue + 1}');
      
    } catch (e) {
      print('❌ GlobalCounterMigration: Error during initialization: $e');
      rethrow;
    }
  }

  /// Test the new global ID generation (for verification)
  Future<void> testGlobalIdGeneration({required String testUserId}) async {
    try {
      print('🧪 GlobalCounterMigration: Testing global ID generation...');
      print('👤 GlobalCounterMigration: Test user ID: $testUserId');
      
      // Get current counters before test
      final globalBefore = await _counterService.getCurrentGlobalCounterValue();
      final userBefore = await _counterService.getCurrentCounterValue(testUserId);
      
      print('📊 GlobalCounterMigration: Before test - Global: $globalBefore, User: $userBefore');
      
      // Generate test ID (this will actually increment the counters)
      print('⚠️  GlobalCounterMigration: WARNING - This will create actual counter increments!');
      print('⚠️  GlobalCounterMigration: Only run this in development/testing environment!');
      
      // Uncomment the next lines to actually test (commented for safety)
      /*
      final testReportId = await _counterService.getNextGlobalReportId(testUserId);
      print('🆔 GlobalCounterMigration: Generated test ID: $testReportId');
      
      // Get counters after test
      final globalAfter = await _counterService.getCurrentGlobalCounterValue();
      final userAfter = await _counterService.getCurrentCounterValue(testUserId);
      
      print('📊 GlobalCounterMigration: After test - Global: $globalAfter, User: $userAfter');
      print('✅ GlobalCounterMigration: Test completed successfully!');
      */
      
      print('💡 GlobalCounterMigration: Test skipped for safety. Uncomment code in testGlobalIdGeneration() to run actual test.');
      
    } catch (e) {
      print('❌ GlobalCounterMigration: Error during testing: $e');
      rethrow;
    }
  }

  /// Display current counter status
  Future<void> displayCounterStatus() async {
    try {
      print('📊 GlobalCounterMigration: Current Counter Status');
      print('=' * 50);
      
      // Global counter
      final globalValue = await _counterService.getCurrentGlobalCounterValue();
      print('🌍 Global Counter: $globalValue');
      
      // Check if global counter document exists
      final globalDoc = await _db.collection('counters').doc('global_report_counter').get();
      if (globalDoc.exists) {
        final data = globalDoc.data()!;
        print('   📅 Last Updated: ${data['lastUpdated']}');
        print('   📝 Description: ${data['description'] ?? 'N/A'}');
        if (data.containsKey('initialCount')) {
          print('   🔢 Initialized From: ${data['initialCount']} existing reports');
        }
      } else {
        print('   ❌ Global counter document does not exist');
      }
      
      // Sample user counters
      print('\n👥 Sample User Counters:');
      final allCounters = await _db.collection('counters').get();
      
      // Filter out global counter
      final userCounterDocs = allCounters.docs
          .where((doc) => doc.id != 'global_report_counter')
          .take(5)
          .toList();
      
      if (userCounterDocs.isEmpty) {
        print('   📭 No user counters found');
      } else {
        for (final doc in userCounterDocs) {
          final data = doc.data();
          final userId = data['userId'] ?? 'unknown';
          final value = data['value'] ?? 0;
          print('   👤 User ${userId}: $value reports');
        }
        
        // Count total user counters
        final totalUserCounters = allCounters.docs
            .where((doc) => doc.id != 'global_report_counter')
            .length;
        
        if (totalUserCounters > 5) {
          print('   ... and ${totalUserCounters - 5} more users');
        }
      }
      
      // Recent reports
      print('\n📋 Recent Reports (showing ID format):');
      final recentReports = await _db.collection('reports')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(5)
          .get();
      
      if (recentReports.docs.isEmpty) {
        print('   📭 No reports found');
      } else {
        for (final doc in recentReports.docs) {
          final id = doc.id;
          final isGlobalFormat = RegExp(r'^\d+_user_\w+_report_\d+$').hasMatch(id);
          final isLegacyFormat = RegExp(r'^user_\w+_report_\d+$').hasMatch(id);
          
          String formatType = 'Unknown';
          if (isGlobalFormat) formatType = '🆕 Global';
          else if (isLegacyFormat) formatType = '🔄 Legacy';
          
          print('   📄 $formatType: $id');
        }
      }
      
      print('=' * 50);
    } catch (e) {
      print('❌ GlobalCounterMigration: Error displaying status: $e');
      rethrow;
    }
  }

  /// Reset global counter (admin function - use with caution!)
  Future<void> resetGlobalCounter({int newValue = 0, bool confirmed = false}) async {
    if (!confirmed) {
      print('⚠️  GlobalCounterMigration: DANGER - This will reset the global counter!');
      print('⚠️  GlobalCounterMigration: Call with confirmed: true to proceed');
      print('⚠️  GlobalCounterMigration: New value would be: $newValue');
      return;
    }
    
    try {
      print('🔄 GlobalCounterMigration: Resetting global counter to $newValue...');
      
      await _counterService.resetGlobalCounter(newValue: newValue);
      
      print('✅ GlobalCounterMigration: Global counter reset completed!');
      print('🔢 GlobalCounterMigration: New value: $newValue');
      
    } catch (e) {
      print('❌ GlobalCounterMigration: Error resetting global counter: $e');
      rethrow;
    }
  }
}

/// Example usage script
void main() async {
  final migration = GlobalCounterMigration();
  
  print('🚀 Global Counter Migration Script');
  print('==================================');
  
  try {
    // Step 1: Display current status
    await migration.displayCounterStatus();
    
    // Step 2: Initialize global counter if needed
    await migration.initializeGlobalCounter();
    
    // Step 3: Display status after initialization
    print('\n📊 Status After Initialization:');
    await migration.displayCounterStatus();
    
    // Step 4: Test ID generation (optional and safe)
    await migration.testGlobalIdGeneration(testUserId: 'test_user_migration');
    
    print('\n✅ Migration script completed successfully!');
    
  } catch (e) {
    print('\n❌ Migration script failed: $e');
  }
}
