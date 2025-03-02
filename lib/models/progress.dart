class UserProgress {
  final List<String> completedModules;
  final Map<String, double> testScores;
  final String? selectedLicense;

  UserProgress({
    required this.completedModules,
    required this.testScores,
    this.selectedLicense,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    Map<String, double> scores = {};
    
    if (json['testScores'] != null) {
      json['testScores'].forEach((key, value) {
        scores[key] = value.toDouble();
      });
    }
    
    return UserProgress(
      completedModules: List<String>.from(json['completedModules'] ?? []),
      testScores: scores,
      selectedLicense: json['selectedLicense'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedModules': completedModules,
      'testScores': testScores,
      'selectedLicense': selectedLicense,
    };
  }

  UserProgress copyWith({
    List<String>? completedModules,
    Map<String, double>? testScores,
    String? selectedLicense,
  }) {
    return UserProgress(
      completedModules: completedModules ?? this.completedModules,
      testScores: testScores ?? this.testScores,
      selectedLicense: selectedLicense ?? this.selectedLicense,
    );
  }
}