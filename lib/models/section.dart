class Section {
  final String title;
  final String content;
  final int order;
  final String? imagePath; // NEW: Optional image path

  Section({
    required this.title,
    required this.content,
    required this.order,
    this.imagePath, // NEW: Optional parameter
  });

  factory Section.fromFirestore(Map<String, dynamic> data) {
    return Section(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      order: data['order'] ?? 0,
      imagePath: data['imagePath'], // NEW: Read imagePath from Firestore
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'order': order,
      if (imagePath != null) 'imagePath': imagePath, // NEW: Only include if not null
    };
  }
}
