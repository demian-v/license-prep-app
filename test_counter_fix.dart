import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/services/counter_service.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('=== Counter Service Fix Test ===');
  
  try {
    // Initialize Flutter binding
    WidgetsFlutterBinding.ensureInitialized();
    print('✓ Flutter binding initialized');
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✓ Firebase initialized');
    
    final counterService = CounterService();
    print('✓ Counter service created');
    
    // Test with a sample user ID
    const testUserId = 'test_user_12345';
    
    print('\n--- Testing Counter Service ---');
    print('Testing user ID: $testUserId');
    
    // Generate 3 sequential report IDs
    for (int i = 1; i <= 3; i++) {
      print('\n--- Attempt $i ---');
      try {
        final reportId = await counterService.getNextUserReportId(testUserId);
        print('Generated Report ID: $reportId');
        
        // Check if it's a clean sequential ID (no timestamp)
        final expectedPattern = RegExp(r'^user_test_user_12345_report_\d+$');
        final isCleanId = expectedPattern.hasMatch(reportId);
        
        if (isCleanId) {
          print('✓ Clean sequential ID generated successfully!');
        } else {
          print('✗ Fallback ID generated (contains timestamp)');
        }
        
        // Small delay between requests
        await Future.delayed(Duration(milliseconds: 500));
        
      } catch (e) {
        print('✗ Error generating report ID: $e');
      }
    }
    
    // Check current counter value
    print('\n--- Checking Counter Value ---');
    try {
      final counterValue = await counterService.getCurrentCounterValue(testUserId);
      print('Current counter value: $counterValue');
      
      if (counterValue > 0) {
        print('✓ Counter document created and updated successfully!');
      } else {
        print('✗ Counter document not found or not updated');
      }
    } catch (e) {
      print('✗ Error getting counter value: $e');
    }
    
  } catch (e) {
    print('✗ Test failed with error: $e');
  }
  
  print('\n=== Test Complete ===');
}
