class QuizProgress {
  final Map<String, bool> answeredQuestions; // questionId -> isCorrect
  final Map<String, double> topicProgress; // topicId -> progress percentage

  QuizProgress({
    required this.answeredQuestions,
    required this.topicProgress,
  });

  double get overallProgress {
    if (topicProgress.isEmpty) return 0.0;
    double sum = topicProgress.values.fold(0.0, (a, b) => a + b);
    return sum / topicProgress.length;
  }
}