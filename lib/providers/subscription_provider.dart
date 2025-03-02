import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/subscription.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionStatus subscription;

  SubscriptionProvider(this.subscription);

  bool get isSubscriptionActive {
    if (subscription.isActive && subscription.nextBillingDate != null) {
      return true;
    }
    
    if (subscription.trialEndsAt != null) {
      final now = DateTime.now();
      return now.isBefore(subscription.trialEndsAt!);
    }
    
    return false;
  }

  int get trialDaysLeft {
    if (subscription.trialEndsAt == null) {
      return 0;
    }
    
    final now = DateTime.now();
    if (now.isAfter(subscription.trialEndsAt!)) {
      return 0;
    }
    
    return subscription.trialEndsAt!.difference(now).inDays + 1;
  }

  Future<bool> subscribe() async {
    try {
      // This would be an API call to payment processor in a real app
      await Future.delayed(Duration(seconds: 2));
      
      final nextBillingDate = DateTime.now().add(Duration(days: 30));
      final updatedSubscription = subscription.copyWith(
        isActive: true,
        nextBillingDate: nextBillingDate,
      );
      
      subscription = updatedSubscription;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subscription', jsonEncode(subscription.toJson()));
      
      notifyListeners();
      return true;
    } catch (e) {
      print('Subscription error: $e');
      return false;
    }
  }
}