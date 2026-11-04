import '../models/quiz_question.dart';

/// Learn-by-Topics question order (App fix C).
///
/// Pipeline states write an authored 1-based `order` on every question, and
/// their ids end in a number that restarts per subject (`t02a_..._01`,
/// `t02a_..._01`, ...), so the id suffix is not a position. Questions with no
/// `order` (the legacy IL/NY docs) keep the old suffix sort. Kept separate from
/// the API class so the rule can be unit-tested without Firebase.
class QuestionOrder {
  const QuestionOrder._();

  /// Trailing number of an id: `q_il_en_duties_01` -> 1; none -> 0.
  static int numericIdSuffix(String questionId) {
    final match = RegExp(r'_(\d+)$').firstMatch(questionId);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  /// Sort in place, stably: `order` first (the id suffix when `order` is null),
  /// then the id suffix, then the incoming position. Returns the same list.
  static List<QuizQuestion> sortForTopic(List<QuizQuestion> questions) {
    final keyed = <MapEntry<int, QuizQuestion>>[];
    for (var i = 0; i < questions.length; i++) {
      keyed.add(MapEntry(i, questions[i]));
    }
    keyed.sort((a, b) {
      final aSuffix = numericIdSuffix(a.value.id);
      final bSuffix = numericIdSuffix(b.value.id);
      var cmp = (a.value.order ?? aSuffix).compareTo(b.value.order ?? bSuffix);
      if (cmp != 0) return cmp;
      cmp = aSuffix.compareTo(bSuffix);
      if (cmp != 0) return cmp;
      return a.key.compareTo(b.key);
    });
    questions
      ..clear()
      ..addAll(keyed.map((e) => e.value));
    return questions;
  }
}
