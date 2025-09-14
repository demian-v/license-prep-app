class QuizTopic {
  final String id;
  final String title;
  final int questionCount;
  final double progress;
  final List<String> questionIds;
  final String? iconAsset;

  QuizTopic({
    required this.id,
    required this.title,
    required this.questionCount,
    this.progress = 0.0,
    required this.questionIds,
    this.iconAsset,
  });
}
