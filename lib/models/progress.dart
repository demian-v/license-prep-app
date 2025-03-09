class UserProgress {
  final List<String> completedModules;
  final Map<String, double> testScores;
  final String? selectedLicense;
  final Map<String, double> topicProgress; // Added for quiz progress

  UserProgress({
    required this.completedModules,
    required this.testScores,
    this.selectedLicense,
    required this.topicProgress, // New parameter
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedModules': completedModules,
      'testScores': testScores,
      'selectedLicense': selectedLicense,
      'topicProgress': topicProgress,
    };
  }

  UserProgress copyWith({
    List<String>? completedModules,
    Map<String, double>? testScores,
    String? selectedLicense,
    Map<String, double>? topicProgress,
  }) {
    return UserProgress(
      completedModules: completedModules ?? this.completedModules,
      testScores: testScores ?? this.testScores,
      selectedLicense: selectedLicense ?? this.selectedLicense,
      topicProgress: topicProgress ?? this.topicProgress,
    );
  }
  
  double get overallTopicProgress {
    if (topicProgress.isEmpty) return 0.0;
    double sum = topicProgress.values.fold(0.0, (a, b) => a + b);
    return sum / topicProgress.length;
  }
}
