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

  /// Create a QuizQuestion from a map (e.g., from Firebase Functions)
  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    // Parse question type
    QuestionType questionType = QuestionType.singleChoice;
    if (map['type'] != null) {
      switch (map['type'] as String) {
        case 'trueFalse':
          questionType = QuestionType.trueFalse;
          break;
        case 'multipleChoice':
          questionType = QuestionType.multipleChoice;
          break;
        case 'singleChoice':
        default:
          questionType = QuestionType.singleChoice;
          break;
      }
    }

    // Parse options
    List<String> options = [];
    if (map['options'] != null) {
      if (map['options'] is List) {
        options = List<String>.from(map['options']);
      }
    }

    return QuizQuestion(
      id: map['id'] ?? '',
      topicId: map['topicId'] ?? '',
      questionText: map['questionText'] ?? '',
      options: options,
      correctAnswer: map['correctAnswer'],
      explanation: map['explanation'],
      ruleReference: map['ruleReference'],
      imagePath: map['imagePath'],
      type: questionType,
    );
  }
}
