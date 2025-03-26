class UserProgress {
  final List<String> completedModules;
  final Map<String, double> testScores;
  final String? selectedLicense;
  final Map<String, double> topicProgress; // Added for quiz progress
  final List<String> savedQuestions; // Deprecated but kept for backward compatibility
  final Map<String, List<String>> savedItems; // New structure for saved items
  final Map<String, Map<String, int>> savedItemsOrder; // To track order of saved items

  UserProgress({
    required this.completedModules,
    required this.testScores,
    this.selectedLicense,
    required this.topicProgress,
    required this.savedQuestions,
    Map<String, List<String>>? savedItems,
    Map<String, Map<String, int>>? savedItemsOrder,
  }) : this.savedItems = savedItems ?? {},
       this.savedItemsOrder = savedItemsOrder ?? {};

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    Map<String, double> scores = {};
    Map<String, double> topics = {};
    Map<String, List<String>> savedItemsMap = {};
    Map<String, Map<String, int>> savedItemsOrderMap = {};
    
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
    
    if (json['savedItems'] != null) {
      (json['savedItems'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
          savedItemsMap[key] = List<String>.from(value);
        }
      });
    }
    
    if (json['savedItemsOrder'] != null) {
      (json['savedItemsOrder'] as Map<String, dynamic>).forEach((key, value) {
        if (value is Map) {
          savedItemsOrderMap[key] = Map<String, int>.from(value);
        }
      });
    }
    
    return UserProgress(
      completedModules: List<String>.from(json['completedModules'] ?? []),
      testScores: scores,
      selectedLicense: json['selectedLicense'],
      topicProgress: topics,
      savedQuestions: List<String>.from(json['savedQuestions'] ?? []),
      savedItems: savedItemsMap,
      savedItemsOrder: savedItemsOrderMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedModules': completedModules,
      'testScores': testScores,
      'selectedLicense': selectedLicense,
      'topicProgress': topicProgress,
      'savedQuestions': savedQuestions,
      'savedItems': savedItems,
      'savedItemsOrder': savedItemsOrder,
    };
  }

  UserProgress copyWith({
    List<String>? completedModules,
    Map<String, double>? testScores,
    String? selectedLicense,
    Map<String, double>? topicProgress,
    List<String>? savedQuestions,
    Map<String, List<String>>? savedItems,
    Map<String, Map<String, int>>? savedItemsOrder,
  }) {
    return UserProgress(
      completedModules: completedModules ?? this.completedModules,
      testScores: testScores ?? this.testScores,
      selectedLicense: selectedLicense ?? this.selectedLicense,
      topicProgress: topicProgress ?? this.topicProgress,
      savedQuestions: savedQuestions ?? this.savedQuestions,
      savedItems: savedItems ?? this.savedItems,
      savedItemsOrder: savedItemsOrder ?? this.savedItemsOrder,
    );
  }
  
  double get overallTopicProgress {
    if (topicProgress.isEmpty) return 0.0;
    double sum = topicProgress.values.fold(0.0, (a, b) => a + b);
    return sum / topicProgress.length;
  }
}
