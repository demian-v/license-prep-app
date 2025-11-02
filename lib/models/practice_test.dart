/// Model class representing a practice test
class PracticeTest {
  final String id;
  final String licenseId;
  final String title;
  final String description;
  final int questions;
  final int timeLimit;

  PracticeTest({
    required this.id,
    required this.licenseId,
    required this.title,
    required this.description,
    required this.questions,
    required this.timeLimit,
  });
}
