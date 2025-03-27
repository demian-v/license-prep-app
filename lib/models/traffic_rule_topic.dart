import 'section.dart';

class TrafficRuleTopic {
  final String id;
  final String title;
  final String? content; // Optional now as we're moving to sections
  final String language;
  final String state;
  final String licenseId;
  final int order;
  final List<Section> sections;

  // Primary constructor for Firebase data
  TrafficRuleTopic.firebase({
    required this.id,
    required this.title,
    this.content,
    required this.language,
    required this.state,
    required this.licenseId,
    required this.order,
    required this.sections,
  });
  
  // Legacy constructor for backward compatibility with hardcoded data
  TrafficRuleTopic({
    required this.id,
    required this.title,
    required String content,
  }) : 
    content = content,
    language = 'uk',
    state = 'ALL',
    licenseId = 'driver',
    order = int.tryParse(id) ?? 0,
    sections = [];

  // Add compatibility method to get full content from sections
  String get fullContent {
    if (content != null && content!.isNotEmpty) {
      return content!;
    }
    
    // Otherwise combine sections content
    if (sections.isEmpty) {
      return '';
    }
    
    return sections.map((section) => "${section.title}\n\n${section.content}").join("\n\n");
  }

  factory TrafficRuleTopic.fromFirestore(Map<String, dynamic> data, String documentId) {
    // Process sections array
    List<Section> sectionsList = [];
    if (data['sections'] != null && data['sections'] is List) {
      sectionsList = (data['sections'] as List)
          .map((section) => Section.fromFirestore(section as Map<String, dynamic>))
          .toList();
      
      // Sort sections by order
      sectionsList.sort((a, b) => a.order.compareTo(b.order));
    }

    return TrafficRuleTopic.firebase(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      content: data['content'],
      language: data['language'] ?? 'uk',
      state: data['state'] ?? 'ALL',
      licenseId: data['licenseId'] ?? 'driver',
      order: data['order'] ?? 0,
      sections: sectionsList,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      if (content != null) 'content': content,
      'language': language,
      'state': state,
      'licenseId': licenseId,
      'order': order,
      'sections': sections.map((section) => section.toFirestore()).toList(),
    };
  }
}
