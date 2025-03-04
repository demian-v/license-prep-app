class TrafficLightInfo {
  final String id;
  final String title;
  final String content;
  final List<String> imageUrls;

  TrafficLightInfo({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrls = const [],
  });
}