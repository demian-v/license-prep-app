import '../models/quiz_question.dart';
import '../models/quiz_topic.dart';

final List<QuizTopic> quizTopics = [
  QuizTopic(
    id: 'general',
    title: 'ЗАГАЛЬНІ ПОЛОЖЕННЯ',
    questionCount: 79,
    questionIds: ['q1', 'q2', 'q3', 'q4', 'q5'],
  ),
  QuizTopic(
    id: 'driver_obligations',
    title: 'ОБОВ\'ЯЗКИ І ПРАВА ВОДІЇВ МЕХАНІЧНИХ ТРАНСПОРТНИХ ЗАСОБІВ',
    questionCount: 37,
    questionIds: ['q6', 'q7', 'q8', 'q9', 'q10'],
  ),
  QuizTopic(
    id: 'special_signals',
    title: 'РУХ ТРАНСПОРТНИХ ЗАСОБІВ ІЗ СПЕЦІАЛЬНИМИ СИГНАЛАМИ',
    questionCount: 15,
    questionIds: ['q11', 'q12', 'q13', 'q14', 'q15'],
  ),
  QuizTopic(
    id: 'pedestrian_obligations',
    title: 'ОБОВ\'ЯЗКИ І ПРАВА ПІШОХОДІВ',
    questionCount: 26,
    questionIds: ['q16', 'q17', 'q18', 'q19', 'q20'],
  ),
  QuizTopic(
    id: 'passenger_obligations',
    title: 'ОБОВ\'ЯЗКИ І ПРАВА ПАСАЖИРІВ',
    questionCount: 16,
    questionIds: ['q21', 'q22', 'q23', 'q24', 'q25'],
  ),
  QuizTopic(
    id: 'cyclist_requirements',
    title: 'ВИМОГИ ДО ВЕЛОСИПЕДИСТІВ',
    questionCount: 12,
    questionIds: ['q26', 'q27', 'q28', 'q29', 'q30'],
  ),
];

final Map<String, QuizQuestion> quizQuestions = {
  'q1': QuizQuestion(
    id: 'q1',
    topicId: 'general',
    questionText: 'Чи належить до проїзної частини велосипедна смуга?',
    options: ['Так, належить.', 'Ні, не належить.'],
    correctAnswer: 'Так, належить.',
    explanation: 'Велосипедна смуга - смуга, призначена для руху на велосипедах у межах проїзної частини вулиці та/або дороги, яка позначена дорожнім знаком 5.88 та відповідною горизонтальною дорожньою розміткою;',
    ruleReference: 'ПДР 1.10',
    type: QuestionType.singleChoice,
  ),
  
  'q2': QuizQuestion(
    id: 'q2',
    topicId: 'general',
    questionText: 'Поздовжня смуга на проїзній частині завширшки щонайменше 2,75 м, що позначена або не позначена дорожньою розміткою і призначена для руху нерейкових транспортних засобів це:',
    options: ['Розділювальна смуга.', 'Смуга руху.', 'Трамвайна колія.'],
    correctAnswer: 'Смуга руху.',
    imagePath: 'assets/images/quiz/lane.jpg',
    type: QuestionType.singleChoice,
  ),
  
  'q13': QuizQuestion(
    id: 'q13',
    topicId: 'special_signals',
    questionText: 'Чи надає перевагу в русі ввімкнення проблискового маячка оранжевого кольору на транспортних засобах дорожньо-експлуатаційної служби під час виконання роботи?',
    options: ['Так.', 'Ні.'],
    correctAnswer: 'Ні.',
    explanation: 'Увімкнення проблискового маячка оранжевого кольору на транспортних засобах з розпізнавальним знаком «Діти», на механічних транспортних засобах дорожньо-експлуатаційної служби під час виконання роботи на дорозі, на великогабаритних та великовагових транспортних засобах, на сільськогосподарській техніці, ширина якої перевищує 2,6 м, не дає їм переваги в русі, а служить для привернення уваги та попередження про небезпеку...',
    ruleReference: 'ПДР 3.6',
    type: QuestionType.singleChoice,
  ),
  
  'q14': QuizQuestion(
    id: 'q14',
    topicId: 'special_signals',
    questionText: 'Трамвайна колія – елемент дороги, призначений для руху рейкових транспортних засобів, який обмежується по ширині:',
    options: [
      'Спеціально виділеним вимощенням трамвайної лінії.',
      'Дорожньої розміткою.',
      'Відповіді, зазначені в пунктах 1 та 2.',
    ],
    correctAnswer: 'Відповіді, зазначені в пунктах 1 та 2.',
    imagePath: 'assets/images/quiz/tram.jpg',
    type: QuestionType.singleChoice,
  ),
  
  // Add more questions here
};