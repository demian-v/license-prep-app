import '../../models/subscription.dart';
import 'firebase_functions_client.dart';
import 'base/subscription_api_interface.dart';

class FirebaseSubscriptionApi implements SubscriptionApiInterface {
  final FirebaseFunctionsClient _functionsClient;
  
  FirebaseSubscriptionApi(this._functionsClient);
  
  /// Get available subscription plans
  @override
  Future<List<dynamic>> getSubscriptionPlans() async {
    try {
      final response = await _functionsClient.callFunction<List<dynamic>>(
        'getSubscriptionPlans',
      );
      
      return response;
    } catch (e) {
      throw 'Failed to fetch subscription plans: $e';
    }
  }
  
  /// Get user's current subscription
  @override
  Future<SubscriptionStatus> getUserSubscription() async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'getUserSubscription',
      );
      
      return SubscriptionStatus.fromJson(response);
    } catch (e) {
      throw 'Failed to fetch user subscription: $e';
    }
  }
  
  /// Check if a user has an active subscription
  @override
  Future<bool> isSubscriptionActive() async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'isSubscriptionActive',
      );
      
      return response['active'] as bool;
    } catch (e) {
      throw 'Failed to check subscription status: $e';
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
      
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'subscribeToPlan',
        data: data,
      );
      
      return SubscriptionStatus.fromJson(response['subscription']);
    } catch (e) {
      throw 'Failed to subscribe to plan: $e';
    }
  }
  
  /// Cancel a user's subscription
  @override
  Future<bool> cancelSubscription() async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'cancelSubscription',
      );
      
      return response['success'] as bool;
    } catch (e) {
      throw 'Failed to cancel subscription: $e';
    }
  }
  
  /// Apply a promo code to a subscription
  @override
  Future<Map<String, dynamic>> applyPromoCode(String promoCode) async {
    try {
      final response = await _functionsClient.callFunction<Map<String, dynamic>>(
        'applyPromoCode',
        data: {
          'promoCode': promoCode,
        },
      );
      
      return response;
    } catch (e) {
      throw 'Failed to apply promo code: $e';
    }
  }
}
