import 'package:dio/dio.dart';
import '../../models/subscription.dart';
import 'api_client.dart';

class SubscriptionApi {
  final ApiClient _apiClient;
  
  SubscriptionApi(this._apiClient);
  
  // Get available subscription plans
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    try {
      final response = await _apiClient.get('/subscriptions/plans');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw 'Failed to load subscription plans: ${e.toString()}';
    }
  }
  
  // Get user's current subscription status
  Future<SubscriptionStatus?> getUserSubscription(String userId) async {
    try {
      final response = await _apiClient.get('/subscriptions/users/$userId');
      
      if (response.data == null) {
        return null;
      }
      
      return SubscriptionStatus.fromJson(response.data);
    } catch (e) {
      throw 'Failed to load user subscription: ${e.toString()}';
    }
  }
  
  // Create or update payment method
  Future<Map<String, dynamic>> createPaymentMethod(String userId, Map<String, dynamic> paymentDetails) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/payment-methods',
        data: {
          'userId': userId,
          ...paymentDetails,
        },
      );
      
      return response.data;
    } catch (e) {
      throw 'Failed to create payment method: ${e.toString()}';
    }
  }
  
  // Get user's payment methods
  Future<List<Map<String, dynamic>>> getUserPaymentMethods(String userId) async {
    try {
      final response = await _apiClient.get('/subscriptions/users/$userId/payment-methods');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw 'Failed to load payment methods: ${e.toString()}';
    }
  }
  
  // Delete payment method
  Future<void> deletePaymentMethod(String userId, String paymentMethodId) async {
    try {
      await _apiClient.delete('/subscriptions/users/$userId/payment-methods/$paymentMethodId');
    } catch (e) {
      throw 'Failed to delete payment method: ${e.toString()}';
    }
  }
  
  // Subscribe user to plan
  Future<SubscriptionStatus> subscribeToPlan(String userId, String planId, String paymentMethodId) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/subscribe',
        data: {
          'userId': userId,
          'planId': planId,
          'paymentMethodId': paymentMethodId,
        },
      );
      
      return SubscriptionStatus.fromJson(response.data);
    } catch (e) {
      throw 'Failed to subscribe to plan: ${e.toString()}';
    }
  }
  
  // Cancel subscription
  Future<void> cancelSubscription(String userId, String subscriptionId) async {
    try {
      await _apiClient.post(
        '/subscriptions/$subscriptionId/cancel',
        data: {
          'userId': userId,
        },
      );
    } catch (e) {
      throw 'Failed to cancel subscription: ${e.toString()}';
    }
  }
  
  // Update auto-renewal setting
  Future<void> updateAutoRenewal(String userId, String subscriptionId, bool autoRenew) async {
    try {
      await _apiClient.put(
        '/subscriptions/$subscriptionId/auto-renew',
        data: {
          'userId': userId,
          'autoRenew': autoRenew,
        },
      );
    } catch (e) {
      throw 'Failed to update auto-renewal setting: ${e.toString()}';
    }
  }
  
  // Get subscription history
  Future<List<Map<String, dynamic>>> getSubscriptionHistory(String userId) async {
    try {
      final response = await _apiClient.get('/subscriptions/users/$userId/history');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw 'Failed to load subscription history: ${e.toString()}';
    }
  }
  
  // Get payment receipts
  Future<List<Map<String, dynamic>>> getPaymentReceipts(String userId) async {
    try {
      final response = await _apiClient.get('/subscriptions/users/$userId/receipts');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw 'Failed to load payment receipts: ${e.toString()}';
    }
  }
  
  // Apply promo code
  Future<Map<String, dynamic>> applyPromoCode(String userId, String promoCode) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/promo-codes/apply',
        data: {
          'userId': userId,
          'promoCode': promoCode,
        },
      );
      
      return response.data;
    } catch (e) {
      throw 'Failed to apply promo code: ${e.toString()}';
    }
  }
  
  // Check subscription status
  Future<bool> isSubscriptionActive(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      return subscription != null && subscription.isActive;
    } catch (e) {
      return false;
    }
  }
}
