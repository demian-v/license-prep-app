import '../../models/quiz_question.dart';
import '../../models/theory_module.dart';
import '../../models/traffic_rule_topic.dart';

/// Interface for content-related API operations
/// 
/// Implementations may use different data sources (REST API, Firebase, etc.)
abstract class ContentApiInterface {
  /// Get the list of traffic rule topics
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String? state);
  
  /// Get a specific traffic rule topic by ID
  Future<TrafficRuleTopic?> getTrafficRuleTopic(String topicId, String language, String? state);
  
  /// Get a list of quiz questions for a specific topic
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String? state);
  
  /// Get a list of theory modules
  Future<List<TheoryModule>> getTheoryModules(String language, String? state, String licenseId);
  
  /// Get a specific theory module
  Future<TheoryModule?> getTheoryModule(String moduleId, String language, String? state);
}
