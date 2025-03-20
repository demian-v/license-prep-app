import '../../../models/quiz_topic.dart';
import '../../../models/quiz_question.dart';
import '../../../models/road_sign_category.dart';
import '../../../models/road_sign.dart';
import '../../../models/theory_module.dart';
import '../../../models/practice_test.dart';

/// Base interface for content API
abstract class ContentApiInterface {
  /// Get quiz topics based on license type, language, and state
  Future<List<QuizTopic>> getQuizTopics(String licenseType, String language, String state);
  
  /// Get quiz questions based on topic ID, language, and state
  Future<List<QuizQuestion>> getQuizQuestions(String topicId, String language, String state);
  
  /// Get road sign categories for a specific language
  Future<List<RoadSignCategory>> getRoadSignCategories(String language);
  
  /// Get road signs for a specific category and language
  Future<List<RoadSign>> getRoadSigns(String categoryId, String language);
  
  /// Get theory modules based on license type, language, and state
  Future<List<TheoryModule>> getTheoryModules(String licenseType, String language, String state);
  
  /// Get practice tests based on license type, language, and state
  Future<List<PracticeTest>> getPracticeTests(String licenseType, String language, String state);
}
