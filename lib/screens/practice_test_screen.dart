import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/test_card.dart';
import '../data/license_data.dart';
import 'dart:math';

class PracticeTestScreen extends StatelessWidget {
  final String licenseId;

  PracticeTestScreen({required this.licenseId});

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    
    // Find the license
    final license = licenseTypes.firstWhere(
      (l) => l.id == licenseId,
      orElse: () => licenseTypes.first,
    );
    
    // Get tests for this license
    final tests = practiceTests.where((t) => t.licenseId == licenseId).toList();
    
    // Check subscription status
    final isSubscriptionActive = subscriptionProvider.isSubscriptionActive;

    Future<void> handleTestStart(String testId) async {
      if (!isSubscriptionActive) {
        Navigator.pushNamed(context, '/subscription');
        return;
      }
      
      // In a real app, this would navigate to the test
      // For demo, we'll simulate a test completion with a random score
      final random = Random();
      final score = 60.0 + random.nextDouble() * 40; // Score between 60-100
      
      // Show a dialog to simulate test experience
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Taking Test...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Simulating test experience...'),
            ],
          ),
        ),
      );
      
      // Simulate test duration
      await Future.delayed(Duration(seconds: 2));
      
      // Save the score
      await progressProvider.saveTestScore(testId, score);
      
      // Show results
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Test Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your score: ${score.toStringAsFixed(1)}%'),
                SizedBox(height: 16),
                Text(
                  score >= 80 
                      ? 'Great job!' 
                      : score >= 70 
                          ? 'Good effort!' 
                          : 'Keep studying, you can improve!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${license.name} - Practice Tests'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSubscriptionActive)
            Container(
              margin: EdgeInsets.all(16.0),
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  Text(
                    'Your trial has ended. Subscribe to continue practicing.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                    child: Text('Subscribe Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,  // Updated parameter name
                      foregroundColor: Colors.white,  // Adding text color explicitly
                   ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final test = tests[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: TestCard(
                    test: test,
                    score: progressProvider.progress.testScores[test.id],
                    onStart: () => handleTestStart(test.id),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/theory/$licenseId');
              },
              child: Text('Back to Theory'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.grey.shade300,  // Updated from primary
                foregroundColor: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
