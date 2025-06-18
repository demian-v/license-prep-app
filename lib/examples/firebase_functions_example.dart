import 'package:flutter/material.dart';
import '../models/quiz_topic.dart';
import '../models/subscription.dart';
import '../services/service_locator.dart';

/// Example class showing how to use Firebase Functions in the app
class FirebaseFunctionsExample extends StatelessWidget {
  const FirebaseFunctionsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Functions Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _getUserProfile,
              child: const Text('Get User Profile'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _getSubscriptionStatus,
              child: const Text('Check Subscription'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _getQuizTopics,
              child: const Text('Get Quiz Topics'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _updateProgress,
              child: const Text('Update Module Progress'),
            ),
          ],
        ),
      ),
    );
  }

  /// Example of fetching user profile using Firebase Auth API
  Future<void> _getUserProfile() async {
    try {
      final userProfile = await serviceLocator.firebaseAuthApi.getCurrentUser();
      if (userProfile != null) {
        debugPrint('User profile: ${userProfile.name}');
      } else {
        debugPrint('No user is currently logged in');
      }
      // Show success message or update UI
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      // Show error message
    }
  }

  /// Example of checking subscription status using Firebase Subscription API
  Future<void> _getSubscriptionStatus() async {
    try {
      final SubscriptionStatus subscription = 
          await serviceLocator.firebaseSubscriptionApi.getUserSubscription();
      
      final bool isActive = subscription.isActive;
      final String planType = subscription.planType;
      
      debugPrint('Subscription active: $isActive, Plan type: $planType');
      // Update UI based on subscription status
    } catch (e) {
      debugPrint('Error checking subscription: $e');
      // Show error message
    }
  }

  /// Example of fetching quiz topics using Firebase Content API
  Future<void> _getQuizTopics() async {
    try {
      final List<QuizTopic> topics = await serviceLocator.firebaseContentApi
          .getQuizTopics('en', 'IL');
      
      debugPrint('Loaded ${topics.length} quiz topics');
      for (final topic in topics) {
        debugPrint('Topic: ${topic.title}, Questions: ${topic.questionCount}');
      }
      // Display topics in UI
    } catch (e) {
      debugPrint('Error fetching quiz topics: $e');
      // Show error message
    }
  }

  /// Example of updating module progress using Firebase Progress API
  Future<void> _updateProgress() async {
    try {
      final String moduleId = 'module123';
      final double progress = 0.75; // 75% complete
      
      final result = await serviceLocator.firebaseProgressApi
          .updateModuleProgress(moduleId, progress);
      
      debugPrint('Progress updated: ${result['success']}');
      // Show success message or update UI
    } catch (e) {
      debugPrint('Error updating progress: $e');
      // Show error message
    }
  }
}
