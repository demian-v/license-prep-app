class TheoryModule {
  final String id;
  final String licenseId;
  final String title;
  final String description;
  final int estimatedTime;
  final List<String> topics;
  // New fields
  final String language;
  final String state;
  final String icon;
  final String type;
  final int order;

  TheoryModule({
    required this.id,
    required this.licenseId,
    required this.title,
    required this.description,
    required this.estimatedTime,
    required this.topics,
    this.language = 'uk',
    this.state = 'ALL',
    this.icon = 'menu_book',
    this.type = 'traffic_rules',
    this.order = 0,
  });

  factory TheoryModule.fromFirestore(Map<String, dynamic> data, String documentId) {
    return TheoryModule(
      id: data['id'] ?? documentId,
      licenseId: data['licenseId'] ?? 'driver',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      estimatedTime: data['estimatedTime'] ?? 0,
      topics: List<String>.from(data['topics'] ?? []),
      language: data['language'] ?? 'uk',
      state: data['state'] ?? 'ALL',
      icon: data['icon'] ?? 'menu_book',
      type: data['type'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'licenseId': licenseId,
      'title': title,
      'description': description,
      'estimatedTime': estimatedTime,
      'topics': topics,
      'language': language,
      'state': state,
      'icon': icon,
      'type': type,
      'order': order,
    };
  }
}
