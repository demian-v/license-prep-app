class User {
  final String id;
  final String name;
  final String email;
  final String? language;
  final String? state;
  final String? currentSessionId;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.language,
    this.state,
    this.currentSessionId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      language: json['language'],
      state: json['state'],
      currentSessionId: json['currentSessionId'],
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
    };
  }

  User copyWith({
    String? name,
    String? language,
    String? state,
    String? currentSessionId,
    bool clearState = false,
    bool clearSessionId = false,
  }) {
    return User(
      id: this.id,
      name: name ?? this.name,
      email: this.email,
      language: language ?? this.language,
      state: clearState ? null : (state ?? this.state),
      currentSessionId: clearSessionId ? null : (currentSessionId ?? this.currentSessionId),
    );
  }
}
