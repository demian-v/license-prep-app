enum QuestionType {
  trueFalse,
  multipleChoice,
  singleChoice,
}

class QuizQuestion {
  final String id;
  final String topicId;
  final String questionText;
  final List<String> options;
  final dynamic correctAnswer; // Can be boolean, String, or List<String>
  final String? explanation;
  final String? ruleReference;
  final String? imagePath;
  final QuestionType type;

  QuizQuestion({
    required this.id,
    required this.topicId,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.ruleReference,
    this.imagePath,
    required this.type,
  });
}