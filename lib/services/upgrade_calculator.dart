import 'package:flutter/foundation.dart';

class UpgradeCalculator {
  static const int YEARLY_DAYS = 360;
  static const int MONTHLY_DAYS = 30;
  
  /// Calculate the new billing date after upgrade, preserving remaining days
  static DateTime calculateUpgradeBillingDate(
    DateTime currentBillingDate,
    String fromPlan,
    String toPlan, {
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();
    
    debugPrint('🧮 UpgradeCalculator: Calculating upgrade billing date');
    debugPrint('📅 Current billing date: ${currentBillingDate.toIso8601String()}');
    debugPrint('📊 From plan: $fromPlan -> To plan: $toPlan');
    debugPrint('📅 Current date: ${now.toIso8601String()}');
    
    // Calculate remaining days in current plan
    final remainingDays = currentBillingDate.isAfter(now)
        ? currentBillingDate.difference(now).inDays
        : 0;
    
    debugPrint('📊 Remaining days in current plan: $remainingDays');
    
    if (fromPlan == 'monthly' && toPlan == 'yearly') {
      // Add remaining monthly days + full yearly period
      final newBillingDate = now.add(Duration(days: remainingDays + YEARLY_DAYS));
      debugPrint('✅ New billing date: ${newBillingDate.toIso8601String()}');
      debugPrint('📊 Total days added: ${remainingDays + YEARLY_DAYS}');
      return newBillingDate;
    }
    
    // For other upgrade scenarios (future use)
    debugPrint('⚠️ Upgrade scenario not handled, returning current billing date');
    return currentBillingDate;
  }
  
  /// Calculate total days user will get after upgrade
  static int calculateTotalDaysAfterUpgrade(
    DateTime currentBillingDate,
    String fromPlan,
    String toPlan, {
    DateTime? currentDate,
  }) {
    final now = currentDate ?? DateTime.now();
    
    // Calculate remaining days in current plan
    final remainingDays = currentBillingDate.isAfter(now)
        ? currentBillingDate.difference(now).inDays
        : 0;
    
    debugPrint('🧮 UpgradeCalculator: Calculating total days after upgrade');
    debugPrint('📊 Remaining days: $remainingDays');
    
    if (fromPlan == 'monthly' && toPlan == 'yearly') {
      final totalDays = remainingDays + YEARLY_DAYS;
      debugPrint('✅ Total days after upgrade: $totalDays');
      return totalDays;
    }
    
    // For other scenarios, return remaining days
    debugPrint('⚠️ Upgrade scenario not handled, returning remaining days: $remainingDays');
    return remainingDays;
  }
  
  /// Calculate savings from upgrade (optional, for displaying benefits)
  static Map<String, dynamic> calculateUpgradeSavings(
    String fromPlan,
    String toPlan,
    double monthlyPrice,
    double yearlyPrice,
  ) {
    debugPrint('💰 UpgradeCalculator: Calculating upgrade savings');
    
    if (fromPlan == 'monthly' && toPlan == 'yearly') {
      final monthlyYearlyCost = monthlyPrice * 12;
      final savings = monthlyYearlyCost - yearlyPrice;
      final savingsPercentage = (savings / monthlyYearlyCost) * 100;
      
      debugPrint('💰 Monthly yearly cost: \$${monthlyYearlyCost.toStringAsFixed(2)}');
      debugPrint('💰 Yearly price: \$${yearlyPrice.toStringAsFixed(2)}');
      debugPrint('💰 Savings: \$${savings.toStringAsFixed(2)} (${savingsPercentage.toStringAsFixed(1)}%)');
      
      return {
        'monthlyCost': monthlyYearlyCost,
        'yearlyCost': yearlyPrice,
        'savings': savings,
        'savingsPercentage': savingsPercentage,
      };
    }
    
    return {
      'monthlyCost': 0.0,
      'yearlyCost': 0.0,
      'savings': 0.0,
      'savingsPercentage': 0.0,
    };
  }
  
  /// Validate upgrade eligibility
  static bool isUpgradeValid(
    String currentPlan,
    String targetPlan,
    bool isCurrentSubscriptionValid,
  ) {
    debugPrint('✅ UpgradeCalculator: Validating upgrade eligibility');
    debugPrint('📊 Current: $currentPlan -> Target: $targetPlan');
    debugPrint('📊 Is current valid: $isCurrentSubscriptionValid');
    
    // Only allow monthly to yearly upgrades for now
    if (currentPlan == 'monthly' && 
        targetPlan == 'yearly' && 
        isCurrentSubscriptionValid) {
      debugPrint('✅ Upgrade is valid');
      return true;
    }
    
    debugPrint('❌ Upgrade is not valid');
    return false;
  }
  
  /// Get upgrade description for UI display
  static String getUpgradeDescription(
    String fromPlan,
    String toPlan,
    int remainingDays,
    int totalDaysAfterUpgrade,
  ) {
    if (fromPlan == 'monthly' && toPlan == 'yearly') {
      return 'Get $totalDaysAfterUpgrade days total\n$remainingDays remaining + ${YEARLY_DAYS} new days';
    }
    
    return 'Upgrade to $toPlan plan';
  }
}
