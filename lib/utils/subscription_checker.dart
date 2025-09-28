import '../providers/subscription_provider.dart';

/// Utility class for checking subscription status and premium feature access
class SubscriptionChecker {
  
  /// Checks if user has valid subscription (either active trial or paid subscription)
  static bool hasValidSubscription(SubscriptionProvider provider) {
    // User has valid subscription if they have an active trial OR a valid subscription
    return provider.isTrialActive || provider.hasValidSubscription;
  }
  
  /// Determines if a premium feature should be blocked
  static bool shouldBlockPremiumFeature(SubscriptionProvider provider) {
    // Block premium features if:
    // 1. Trial has expired (hasExpiredTrial = true)
    // 2. No active trial AND no valid subscription
    return provider.hasExpiredTrial || 
           (!provider.isTrialActive && !provider.hasValidSubscription);
  }
  
  /// Gets the specific reason why a premium feature is blocked
  /// Useful for analytics and debugging
  static String getBlockReason(SubscriptionProvider provider) {
    if (provider.hasExpiredTrial) {
      return 'trial_expired';
    }
    if (provider.subscription?.status == 'canceled' && !provider.hasValidSubscription) {
      return 'canceled_subscription_expired';
    }
    if (!provider.hasValidSubscription && !provider.isTrialActive) {
      return 'no_valid_subscription';
    }
    if (provider.subscription?.status == 'inactive') {
      return 'subscription_inactive';
    }
    return 'unknown';
  }
  
  /// Gets user-friendly message key based on subscription state
  static String getBlockMessageKey(SubscriptionProvider provider) {
    if (provider.hasExpiredTrial) {
      return 'trial_expired_message';
    }
    if (!provider.hasValidSubscription) {
      return 'subscription_expired_message';
    }
    return 'premium_feature_blocked_message';
  }
  
  /// Gets appropriate title key for the block dialog
  static String getBlockTitleKey(SubscriptionProvider provider) {
    if (provider.hasExpiredTrial) {
      return 'trial_expired';
    }
    return 'premium_feature_blocked';
  }
}
