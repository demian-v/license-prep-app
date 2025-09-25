/// Utility class for calculating billing dates and subscription cycles
class BillingCalculator {
  /// Trial period in days
  static const int TRIAL_DAYS = 3;
  
  /// Monthly plan duration in days
  static const int MONTHLY_DAYS = 30;
  
  /// Yearly plan duration in days
  static const int YEARLY_DAYS = 360;
  
  /// Calculate trial end date from registration date
  /// 
  /// For new users, trial period starts from registration date
  /// and lasts for TRIAL_DAYS (3 days)
  static DateTime calculateTrialEndDate(DateTime registrationDate) {
    return registrationDate.add(Duration(days: TRIAL_DAYS));
  }
  
  /// Calculate next billing date based on plan type and base date
  /// 
  /// Used for calculating when user will be billed next based on:
  /// - Plan type ('monthly', 'yearly', or 'trial')
  /// - Base date (usually current date or trial end date)
  static DateTime calculateNextBillingDate(DateTime baseDate, String planType) {
    switch (planType.toLowerCase()) {
      case 'monthly':
        return baseDate.add(Duration(days: MONTHLY_DAYS));
      case 'yearly':
        return baseDate.add(Duration(days: YEARLY_DAYS));
      case 'trial':
      default:
        return baseDate.add(Duration(days: TRIAL_DAYS));
    }
  }
  
  /// Calculate first billing date after trial conversion
  /// 
  /// When user converts from trial to paid plan, next billing is:
  /// trial end date + plan duration
  static DateTime calculateFirstBillingAfterTrial(DateTime trialEndDate, String planType) {
    int durationDays = planType.toLowerCase() == 'monthly' ? MONTHLY_DAYS : YEARLY_DAYS;
    return trialEndDate.add(Duration(days: durationDays));
  }
  
  /// Calculate renewal billing date after successful payment
  /// 
  /// After each successful payment, next billing date is:
  /// current date + plan duration
  static DateTime calculateRenewalDate(DateTime paymentDate, String planType) {
    int durationDays = planType.toLowerCase() == 'monthly' ? MONTHLY_DAYS : YEARLY_DAYS;
    return paymentDate.add(Duration(days: durationDays));
  }
  
  /// Get plan duration in days
  static int getPlanDurationDays(String planType) {
    switch (planType.toLowerCase()) {
      case 'monthly':
        return MONTHLY_DAYS;
      case 'yearly':
        return YEARLY_DAYS;
      case 'trial':
        return TRIAL_DAYS;
      default:
        return TRIAL_DAYS;
    }
  }
  
  /// Check if user is currently in trial period
  static bool isInTrialPeriod(DateTime? nextBillingDate, DateTime registrationDate) {
    if (nextBillingDate == null) return false;
    
    final trialEndDate = calculateTrialEndDate(registrationDate);
    final now = DateTime.now();
    
    // User is in trial if:
    // 1. Current time is before trial end date
    // 2. Next billing date matches trial end date (within 1 day tolerance)
    return now.isBefore(trialEndDate) && 
           nextBillingDate.difference(trialEndDate).abs().inDays <= 1;
  }
  
  /// Calculate days left in trial
  static int calculateTrialDaysLeft(DateTime registrationDate) {
    final trialEndDate = calculateTrialEndDate(registrationDate);
    final now = DateTime.now();
    
    if (now.isAfter(trialEndDate)) {
      return 0; // Trial has ended
    }
    
    return trialEndDate.difference(now).inDays + 1; // +1 to include current day
  }
  
  /// Calculate next billing date when converting trial to paid subscription
  /// Ensures remaining trial days are preserved by using trial end date as base
  /// 
  /// @param trialEndDate The original trial end date
  /// @param planType The plan type ('monthly' or 'yearly')
  /// @param currentDate Optional current date for testing (defaults to now)
  /// @return DateTime when the first paid billing should occur
  static DateTime calculateTrialToPaidBillingDate(
    DateTime trialEndDate, 
    String planType,
    {DateTime? currentDate}
  ) {
    final now = currentDate ?? DateTime.now();
    
    // If trial hasn't ended yet, start billing from trial end date
    // This preserves the remaining trial days for the user
    if (now.isBefore(trialEndDate)) {
      return calculateNextBillingDate(trialEndDate, planType);
    }
    
    // If trial already ended, start billing immediately from current date
    return calculateNextBillingDate(now, planType);
  }

  /// Validate that user and subscription billing dates are in sync
  static bool areBillingDatesInSync(DateTime? userNextBillingDate, DateTime? subscriptionNextBillingDate) {
    if (userNextBillingDate == null || subscriptionNextBillingDate == null) {
      return userNextBillingDate == subscriptionNextBillingDate;
    }
    
    // Allow 1 minute tolerance for sync differences
    return userNextBillingDate.difference(subscriptionNextBillingDate).abs().inMinutes <= 1;
  }
  
  /// Calculate billing period end date for display purposes
  static DateTime calculatePeriodEndDate(DateTime lastBillingDate, String planType) {
    return calculateNextBillingDate(lastBillingDate, planType).subtract(Duration(days: 1));
  }
}
