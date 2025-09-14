enum SubscriptionType {
  monthly,
  yearly
}

class SubscriptionStatus {
  final bool isActive;
  final DateTime? trialEndsAt;
  final DateTime? nextBillingDate;
  final String planType; // New field
  final DateTime createdAt; // New field
  final DateTime updatedAt; // New field

  SubscriptionStatus({
    required this.isActive,
    this.trialEndsAt,
    this.nextBillingDate,
    required this.planType, // New required parameter
    required this.createdAt, // New required parameter
    required this.updatedAt, // New required parameter
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isActive: json['isActive'],
      trialEndsAt: json['trialEndsAt'] != null ? DateTime.parse(json['trialEndsAt']) : null,
      nextBillingDate: json['nextBillingDate'] != null ? DateTime.parse(json['nextBillingDate']) : null,
      planType: json['planType'] ?? 'trial', // Default to 'trial' if not provided
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'planType': planType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SubscriptionStatus copyWith({
    bool? isActive,
    DateTime? trialEndsAt,
    DateTime? nextBillingDate,
    String? planType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionStatus(
      isActive: isActive ?? this.isActive,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      planType: planType ?? this.planType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
