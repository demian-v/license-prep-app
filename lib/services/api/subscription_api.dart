import 'package:dio/dio.dart';
import '../../models/subscription.dart';
import 'api_client.dart';
import 'base/subscription_api_interface.dart';

class SubscriptionApi implements SubscriptionApiInterface {
  final ApiClient _apiClient;
  
  SubscriptionApi(this._apiClient);
  
  /// Get available subscription plans
  @override
  Future<List<dynamic>> getSubscriptionPlans() async {
    try {
      final response = await _apiClient.get('/subscriptions/plans');
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw 'Failed to fetch subscription plans: ${e.message}';
      } else {
        throw 'Failed to fetch subscription plans: $e';
      }
    }
  }
  
  /// Get user's current subscription
  @override
  Future<SubscriptionStatus> getUserSubscription() async {
    try {
      final response = await _apiClient.get('/subscriptions/current');
      return SubscriptionStatus.fromJson(response.data);
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          // User has no subscription
          final now = DateTime.now();
          return SubscriptionStatus(
            isActive: false,
            planType: 'none', 
            createdAt: now,
            updatedAt: now,
          );
        }
        throw 'Failed to fetch subscription: ${e.message}';
      } else {
        throw 'Failed to fetch subscription: $e';
      }
    }
  }
  
  /// Check if a user has an active subscription
  @override
  Future<bool> isSubscriptionActive() async {
    try {
      final response = await _apiClient.get('/subscriptions/status');
      return response.data['active'] as bool;
    } catch (e) {
      if (e is DioException) {
        return false; // Assume no active subscription on error
      } else {
        throw 'Failed to check subscription status: $e';
      }
    }
  }
  
  /// Subscribe a user to a plan (create or update subscription)
  @override
  Future<SubscriptionStatus> subscribeToPlan(String planId, {String? paymentMethodId}) async {
    try {
      final Map<String, dynamic> data = {
        'planId': planId,
      };
      
      if (paymentMethodId != null) {
        data['paymentMethodId'] = paymentMethodId;
      }
      
      final response = await _apiClient.post(
        '/subscriptions/subscribe',
        data: data,
      );
      
      return SubscriptionStatus.fromJson(response.data['subscription']);
    } catch (e) {
      if (e is DioException) {
        throw 'Failed to subscribe to plan: ${e.message}';
      } else {
        throw 'Failed to subscribe to plan: $e';
      }
    }
  }
  
  /// Cancel a user's subscription
  @override
  Future<bool> cancelSubscription() async {
    try {
      final response = await _apiClient.post('/subscriptions/cancel');
      return response.data['success'] as bool;
    } catch (e) {
      if (e is DioException) {
        throw 'Failed to cancel subscription: ${e.message}';
      } else {
        throw 'Failed to cancel subscription: $e';
      }
    }
  }
  
  /// Apply a promo code to a subscription
  @override
  Future<Map<String, dynamic>> applyPromoCode(String promoCode) async {
    try {
      final response = await _apiClient.post(
        '/subscriptions/promo',
        data: {
          'promoCode': promoCode,
        },
      );
      
      return response.data;
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 400) {
          throw 'Invalid promo code';
        } else if (e.response?.statusCode == 409) {
          throw 'Promo code already used';
        } else {
          throw 'Failed to apply promo code: ${e.message}';
        }
      } else {
        throw 'Failed to apply promo code: $e';
      }
    }
  }
  
  /// Get subscription history
  Future<List<Map<String, dynamic>>> getSubscriptionHistory() async {
    try {
      final response = await _apiClient.get('/subscriptions/history');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      if (e is DioException) {
        throw 'Failed to fetch subscription history: ${e.message}';
      } else {
        throw 'Failed to fetch subscription history: $e';
      }
    }
  }
  
  /// Update payment method
  Future<Map<String, dynamic>> updatePaymentMethod(String paymentMethodId) async {
    try {
      final response = await _apiClient.put(
        '/subscriptions/payment-method',
        data: {
          'paymentMethodId': paymentMethodId,
        },
      );
      
      return response.data;
    } catch (e) {
      if (e is DioException) {
        throw 'Failed to update payment method: ${e.message}';
      } else {
        throw 'Failed to update payment method: $e';
      }
    }
  }
}
