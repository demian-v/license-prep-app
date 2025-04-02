class User {
  final String id;
  final String name;
  final String email;
  final String? language;
  final String? state;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.language,
    this.state,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      language: json['language'],
      state: json['state'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'language': language,
      'state': state,
    };
  }

  User copyWith({
    String? name,
    String? language,
    String? state,
    bool clearState = false,
  }) {
    return User(
      id: this.id,
      name: name ?? this.name,
      email: this.email,
      language: language ?? this.language,
      state: clearState ? null : (state ?? this.state),
    );
  }
}
