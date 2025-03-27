class Section {
  final String title;
  final String content;
  final int order;

  Section({
    required this.title,
    required this.content,
    required this.order,
  });

  factory Section.fromFirestore(Map<String, dynamic> data) {
    return Section(
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'order': order,
    };
  }
}
