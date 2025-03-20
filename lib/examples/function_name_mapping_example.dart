import 'package:flutter/material.dart';
import '../services/api/firebase_functions_client.dart';
import '../services/service_locator.dart';

/// Example demonstrating the function name mapping mechanism
class FunctionNameMappingExample extends StatelessWidget {
  const FunctionNameMappingExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Function Name Mapping'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Function Name Mapping Example',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This example demonstrates how function names are mapped between '
              'the client and the Cloud Functions.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showMappingExample(context),
              child: const Text('Show Function Name Mapping'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testFunctionCall(context),
              child: const Text('Test Function Call'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows how a client function name maps to a cloud function name
  void _showMappingExample(BuildContext context) {
    final examples = [
      {'client': 'loginUser', 'cloud': FunctionNameMapper.getCloudFunctionName('loginUser')},
      {'client': 'getQuizTopics', 'cloud': FunctionNameMapper.getCloudFunctionName('getQuizTopics')},
      {'client': 'updateTopicProgress', 'cloud': FunctionNameMapper.getCloudFunctionName('updateTopicProgress')},
      {'client': 'nonMappedFunction', 'cloud': FunctionNameMapper.getCloudFunctionName('nonMappedFunction')},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Function Name Mapping'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: examples.length,
            itemBuilder: (context, index) {
              final example = examples[index];
              return ListTile(
                title: Text('Client: ${example['client']}'),
                subtitle: Text('Cloud: ${example['cloud']}'),
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Tests calling a function with the mapping
  Future<void> _testFunctionCall(BuildContext context) async {
    try {
      // This will show a debug print with the mapping
      final result = await serviceLocator.firebaseFunctionsClient.callFunction<Map<String, dynamic>>(
        'loginUser',
        data: {
          'email': 'test@example.com',
          'password': 'password',
        },
      );
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Function Call Result'),
          content: Text('Called loginUser which mapped to getUserData\nResult: $result'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Function Call Error'),
          content: Text('Error: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
}
