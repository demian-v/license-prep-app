class User {
  final String id;
  final String name;
  final String email;
  final String? language;
  final String? state;
  final String? currentSessionId;
  // New subscription-related fields
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final String status; // 'active', 'inactive', 'deleted'
  final DateTime? lastBillingDate;
  final DateTime? nextBillingDate;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.language,
    this.state,
    this.currentSessionId,
    required this.createdAt,
    this.lastLoginAt,
    this.status = 'active',
    this.lastBillingDate,
    this.nextBillingDate,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      language: json['language'],
      state: json['state'],
      currentSessionId: json['currentSessionId'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null ? DateTime.parse(json['lastLoginAt']) : null,
      status: json['status'] ?? 'active',
      lastBillingDate: json['lastBillingDate'] != null ? DateTime.parse(json['lastBillingDate']) : null,
      nextBillingDate: json['nextBillingDate'] != null ? DateTime.parse(json['nextBillingDate']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'language': language,
      'state': state,
      'currentSessionId': currentSessionId,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'status': status,
      'lastBillingDate': lastBillingDate?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
    };
  }

  User copyWith({
    String? name,
    String? language,
    String? state,
    String? currentSessionId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    String? status,
    DateTime? lastBillingDate,
    DateTime? nextBillingDate,
    bool clearState = false,
    bool clearSessionId = false,
    bool clearLastLoginAt = false,
    bool clearLastBillingDate = false,
    bool clearNextBillingDate = false,
  }) {
    return User(
      id: this.id,
      name: name ?? this.name,
      email: this.email,
      language: language ?? this.language,
      state: clearState ? null : (state ?? this.state),
      currentSessionId: clearSessionId ? null : (currentSessionId ?? this.currentSessionId),
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: clearLastLoginAt ? null : (lastLoginAt ?? this.lastLoginAt),
      status: status ?? this.status,
      lastBillingDate: clearLastBillingDate ? null : (lastBillingDate ?? this.lastBillingDate),
      nextBillingDate: clearNextBillingDate ? null : (nextBillingDate ?? this.nextBillingDate),
    );
  }
}
