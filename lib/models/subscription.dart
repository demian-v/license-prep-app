class SubscriptionStatus {
  final bool isActive;
  final DateTime? trialEndsAt;
  final DateTime? nextBillingDate;

  SubscriptionStatus({
    required this.isActive,
    this.trialEndsAt,
    this.nextBillingDate,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['isActive'],
      trialEndsAt: json['trialEndsAt'] != null ? DateTime.parse(json['trialEndsAt']) : null,
      nextBillingDate: json['nextBillingDate'] != null ? DateTime.parse(json['nextBillingDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
    };
  }

  SubscriptionStatus copyWith({
    bool? isActive,
    DateTime? trialEndsAt,
    DateTime? nextBillingDate,
  }) {
    return SubscriptionStatus(
      isActive: isActive ?? this.isActive,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
    );
  }
}