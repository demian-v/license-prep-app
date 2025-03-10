class UserProgress {
  final List<String> completedModules;
  final Map<String, double> testScores;
  final String? selectedLicense;
  final Map<String, double> topicProgress; // Added for quiz progress
  final List<String> savedQuestions; // For storing saved/favorited questions

  UserProgress({
    required this.completedModules,
    required this.testScores,
    this.selectedLicense,
    required this.topicProgress,
    required this.savedQuestions,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    Map<String, double> scores = {};
    Map<String, double> topics = {};
    
    if (json['testScores'] != null) {
      json['testScores'].forEach((key, value) {
        scores[key] = value.toDouble();
      });
    }
    
    if (json['topicProgress'] != null) {
      json['topicProgress'].forEach((key, value) {
        topics[key] = value.toDouble();
      });
    }
    
    return UserProgress(
      completedModules: List<String>.from(json['completedModules'] ?? []),
      testScores: scores,
      selectedLicense: json['selectedLicense'],
      topicProgress: topics,
      savedQuestions: List<String>.from(json['savedQuestions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedModules': completedModules,
      'testScores': testScores,
      'selectedLicense': selectedLicense,
      'topicProgress': topicProgress,
      'savedQuestions': savedQuestions,
    };
  }

  UserProgress copyWith({
    List<String>? completedModules,
    Map<String, double>? testScores,
    String? selectedLicense,
    Map<String, double>? topicProgress,
    List<String>? savedQuestions,
  }) {
    return UserProgress(
      completedModules: completedModules ?? this.completedModules,
      testScores: testScores ?? this.testScores,
      selectedLicense: selectedLicense ?? this.selectedLicense,
      topicProgress: topicProgress ?? this.topicProgress,
      savedQuestions: savedQuestions ?? this.savedQuestions,
    );
  }
  
  double get overallTopicProgress {
    if (topicProgress.isEmpty) return 0.0;
    double sum = topicProgress.values.fold(0.0, (a, b) => a + b);
    return sum / topicProgress.length;
  }
}
