class TheoryModule {
  final String id;
  final String licenseId;
  final String title;
  final String description;
  final int estimatedTime;
  final dynamic topics; // Can be a string or a list
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
    required this.topics, // Can be a string or a list
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
      topics: data['topics'] ?? '', // This can now be a string or a list
      language: data['language'] ?? 'uk',
      state: data['state'] ?? 'ALL',
      icon: data['icon'] ?? 'menu_book',
      type: data['type'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  // Helper method to get the topic ID regardless of whether topics is a string or list
  String getTopicId() {
    if (topics is String) {
      return topics; // Return the single topic string
    } else if (topics is List && (topics as List).isNotEmpty) {
      return (topics as List)[0].toString(); // Return the first item in the list
    }
    return ''; // Return empty string if no topics
  }

  // Helper to always return topics as a list for backward compatibility
  List<String> getTopicsList() {
    if (topics is String && (topics as String).isNotEmpty) {
      return [topics as String]; // Convert single string to a list with one item
    } else if (topics is List) {
      return List<String>.from(topics); // Convert List<dynamic> to List<String>
    }
    return []; // Return empty list if no topics
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'licenseId': licenseId,
      'title': title,
      'description': description,
      'estimatedTime': estimatedTime,
      'topics': topics, // Already handles both string and list
      'language': language,
      'state': state,
      'icon': icon,
      'type': type,
      'order': order,
    };
  }
}
