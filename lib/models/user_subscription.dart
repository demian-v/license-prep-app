import 'package:cloud_firestore/cloud_firestore.dart';

class UserSubscription {
  final String id;
  final String userId;
  final int packageId;
  final String status; // 'active', 'inactive', 'deleted'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? trialEndsAt;
  final int trialUsed; // 0 = trial active, 1 = trial used
  final int duration; // days
  final DateTime? nextBillingDate;
  final String planType; // 'monthly', 'yearly', 'trial'
  // Written by Cloud Functions only — never written from Flutter.
  // Stored so Firestore round-trips preserve these fields without losing them.
  final String? originalTransactionId; // iOS: stable ID across renewals, used for webhook matching
  final String? androidPurchaseToken;  // Android: purchase token, used for webhook matching

  UserSubscription({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.status,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.trialEndsAt,
    this.trialUsed = 0,
    required this.duration,
    this.nextBillingDate,
    required this.planType,
    this.originalTransactionId,
    this.androidPurchaseToken,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? '',
      packageId: _parseInt(json['packageId']) ?? 0,
      status: json['status'] ?? 'active',
      isActive: json['isActive'] ?? false,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      trialEndsAt: _parseDateTime(json['trialEndsAt']),
      trialUsed: _parseInt(json['trialUsed']) ?? 0,
      duration: _parseInt(json['duration']) ?? 0,
      nextBillingDate: _parseDateTime(json['nextBillingDate']),
      planType: json['planType'] ?? 'trial',
      originalTransactionId: json['originalTransactionId'] as String?,
      androidPurchaseToken: json['androidPurchaseToken'] as String?,
    );
  }

  /// Helper method to parse DateTime from either Timestamp or String
  /// Handles backward compatibility with string timestamps
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  /// Helper method to parse int from dynamic value (handles String, int, double)
  /// Handles cases where Firestore returns strings instead of ints
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'packageId': packageId,
      'status': status,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'trialEndsAt': trialEndsAt != null ? Timestamp.fromDate(trialEndsAt!) : null,
      'trialUsed': trialUsed,
      'duration': duration,
      'nextBillingDate': nextBillingDate != null ? Timestamp.fromDate(nextBillingDate!) : null,
      'planType': planType,
      if (originalTransactionId != null) 'originalTransactionId': originalTransactionId,
      if (androidPurchaseToken != null) 'androidPurchaseToken': androidPurchaseToken,
    };
  }

  /// Serialize for local cache storage (uses strings for JSON compatibility)
  /// This method is used when saving to SharedPreferences which requires JSON-encodable objects
  Map<String, dynamic> toCacheJson() {
    return {
      'id': id,
      'userId': userId,
      'packageId': packageId,
      'status': status,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'trialUsed': trialUsed,
      'duration': duration,
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'planType': planType,
      if (originalTransactionId != null) 'originalTransactionId': originalTransactionId,
      if (androidPurchaseToken != null) 'androidPurchaseToken': androidPurchaseToken,
    };
  }

  UserSubscription copyWith({
    String? id,
    String? userId,
    int? packageId,
    String? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? trialEndsAt,
    int? trialUsed,
    int? duration,
    DateTime? nextBillingDate,
    String? planType,
    String? originalTransactionId,
    String? androidPurchaseToken,
    bool clearTrialEndsAt = false,
    bool clearNextBillingDate = false,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      packageId: packageId ?? this.packageId,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trialEndsAt: clearTrialEndsAt ? null : (trialEndsAt ?? this.trialEndsAt),
      trialUsed: trialUsed ?? this.trialUsed,
      duration: duration ?? this.duration,
      nextBillingDate: clearNextBillingDate ? null : (nextBillingDate ?? this.nextBillingDate),
      planType: planType ?? this.planType,
      originalTransactionId: originalTransactionId ?? this.originalTransactionId,
      androidPurchaseToken: androidPurchaseToken ?? this.androidPurchaseToken,
    );
  }

  // Helper methods for subscription status
  bool get isTrial => planType == 'trial';
  bool get isMonthly => planType == 'monthly';
  bool get isYearly => planType == 'yearly';

  // Check if trial is currently active
  bool get isTrialActive {
    if (!isTrial || trialUsed == 1) return false;
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  // Get days remaining in trial
  int get trialDaysRemaining {
    if (!isTrialActive || trialEndsAt == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(trialEndsAt!)) return 0;
    return trialEndsAt!.difference(now).inDays + 1;
  }

  // Check if subscription is currently valid (either trial, paid, or canceled but still active)
  bool get isValidSubscription {
    if (!isActive) return false;
    
    // Active and canceled subscriptions are valid until expiry
    if (status != 'active' && status != 'canceled') return false;
    
    if (isTrial) {
      return isTrialActive;
    }
    
    // For paid and canceled subscriptions, check billing date
    if (nextBillingDate != null) {
      return DateTime.now().isBefore(nextBillingDate!);
    }
    
    return true;
  }

  // Check if this is a paid subscription (not trial)
  bool get isPaidSubscription {
    if (status != 'active' || !isActive) return false;
    if (isTrial) return false; // Trials are not paid subscriptions
    return nextBillingDate != null && DateTime.now().isBefore(nextBillingDate!);
  }

  // Get days until next billing
  int get daysUntilNextBilling {
    if (nextBillingDate == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(nextBillingDate!)) return 0;
    return nextBillingDate!.difference(now).inDays + 1;
  }

  // Get formatted duration
  String get formattedDuration {
    if (duration == 1) return '1 day';
    if (duration < 30) return '$duration days';
    if (duration == 30) return '1 month';
    if (duration < 365) {
      final months = (duration / 30).round();
      return '$months month${months > 1 ? 's' : ''}';
    }
    final years = (duration / 365).round();
    return '$years year${years > 1 ? 's' : ''}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSubscription &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode;

  // Upgrade eligibility methods
  bool canUpgradeToYearly() {
    return isMonthly && isValidSubscription;
  }

  bool canUpgradeToMonthly() {
    return false; // No downgrade from yearly to monthly
  }

  int getDaysRemainingInCurrentPlan() {
    if (nextBillingDate == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(nextBillingDate!)) return 0;
    return nextBillingDate!.difference(now).inDays + 1;
  }

  bool isUpgradeEligible(String targetPlanType) {
    if (targetPlanType == 'yearly' && isMonthly) return true;
    return false;
  }

  @override
  String toString() => 'UserSubscription{id: $id, userId: $userId, planType: $planType, status: $status, isActive: $isActive}';
}
