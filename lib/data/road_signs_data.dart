import '../models/road_sign.dart';
import '../models/road_sign_category.dart';

final String roadSignsIntro = 
  'Дорожні знаки — це засоби організації дорожнього руху, які представляють собою стандартизовані графічні малюнки, що передають певні повідомлення учасникам дорожнього руху.';

final List<RoadSignCategory> roadSignCategories = [
  RoadSignCategory(
    id: 'warning',
    title: 'Попереджувальні знаки',
    iconUrl: 'assets/images/signs/warning_icon.png',
    description: 'Попереджувальні знаки інформують водіїв про наближення до небезпечної ділянки дороги і характер небезпеки. Під час руху по цій ділянці необхідно вжити заходів для безпечного проїзду.',
    signs: [
      RoadSign(
        id: '1.1',
        name: 'Небезпечний поворот праворуч',
        signCode: 'знак 1.1',
        imageUrl: 'assets/images/signs/1.1.png',
        description: 'Знак попереджає про заокруглення дороги радіусом менше 500 м поза населеними пунктами і менше 150 м — у населених пунктах або про заокруглення з обмеженою оглядовістю.',
        installationGuidelines: 'Попереджувальний знак установлюється поза населеними пунктами на відстані 150–300 м, у населених пунктах — на відстані 50–100 м до початку небезпечної ділянки. У разі потреби знак установлюється і на іншій відстані, яка зазначається на табличці 7.1.1',
        exampleImageUrl: 'assets/images/signs/examples/1.1_example.jpg',
      ),
      RoadSign(
        id: '1.2',
        name: 'Небезпечний поворот ліворуч',
        signCode: 'знак 1.2',
        imageUrl: 'assets/images/signs/1.2.png',
        description: 'Знак попереджає про заокруглення дороги радіусом менше 500 м поза населеними пунктами і менше 150 м — у населених пунктах або про заокруглення з обмеженою оглядовістю.',
        installationGuidelines: 'Попереджувальний знак установлюється поза населеними пунктами на відстані 150–300 м, у населених пунктах — на відстані 50–100 м до початку небезпечної ділянки.',
        exampleImageUrl: 'assets/images/signs/examples/1.2_example.jpg',
      ),
      // Add more warning signs...
    ],
  ),
  RoadSignCategory(
    id: 'priority',
    title: 'Знаки пріоритету',
    iconUrl: 'assets/images/signs/priority_icon.png',
    description: 'Знаки пріоритету встановлюють черговість проїзду перехресть, перехрещень проїзних частин або вузьких ділянок дороги.',
    signs: [
      RoadSign(
        id: '2.1',
        name: 'Дати дорогу',
        signCode: 'знак 2.1',
        imageUrl: 'assets/images/signs/2.1.png',
        description: 'Водій повинен дати дорогу транспортним засобам, що під\'їжджають до нерегульованого перехрестя по головній дорозі, а за наявності таблички 7.8 — транспортним засобам, що рухаються по головній дорозі.',
        installationGuidelines: 'Знак встановлюється безпосередньо перед перехрестям або вузькою ділянкою дороги. Поза населеними пунктами на дорогах з твердим покриттям знак повторюється з додатковою табличкою 7.1.1.',
        exampleImageUrl: 'assets/images/signs/examples/2.1_example.jpg',
      ),
      // Add more priority signs...
    ],
  ),
  RoadSignCategory(
    id: 'prohibition',
    title: 'Заборонні знаки',
    iconUrl: 'assets/images/signs/prohibition_icon.png',
    description: 'Заборонні знаки запроваджують або скасовують певні обмеження в русі.',
    signs: [
      RoadSign(
        id: '3.1',
        name: 'Рух заборонено',
        signCode: 'знак 3.1',
        imageUrl: 'assets/images/signs/3.1.png',
        description: 'Забороняється рух усіх транспортних засобів у випадках, коли:\n- початок пішохідної зони позначено знаком 5.36;\n- дорога та (або) вулиця перебуває в аварійному стані і непридатна для руху транспортних засобів; у такому випадку обов\'язково додатково встановлюється знак 3.43.',
        installationGuidelines: 'Не поширюється дія знака:\n- на транспортні засоби, що рухаються за встановленими маршрутами;\n-на водіїв з інвалідністю, що керують мотоколяскою або автомобілем, позначеними розпізнавальним знаком «Водій з інвалідністю».',
        exampleImageUrl: 'assets/images/signs/examples/3.1_example.jpg',
      ),
      // Add more prohibition signs...
    ],
  ),
  RoadSignCategory(
    id: 'mandatory',
    title: 'Наказові знаки',
    iconUrl: 'assets/images/signs/mandatory_icon.png',
    description: 'Наказові знаки встановлюють обов\'язкові для водіїв напрямки руху, дозволені види маневрів або обмеження швидкості.',
    signs: [],
  ),
  RoadSignCategory(
    id: 'information',
    title: 'Інформаційно-вказівні знаки',
    iconUrl: 'assets/images/signs/information_icon.png',
    description: 'Інформаційно-вказівні знаки інформують про розташування населених пунктів та інших об\'єктів, встановлюють або скасовують певний режим руху.',
    signs: [],
  ),
  RoadSignCategory(
    id: 'service',
    title: 'Знаки сервісу',
    iconUrl: 'assets/images/signs/service_icon.png',
    description: 'Знаки сервісу інформують про розташування об\'єктів обслуговування.',
    signs: [],
  ),
  RoadSignCategory(
    id: 'additional',
    title: 'Таблички до дорожніх знаків',
    iconUrl: 'assets/images/signs/additional_icon.png',
    description: 'Таблички до дорожніх знаків уточнюють або обмежують дію знаків, разом з якими вони встановлені.',
    signs: [],
  ),
];