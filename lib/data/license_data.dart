import '../models/license_type.dart';
import '../models/theory_module.dart';

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
