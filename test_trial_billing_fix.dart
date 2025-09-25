import 'package:flutter/material.dart';
import 'lib/services/billing_calculator.dart';

void main() {
  testTrialBillingCalculation();
}

void testTrialBillingCalculation() {
  print('🧪 Testing Trial Billing Fix');
  print('=' * 50);
  
  // Test Case 1: Monthly subscription with 3 days left in trial
  final trialEndDate = DateTime(2025, 9, 27); // Sept 27, 2025
  final upgradeDate = DateTime(2025, 9, 24);  // Sept 24, 2025 (3 days before trial ends)
  
  final monthlyBilling = BillingCalculator.calculateTrialToPaidBillingDate(
    trialEndDate,
    'monthly',
    currentDate: upgradeDate,
  );
  
  print('Test Case 1: Monthly Subscription with 3 Days Remaining');
  print('📅 Trial ends: ${trialEndDate.toIso8601String()}');
  print('📅 Upgrade date: ${upgradeDate.toIso8601String()}');
  print('📅 Next billing (monthly): ${monthlyBilling.toIso8601String()}');
  print('📊 Expected: Sept 27 + 30 days = Oct 27, 2025');
  final monthlyCorrect = monthlyBilling.day == 27 && monthlyBilling.month == 10 && monthlyBilling.year == 2025;
  print('✅ Correct: $monthlyCorrect');
  print('💰 Trial days preserved: 3 days');
  print('');
  
  // Test Case 2: Yearly subscription with 3 days left in trial
  final yearlyBilling = BillingCalculator.calculateTrialToPaidBillingDate(
    trialEndDate,
    'yearly',
    currentDate: upgradeDate,
  );
  
  print('Test Case 2: Yearly Subscription with 3 Days Remaining');
  print('📅 Next billing (yearly): ${yearlyBilling.toIso8601String()}');
  print('📊 Expected: Sept 27 + 360 days = Sept 22, 2026');
  final yearlyCorrect = yearlyBilling.month == 9 && yearlyBilling.year == 2026 && yearlyBilling.day == 22;
  print('✅ Correct: $yearlyCorrect');
  print('💰 Trial days preserved: 3 days');
  print('');
  
  // Test Case 3: Monthly subscription with 1 day left in trial
  final trialEndDate1Day = DateTime(2025, 9, 25); // Sept 25, 2025
  final upgradeDate1Day = DateTime(2025, 9, 24);  // Sept 24, 2025 (1 day before trial ends)
  
  final monthlyBilling1Day = BillingCalculator.calculateTrialToPaidBillingDate(
    trialEndDate1Day,
    'monthly',
    currentDate: upgradeDate1Day,
  );
  
  print('Test Case 3: Monthly Subscription with 1 Day Remaining');
  print('📅 Trial ends: ${trialEndDate1Day.toIso8601String()}');
  print('📅 Upgrade date: ${upgradeDate1Day.toIso8601String()}');
  print('📅 Next billing (monthly): ${monthlyBilling1Day.toIso8601String()}');
  print('📊 Expected: Sept 25 + 30 days = Oct 25, 2025');
  final monthly1DayCorrect = monthlyBilling1Day.day == 25 && monthlyBilling1Day.month == 10 && monthlyBilling1Day.year == 2025;
  print('✅ Correct: $monthly1DayCorrect');
  print('💰 Trial days preserved: 1 day');
  print('');
  
  // Test Case 4: Trial already expired (edge case)
  final expiredTrialDate = DateTime(2025, 9, 20); // Trial ended 4 days ago
  final lateUpgradeDate = DateTime(2025, 9, 24);
  
  final expiredTrialBilling = BillingCalculator.calculateTrialToPaidBillingDate(
    expiredTrialDate,
    'monthly',
    currentDate: lateUpgradeDate,
  );
  
  print('Test Case 4: Trial Already Expired (Edge Case)');
  print('📅 Trial ended: ${expiredTrialDate.toIso8601String()}');
  print('📅 Late upgrade: ${lateUpgradeDate.toIso8601String()}');
  print('📅 Next billing: ${expiredTrialBilling.toIso8601String()}');
  print('📊 Expected: Sept 24 + 30 days = Oct 24, 2025 (no trial days to preserve)');
  final expiredCorrect = expiredTrialBilling.day == 24 && expiredTrialBilling.month == 10 && expiredTrialBilling.year == 2025;
  print('✅ Correct: $expiredCorrect');
  print('💰 Trial days preserved: 0 days (trial already expired)');
  print('');
  
  // Test Case 5: Upgrade on last day of trial
  final trialEndDateLastDay = DateTime(2025, 9, 24, 23, 59); // Sept 24, 2025 at 11:59 PM
  final upgradeOnLastDay = DateTime(2025, 9, 24, 10, 0);    // Sept 24, 2025 at 10:00 AM
  
  final lastDayBilling = BillingCalculator.calculateTrialToPaidBillingDate(
    trialEndDateLastDay,
    'monthly',
    currentDate: upgradeOnLastDay,
  );
  
  print('Test Case 5: Upgrade on Last Day of Trial');
  print('📅 Trial ends: ${trialEndDateLastDay.toIso8601String()}');
  print('📅 Upgrade time: ${upgradeOnLastDay.toIso8601String()}');
  print('📅 Next billing: ${lastDayBilling.toIso8601String()}');
  print('📊 Expected: Sept 24 + 30 days = Oct 24, 2025');
  final lastDayCorrect = lastDayBilling.day == 24 && lastDayBilling.month == 10 && lastDayBilling.year == 2025;
  print('✅ Correct: $lastDayCorrect');
  print('💰 Trial days preserved: ~14 hours');
  print('');
  
  // Summary
  print('📊 TEST SUMMARY');
  print('=' * 30);
  final allTestsPassed = monthlyCorrect && yearlyCorrect && monthly1DayCorrect && expiredCorrect && lastDayCorrect;
  print('Monthly with 3 days: ${monthlyCorrect ? "✅ PASS" : "❌ FAIL"}');
  print('Yearly with 3 days: ${yearlyCorrect ? "✅ PASS" : "❌ FAIL"}');
  print('Monthly with 1 day: ${monthly1DayCorrect ? "✅ PASS" : "❌ FAIL"}');
  print('Expired trial: ${expiredCorrect ? "✅ PASS" : "❌ FAIL"}');
  print('Last day upgrade: ${lastDayCorrect ? "✅ PASS" : "❌ FAIL"}');
  print('');
  print('🎉 All tests: ${allTestsPassed ? "✅ PASSED" : "❌ FAILED"}');
  
  if (allTestsPassed) {
    print('');
    print('✅ The fix successfully preserves trial days when upgrading!');
    print('🚀 Ready for deployment');
  }
}
