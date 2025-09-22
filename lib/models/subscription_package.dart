import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPackage {
  final int id;
  final String planType; // 'monthly', 'yearly', 'trial'
  final double price;
  final int duration; // days (30 for monthly, 360 for yearly, 3 for trial)
  final DateTime createdAt;
  final bool isSubscription; // true for paid plans, false for trial

  SubscriptionPackage({
    required this.id,
    required this.planType,
    required this.price,
    required this.duration,
    required this.createdAt,
    required this.isSubscription,
  });

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) {
    return SubscriptionPackage(
      id: json['id'] ?? 0,
      planType: json['planType'] ?? 'unknown',
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0,
      duration: json['duration'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] is Timestamp 
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.parse(json['createdAt']))
          : DateTime.now(),
      isSubscription: json['isSubscription'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planType': planType,
      'price': price,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'isSubscription': isSubscription,
    };
  }

  SubscriptionPackage copyWith({
    int? id,
    String? planType,
    double? price,
    int? duration,
    DateTime? createdAt,
    bool? isSubscription,
  }) {
    return SubscriptionPackage(
      id: id ?? this.id,
      planType: planType ?? this.planType,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      isSubscription: isSubscription ?? this.isSubscription,
    );
  }

  // Helper methods for common package types
  bool get isMonthly => planType == 'monthly';
  bool get isYearly => planType == 'yearly';
  bool get isTrial => planType == 'trial';

  // Get formatted price string
  String get formattedPrice => price == 0 ? 'Free' : '\$${price.toStringAsFixed(2)}';

  // Get duration in human readable format
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
      other is SubscriptionPackage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SubscriptionPackage{id: $id, planType: $planType, price: $price, duration: $duration}';
}
