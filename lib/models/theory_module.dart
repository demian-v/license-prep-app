class TheoryModule {
  final String id;
  final String licenseId;
  final String title;
  final String description;
  final int estimatedTime;
  final List<String> topics;

  TheoryModule({
    required this.id,
    required this.licenseId,
    required this.title,
    required this.description,
    required this.estimatedTime,
    required this.topics,
  });
}