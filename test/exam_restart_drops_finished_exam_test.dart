import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/models/exam.dart';
import 'package:license_prep_app/providers/exam_provider.dart';

/// Тесты pushes the exam question screen without awaiting `startNewExam`, and
/// that screen sends a finished exam straight to its result page. Leaving a
/// result page with the system Back button never called `cancelExam`, so the
/// next Take Exam found the old, finished exam and opened an empty result
/// (0/0, 00:00) instead of question 1 (Android, 2026-10-31).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starting a new exam drops a finished one before anything loads', () async {
    final provider = ExamProvider();
    provider.debugCurrentExam = Exam(
      questionIds: const ['q1'],
      startTime: DateTime.now().subtract(const Duration(minutes: 3)),
      timeLimit: 60,
    ).copyWith(isCompleted: true, completedAt: DateTime.now());

    // Not awaited, as test_screen.dart does: the question screen reads the
    // provider while the questions are still loading.
    final loading = provider.startNewExam(language: 'en', state: 'CA');

    expect(provider.currentExam, isNull);
    expect(provider.isLoading, isTrue);

    await loading; // No Firebase here, so loading fails and is reported.
    expect(provider.currentExam, isNull);
  });
}
