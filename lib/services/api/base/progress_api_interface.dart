/// Base interface for progress API
abstract class ProgressApiInterface {
  /// Get the overall progress for a user
  Future<Map<String, dynamic>> getUserProgress([String? userId]);
  
  /// Update the progress for a specific module
  Future<Map<String, dynamic>> updateModuleProgress(String moduleId, double progress, [String? userId]);
  
  /// Update quiz progress for a topic
  Future<Map<String, dynamic>> updateTopicProgress(String topicId, double progress, [String? userId]);
  
  /// Save a question answer
  Future<Map<String, dynamic>> updateQuestionProgress(String questionId, bool isCorrect, [String? userId]);
  
  /// Save test score for practice test or exam
  Future<Map<String, dynamic>> saveTestScore(String testId, double score, String testType, [String? userId]);
  
  /// Get saved items (bookmarked questions, topics, etc.)
  Future<dynamic> getSavedItems([String? userId]);
  
  /// Add a saved item (bookmark a question, topic, etc.)
  Future<Map<String, dynamic>> saveItem(String itemId, String itemType, [String? userId]);
  
  /// Remove a saved item (unbookmark a question, topic, etc.)
  Future<Map<String, dynamic>> removeSavedItem(String itemId, String itemType, [String? userId]);
}
