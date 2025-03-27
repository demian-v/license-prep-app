import '../../../models/quiz_topic.dart';
import '../../../models/quiz_question.dart';
import '../../../models/theory_module.dart';
import '../../../models/practice_test.dart';
import '../../../models/traffic_rule_topic.dart';

/// Base interface for content API
abstract class ContentApiInterface {
  /// Get quiz topics based on license type, language, and state
  Future<List<QuizTopic>> getQuizTopics(String licenseType, String language, String state);
  
  /// Get quiz questions based on topic ID, language, and state
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state);
  
  /// Get theory modules based on license type, language, and state
  Future<List<TheoryModule>> getTheoryModules(String licenseType, String language, String state);
  
  /// Get practice tests based on license type, language, and state
  Future<List<PracticeTest>> getPracticeTests(String licenseType, String language, String state);
  
  /// Get traffic rule topics from Firestore
  /// This method is only used by the FirebaseContentApi implementation
  Future<List<TrafficRuleTopic>> getTrafficRuleTopics(String language, String state, String licenseId);
  
  /// Get a specific traffic rule topic by ID
  /// This method is only used by the FirebaseContentApi implementation
  Future<TrafficRuleTopic?> getTrafficRuleTopic(String topicId);
}
