import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/models/exam.dart';

/// The result pages (Экзамен, Практика) show `elapsedTime`. It used to be
/// computed from `DateTime.now()` even after completion, so the time on the
/// result page kept counting up while it was open (observed 01:06 → 01:26,
/// 2026-09-26), and the analytics event sent a later time than the real one.
void main() {
  test('elapsed time stops at the moment the exam was completed', () {
    final start = DateTime.now().subtract(const Duration(minutes: 5));
    final completedAt = start.add(const Duration(minutes: 2, seconds: 30));
    final exam = Exam(
      questionIds: const ['q1'],
      startTime: start,
      timeLimit: 60,
    ).copyWith(isCompleted: true, completedAt: completedAt);

    expect(exam.elapsedTime, const Duration(minutes: 2, seconds: 30));
  });

  test('elapsed time never exceeds the time limit', () {
    final start = DateTime.now().subtract(const Duration(minutes: 90));
    final exam = Exam(
      questionIds: const ['q1'],
      startTime: start,
      timeLimit: 60,
    ).copyWith(
      isCompleted: true,
      completedAt: start.add(const Duration(minutes: 75)),
    );

    expect(exam.elapsedTime, const Duration(minutes: 60));
  });

  test('an exam in progress still reports live elapsed time', () {
    final start = DateTime.now().subtract(const Duration(minutes: 3));
    final exam = Exam(questionIds: const ['q1'], startTime: start, timeLimit: 60);

    expect(exam.elapsedTime.inMinutes, 3);
  });
}
