class Exam {
  final List<String> questionIds;
  final Map<String, bool> answers; // questionId -> isCorrect
  final DateTime startTime;
  final int timeLimit; // in minutes
  int currentQuestionIndex;
  bool isCompleted;

  Exam({
    required this.questionIds,
    required this.startTime,
    required this.timeLimit,
    this.currentQuestionIndex = 0,
    this.isCompleted = false,
    Map<String, bool>? answers,
  }) : this.answers = answers ?? {};

  DateTime get endTime => startTime.add(Duration(minutes: timeLimit));
  
  bool get isTimeLimitExceeded {
    final now = DateTime.now();
    return now.isAfter(endTime);
  }
  
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(endTime)) {
      return Duration.zero;
    }
    return endTime.difference(now);
  }
  
  int get correctAnswersCount => answers.values.where((isCorrect) => isCorrect).length;
  
  int get incorrectAnswersCount => answers.values.where((isCorrect) => !isCorrect).length;
  
  int get answeredQuestionsCount => answers.length;
  
  bool get isPassed {
    // Exam is passed if user has at least 36 correct answers (90% of 40)
    return correctAnswersCount >= 36;
  }
  
  Duration get elapsedTime {
    if (isCompleted) {
      return Duration(minutes: timeLimit) - remainingTime;
    } else {
      return DateTime.now().difference(startTime);
    }
  }
  
  Exam copyWith({
    List<String>? questionIds,
    Map<String, bool>? answers,
    DateTime? startTime,
    int? timeLimit,
    int? currentQuestionIndex,
    bool? isCompleted,
  }) {
    return Exam(
      questionIds: questionIds ?? this.questionIds,
      answers: answers ?? this.answers,
      startTime: startTime ?? this.startTime,
      timeLimit: timeLimit ?? this.timeLimit,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
