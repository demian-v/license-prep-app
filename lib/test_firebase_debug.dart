import 'package:flutter/material.dart';
import 'services/api/firebase_functions_client.dart';

/// Test class to demonstrate Firebase Functions debugging
class FirebaseDebugTest {
  static final FirebaseFunctionsClient _functionsClient = FirebaseFunctionsClient();
  
  /// Test Firebase Functions call with comprehensive debugging
  static Future<void> testQuizTopicsCall() async {
    print('\n🧪 [TEST] Starting Firebase Functions Debug Test...');
    print('🎯 [TEST] This will show detailed authentication and function call logs');
    print('=' * 80);
    
    try {
      // Test parameters (matching your Ukrainian/Illinois setup)
      final testData = {
        'language': 'uk',  // Ukrainian language
        'state': 'IL',     // Illinois state
        'limit': 10,
      };
      
      print('📝 [TEST] Test parameters:');
      print('   Language: ${testData['language']}');
      print('   State: ${testData['state']}');
      print('   Limit: ${testData['limit']}');
      print('');
      
      // Call the function with full debugging
      final result = await _functionsClient.callFunction<List<dynamic>>(
        'getQuizTopics',
        data: testData,
      );
      
      print('');
      print('🎉 [TEST] SUCCESS! Function call completed');
      print('📊 [TEST] Result summary:');
      print('   Type: ${result.runtimeType}');
      print('   Length: ${result.length}');
      
      if (result.isNotEmpty) {
        print('   First item keys: ${(result.first as Map).keys.toList()}');
        print('   Sample topic: ${(result.first as Map)['title'] ?? 'No title'}');
      }
      
    } catch (e) {
      print('');
      print('💥 [TEST] FAILURE! Function call failed');
      print('❌ [TEST] Error: $e');
      print('🔍 [TEST] This error information will help pinpoint the exact issue');
    }
    
    print('=' * 80);
    print('🧪 [TEST] Debug test completed');
  }
  
  /// Quick authentication state check
  static Future<void> quickAuthCheck() async {
    print('\n🔍 [QUICK CHECK] Firebase Authentication State');
    print('-' * 50);
    
    try {
      final client = FirebaseFunctionsClient();
      // This will trigger the authentication debugging
      await client.callFunction<Map<String, dynamic>>(
        'getUserData',
        data: {},
      );
      print('✅ [QUICK CHECK] Authentication working');
    } catch (e) {
      print('❌ [QUICK CHECK] Authentication issue: $e');
    }
  }
}

/// Widget to test debugging from UI
class FirebaseDebugTestWidget extends StatelessWidget {
  const FirebaseDebugTestWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Debug Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Firebase Functions Debug Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'This will run comprehensive debugging on Firebase Functions authentication and function calls. Check the console/logs for detailed output.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Running debug test... Check console for logs')),
                );
                await FirebaseDebugTest.testQuizTopicsCall();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Run Full Debug Test',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Running quick auth check... Check console for logs')),
                );
                await FirebaseDebugTest.quickAuthCheck();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Quick Auth Check',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 40),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'What to Look For:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 🔍 [AUTH DEBUG] - Authentication state details\n'
                      '• 🚀 [FUNCTION DEBUG] - Function call progress\n'
                      '• ❌ [FUNCTION DEBUG] - Specific error details\n'
                      '• 🏷️ Error Category - Type of failure',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
