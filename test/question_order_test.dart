import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/models/quiz_question.dart';
import 'package:license_prep_app/services/question_order.dart';

/// App fix C — Learn-by-Topics must follow the authored `order`, not the id's
/// numeric suffix. The ids below are real shapes from the vault.
QuizQuestion q(String id, {int? order}) => QuizQuestion(
      id: id,
      topicId: 't',
      questionText: id,
      options: const ['a', 'b'],
      correctAnswer: 'a',
      type: QuestionType.singleChoice,
      order: order,
    );

List<String> ids(List<QuizQuestion> l) => l.map((e) => e.id).toList();

void main() {
  test('NY redo: every id ends _01 - order decides', () {
    final list = [
      q('q_ny_en_t02b_hill_parking_04', order: 3),
      q('q_ny_en_t02a_left_turn_wait_in_intersection_01', order: 1),
      q('q_ny_en_t02a_wheels_straight_before_turn_01', order: 2),
    ];
    expect(ids(QuestionOrder.sortForTopic(list)), [
      'q_ny_en_t02a_left_turn_wait_in_intersection_01',
      'q_ny_en_t02a_wheels_straight_before_turn_01',
      'q_ny_en_t02b_hill_parking_04',
    ]);
  });

  test('IL redo: the same suffix in both halves of topic 1', () {
    final list = [
      q('q_il_en_t01b_x_01', order: 25),
      q('q_il_en_t01a_y_02', order: 2),
      q('q_il_en_t01a_z_01', order: 1),
    ];
    expect(ids(QuestionOrder.sortForTopic(list)),
        ['q_il_en_t01a_z_01', 'q_il_en_t01a_y_02', 'q_il_en_t01b_x_01']);
  });

  test('pipeline order beats a smaller suffix (VA-style restarting suffixes)', () {
    final list = [
      q('default_speed_25_02', order: 1),
      q('speed_limit_meaning_01', order: 2),
    ];
    expect(ids(QuestionOrder.sortForTopic(list)),
        ['default_speed_25_02', 'speed_limit_meaning_01']);
  });

  test('legacy docs with no order keep the suffix sort', () {
    final list = [q('q_il_en_duties_03'), q('q_il_en_duties_01'), q('q_il_en_duties_02')];
    expect(ids(QuestionOrder.sortForTopic(list)),
        ['q_il_en_duties_01', 'q_il_en_duties_02', 'q_il_en_duties_03']);
  });

  test('ties keep their incoming position (stable)', () {
    final list = [q('b_x', order: 1), q('a_x', order: 1)];
    expect(ids(QuestionOrder.sortForTopic(list)), ['b_x', 'a_x']);
  });

  test('parseOrder: 0, negative, junk and null are "no order"', () {
    expect(QuizQuestion.parseOrder(0), isNull);
    expect(QuizQuestion.parseOrder(-1), isNull);
    expect(QuizQuestion.parseOrder('x'), isNull);
    expect(QuizQuestion.parseOrder(null), isNull);
    expect(QuizQuestion.parseOrder('7'), 7);
    expect(QuizQuestion.parseOrder(7.0), 7);
  });

  test('numericIdSuffix', () {
    expect(QuestionOrder.numericIdSuffix('q_il_en_duties_01'), 1);
    expect(QuestionOrder.numericIdSuffix('no_suffix'), 0);
  });
}
