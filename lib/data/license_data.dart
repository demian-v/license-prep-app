import '../models/license_type.dart';
import '../models/theory_module.dart';
import '../models/practice_test.dart';

final List<LicenseType> licenseTypes = [
  LicenseType(
    id: 'driver',
    name: 'Правила Дорожнього Руху',
    description: 'Теоретичний курс майбутнього водія',
    icon: 'Car',
    modules: 5,
    tests: 3,
  ),
];

final List<TheoryModule> theoryModules = [
  TheoryModule(
    id: 'traffic-rules',
    licenseId: 'driver',
    title: 'Правила дорожнього руху',
    description: 'Вивчення основних правил дорожнього руху',
    estimatedTime: 45,
    topics: ['Загальні положення', 'Обов\'язки учасників руху', 'Регулювання руху'],
  ),
  TheoryModule(
    id: 'road-signs',
    licenseId: 'driver',
    title: 'Знаки',
    description: 'Вивчення дорожніх знаків та їх значення',
    estimatedTime: 30,
    topics: ['Попереджувальні знаки', 'Знаки пріоритету', 'Заборонні знаки'],
  ),
  TheoryModule(
    id: 'traffic-lights',
    licenseId: 'driver',
    title: 'Світлофор',
    description: 'Вивчення сигналів світлофора',
    estimatedTime: 15,
    topics: ['Типи світлофорів', 'Значення сигналів'],
  ),
];

final List<PracticeTest> practiceTests = [
  PracticeTest(
    id: 'exam-simulation',
    licenseId: 'driver',
    title: 'Складай іспит',
    description: 'як в СЦ МВС: 20 запитань, 20 хвилин',
    questions: 20,
    timeLimit: 20,
  ),
  PracticeTest(
    id: 'random-questions',
    licenseId: 'driver',
    title: 'Тренуйся по білетах',
    description: '20 випадкових запитань, без обмежень',
    questions: 20,
    timeLimit: 0,
  ),
  PracticeTest(
    id: 'my-mistakes',
    licenseId: 'driver',
    title: 'Мої помилки',
    description: 'Запитання, де були допущені помилки',
    questions: 0,
    timeLimit: 0,
  ),
];
