class RoadSign {
  final String id;
  final String name;
  final String signCode;
  final String imageUrl;
  final String description;
  final String installationGuidelines;
  final String? exampleImageUrl;

  RoadSign({
    required this.id,
    required this.name,
    required this.signCode,
    required this.imageUrl,
    required this.description,
    required this.installationGuidelines,
    this.exampleImageUrl,
  });
}