import '../../../models/subscription.dart';

/// Base interface for subscription API
abstract class SubscriptionApiInterface {
  /// Get available subscription plans
  Future<List<dynamic>> getSubscriptionPlans();
  
  /// Get user's current subscription
  Future<SubscriptionStatus> getUserSubscription();
  
  /// Check if a user has an active subscription
  Future<bool> isSubscriptionActive();
  
  /// Subscribe a user to a plan (create or update subscription)
  Future<SubscriptionStatus> subscribeToPlan(String planId, {String? paymentMethodId});
  
  /// Cancel a user's subscription
  Future<bool> cancelSubscription();
  
  /// Apply a promo code to a subscription
  Future<Map<String, dynamic>> applyPromoCode(String promoCode);
}
