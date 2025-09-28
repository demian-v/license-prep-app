"use strict";
/**
 * Email templates for subscription notifications
 * Supports multiple languages: en, es, uk, ru, pl
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.replaceTemplateVariables = exports.getRenewalFailureTemplate = exports.getRenewalSuccessTemplate = exports.getSubscriptionExpiredTemplate = exports.getTrialExpiredTemplate = exports.RENEWAL_FAILURE_TEMPLATES = exports.RENEWAL_SUCCESS_TEMPLATES = exports.SUBSCRIPTION_EXPIRED_TEMPLATES = exports.TRIAL_EXPIRED_TEMPLATES = void 0;
/**
 * Trial expired email templates
 */
exports.TRIAL_EXPIRED_TEMPLATES = {
    en: {
        subject: "Your trial has expired - Continue with a subscription",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #007bff; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Your Trial Has Expired</h1>
          </div>
          <div class="content">
            <p>Hello {{userName}},</p>
            <p>Your 3-day free trial has expired. We hope you enjoyed exploring all the features of our license preparation app!</p>
            <p>To continue accessing premium content and features, please choose a subscription plan:</p>
            <ul>
              <li>✅ Full access to all practice questions</li>
              <li>✅ Detailed explanations and rule references</li>
              <li>✅ Progress tracking and analytics</li>
              <li>✅ Offline access to content</li>
              <li>✅ Regular updates with new questions</li>
            </ul>
            <a href="{{subscriptionUrl}}" class="cta">Choose Your Plan</a>
            <p>Don't let your preparation stop here. Get back to studying and ace your license exam!</p>
            <p>Best regards,<br>The License Prep Team</p>
          </div>
          <div class="footer">
            <p>This email was sent because your trial subscription expired. If you have questions, please contact our support team.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hello {{userName}},

Your 3-day free trial has expired. We hope you enjoyed exploring all the features of our license preparation app!

To continue accessing premium content and features, please choose a subscription plan.

Benefits include:
- Full access to all practice questions
- Detailed explanations and rule references  
- Progress tracking and analytics
- Offline access to content
- Regular updates with new questions

Choose Your Plan: {{subscriptionUrl}}

Don't let your preparation stop here. Get back to studying and ace your license exam!

Best regards,
The License Prep Team`
    },
    es: {
        subject: "Tu prueba gratuita ha expirado - Continúa con una suscripción",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #007bff; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Tu Prueba Gratuita Ha Expirado</h1>
          </div>
          <div class="content">
            <p>Hola {{userName}},</p>
            <p>Tu prueba gratuita de 3 días ha expirado. ¡Esperamos que hayas disfrutado explorando todas las características de nuestra app de preparación!</p>
            <p>Para continuar accediendo al contenido y características premium, por favor elige un plan de suscripción:</p>
            <ul>
              <li>✅ Acceso completo a todas las preguntas de práctica</li>
              <li>✅ Explicaciones detalladas y referencias de reglas</li>
              <li>✅ Seguimiento de progreso y análisis</li>
              <li>✅ Acceso sin conexión al contenido</li>
              <li>✅ Actualizaciones regulares con nuevas preguntas</li>
            </ul>
            <a href="{{subscriptionUrl}}" class="cta">Elige Tu Plan</a>
            <p>No dejes que tu preparación se detenga aquí. ¡Vuelve a estudiar y aprueba tu examen de licencia!</p>
            <p>Saludos cordiales,<br>El Equipo de License Prep</p>
          </div>
          <div class="footer">
            <p>Este correo fue enviado porque tu suscripción de prueba expiró. Si tienes preguntas, por favor contacta a nuestro equipo de soporte.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hola {{userName}},

Tu prueba gratuita de 3 días ha expirado. ¡Esperamos que hayas disfrutado explorando todas las características de nuestra app de preparación!

Para continuar accediendo al contenido y características premium, por favor elige un plan de suscripción.

Los beneficios incluyen:
- Acceso completo a todas las preguntas de práctica
- Explicaciones detalladas y referencias de reglas
- Seguimiento de progreso y análisis
- Acceso sin conexión al contenido
- Actualizaciones regulares con nuevas preguntas

Elige Tu Plan: {{subscriptionUrl}}

No dejes que tu preparación se detenga aquí. ¡Vuelve a estudiar y aprueba tu examen de licencia!

Saludos cordiales,
El Equipo de License Prep`
    },
    uk: {
        subject: "Ваш пробний період закінчився - Продовжіть з підпискою",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #007bff; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Ваш Пробний Період Закінчився</h1>
          </div>
          <div class="content">
            <p>Привіт {{userName}},</p>
            <p>Ваш 3-денний безкоштовний пробний період закінчився. Сподіваємося, вам сподобалось досліджувати всі можливості нашого додатку для підготовки до іспитів!</p>
            <p>Щоб продовжити доступ до преміум контенту та функцій, будь ласка, оберіть план підписки:</p>
            <ul>
              <li>✅ Повний доступ до всіх практичних питань</li>
              <li>✅ Детальні пояснення та посилання на правила</li>
              <li>✅ Відстеження прогресу та аналітика</li>
              <li>✅ Офлайн доступ до контенту</li>
              <li>✅ Регулярні оновлення з новими питаннями</li>
            </ul>
            <a href="{{subscriptionUrl}}" class="cta">Оберіть Ваш План</a>
            <p>Не дозволяйте вашій підготовці зупинитися тут. Повертайтесь до навчання та здавайте іспит на отримання ліцензії!</p>
            <p>З найкращими побажаннями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Цей email було надіслано, оскільки ваша пробна підписка закінчилась. Якщо у вас є питання, зв'яжіться з нашою службою підтримки.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привіт {{userName}},

Ваш 3-денний безкоштовний пробний період закінчився. Сподіваємося, вам сподобалось досліджувати всі можливості нашого додатку для підготовки до іспитів!

Щоб продовжити доступ до преміум контенту та функцій, будь ласка, оберіть план підписки.

Переваги включають:
- Повний доступ до всіх практичних питань
- Детальні пояснення та посилання на правила
- Відстеження прогресу та аналітика
- Офлайн доступ до контенту
- Регулярні оновлення з новими питаннями

Оберіть Ваш План: {{subscriptionUrl}}

Не дозволяйте вашій підготовці зупинитися тут. Повертайтесь до навчання та здавайте іспит на отримання ліцензії!

З найкращими побажаннями,
Команда License Prep`
    },
    ru: {
        subject: "Ваш пробный период истек - Продолжите с подпиской",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #007bff; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Ваш Пробный Период Истек</h1>
          </div>
          <div class="content">
            <p>Привет {{userName}},</p>
            <p>Ваш 3-дневный бесплатный пробный период истек. Надеемся, вам понравилось изучать все возможности нашего приложения для подготовки к экзаменам!</p>
            <p>Чтобы продолжить доступ к премиум контенту и функциям, пожалуйста, выберите план подписки:</p>
            <ul>
              <li>✅ Полный доступ ко всем практическим вопросам</li>
              <li>✅ Подробные объяснения и ссылки на правила</li>
              <li>✅ Отслеживание прогресса и аналитика</li>
              <li>✅ Офлайн доступ к контенту</li>
              <li>✅ Регулярные обновления с новыми вопросами</li>
            </ul>
            <a href="{{subscriptionUrl}}" class="cta">Выберите Ваш План</a>
            <p>Не позволяйте вашей подготовке остановиться здесь. Возвращайтесь к изучению и сдавайте экзамен на получение лицензии!</p>
            <p>С наилучшими пожеланиями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Этот email был отправлен, поскольку ваша пробная подписка истекла. Если у вас есть вопросы, свяжитесь с нашей службой поддержки.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привет {{userName}},

Ваш 3-дневный бесплатный пробный период истек. Надеемся, вам понравилось изучать все возможности нашего приложения для подготовки к экзаменам!

Чтобы продолжить доступ к премиум контенту и функциям, пожалуйста, выберите план подписки.

Преимущества включают:
- Полный доступ ко всем практическим вопросам
- Подробные объяснения и ссылки на правила
- Отслеживание прогресса и аналитика
- Офлайн доступ к контенту
- Регулярные обновления с новыми вопросами

Выберите Ваш План: {{subscriptionUrl}}

Не позволяйте вашей подготовке остановиться здесь. Возвращайтесь к изучению и сдавайте экзамен на получение лицензии!

С наилучшими пожеланиями,
Команда License Prep`
    },
    pl: {
        subject: "Twój okres próbny wygasł - Kontynuuj z subskrypcją",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #007bff; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #28a745; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Twój Okres Próbny Wygasł</h1>
          </div>
          <div class="content">
            <p>Cześć {{userName}},</p>
            <p>Twój 3-dniowy bezpłatny okres próbny wygasł. Mamy nadzieję, że podobało Ci się odkrywanie wszystkich funkcji naszej aplikacji do przygotowań do egzaminów!</p>
            <p>Aby nadal korzystać z premium treści i funkcji, proszę wybierz plan subskrypcji:</p>
            <ul>
              <li>✅ Pełny dostęp do wszystkich pytań praktycznych</li>
              <li>✅ Szczegółowe wyjaśnienia i odnośniki do przepisów</li>
              <li>✅ Śledzenie postępów i analityka</li>
              <li>✅ Dostęp offline do treści</li>
              <li>✅ Regularne aktualizacje z nowymi pytaniami</li>
            </ul>
            <a href="{{subscriptionUrl}}" class="cta">Wybierz Swój Plan</a>
            <p>Nie pozwól, żeby Twoje przygotowania zatrzymały się tutaj. Wróć do nauki i zdaj egzamin na prawo jazdy!</p>
            <p>Z najlepszymi życzeniami,<br>Zespół License Prep</p>
          </div>
          <div class="footer">
            <p>Ten email został wysłany, ponieważ Twoja próbna subskrypcja wygasła. Jeśli masz pytania, skontaktuj się z naszym zespołem wsparcia.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Cześć {{userName}},

Twój 3-dniowy bezpłatny okres próbny wygasł. Mamy nadzieję, że podobało Ci się odkrywanie wszystkich funkcji naszej aplikacji do przygotowań do egzaminów!

Aby nadal korzystać z premium treści i funkcji, proszę wybierz plan subskrypcji.

Korzyści obejmują:
- Pełny dostęp do wszystkich pytań praktycznych
- Szczegółowe wyjaśnienia i odnośniki do przepisów
- Śledzenie postępów i analityka
- Dostęp offline do treści
- Regularne aktualizacje z nowymi pytaniami

Wybierz Swój Plan: {{subscriptionUrl}}

Nie pozwól, żeby Twoje przygotowania zatrzymały się tutaj. Wróć do nauki i zdaj egzamin na prawo jazdy!

Z najlepszymi życzeniami,
Zespół License Prep`
    }
};
/**
 * Subscription expired email templates
 */
exports.SUBSCRIPTION_EXPIRED_TEMPLATES = {
    en: {
        subject: "Your subscription has expired - Renew to continue",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Your Subscription Has Expired</h1>
          </div>
          <div class="content">
            <p>Hello {{userName}},</p>
            <p>Your subscription to our license preparation app has expired. Your access to premium features is now limited.</p>
            <p>To restore full access and continue your exam preparation, please renew your subscription:</p>
            <ul>
              <li>📚 Continue accessing all practice questions</li>
              <li>📊 Keep your progress and statistics</li>
              <li>🎯 Get detailed explanations for every answer</li>
              <li>📱 Enjoy offline access</li>
              <li>🔄 Receive the latest question updates</li>
            </ul>
            <a href="{{renewUrl}}" class="cta">Renew Subscription</a>
            <p>Don't lose momentum in your studies. Renew today and stay on track for success!</p>
            <p>Best regards,<br>The License Prep Team</p>
          </div>
          <div class="footer">
            <p>This email was sent because your subscription expired. If you have questions about billing or renewal, please contact support.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hello {{userName}},

Your subscription to our license preparation app has expired. Your access to premium features is now limited.

To restore full access and continue your exam preparation, please renew your subscription.

Benefits you'll regain:
- Continue accessing all practice questions
- Keep your progress and statistics
- Get detailed explanations for every answer
- Enjoy offline access
- Receive the latest question updates

Renew Subscription: {{renewUrl}}

Don't lose momentum in your studies. Renew today and stay on track for success!

Best regards,
The License Prep Team`
    },
    es: {
        subject: "Tu suscripción ha expirado - Renueva para continuar",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Tu Suscripción Ha Expirado</h1>
          </div>
          <div class="content">
            <p>Hola {{userName}},</p>
            <p>Tu suscripción a nuestra app de preparación para licencias ha expirado. Tu acceso a las características premium ahora es limitado.</p>
            <p>Para restaurar el acceso completo y continuar tu preparación para el examen, por favor renueva tu suscripción:</p>
            <ul>
              <li>📚 Continúa accediendo a todas las preguntas de práctica</li>
              <li>📊 Mantén tu progreso y estadísticas</li>
              <li>🎯 Obtén explicaciones detalladas para cada respuesta</li>
              <li>📱 Disfruta del acceso sin conexión</li>
              <li>🔄 Recibe las últimas actualizaciones de preguntas</li>
            </ul>
            <a href="{{renewUrl}}" class="cta">Renovar Suscripción</a>
            <p>No pierdas el impulso en tus estudios. ¡Renueva hoy y mantente en camino al éxito!</p>
            <p>Saludos cordiales,<br>El Equipo de License Prep</p>
          </div>
          <div class="footer">
            <p>Este correo fue enviado porque tu suscripción expiró. Si tienes preguntas sobre facturación o renovación, contacta a soporte.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hola {{userName}},

Tu suscripción a nuestra app de preparación para licencias ha expirado. Tu acceso a las características premium ahora es limitado.

Para restaurar el acceso completo y continuar tu preparación para el examen, por favor renueva tu suscripción.

Beneficios que recuperarás:
- Continúa accediendo a todas las preguntas de práctica
- Mantén tu progreso y estadísticas
- Obtén explicaciones detalladas para cada respuesta
- Disfruta del acceso sin conexión
- Recibe las últimas actualizaciones de preguntas

Renovar Suscripción: {{renewUrl}}

No pierdas el impulso en tus estudios. ¡Renueva hoy y mantente en camino al éxito!

Saludos cordiales,
El Equipo de License Prep`
    },
    uk: {
        subject: "Ваша підписка закінчилася - Поновіть для продовження",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Ваша Підписка Закінчилася</h1>
          </div>
          <div class="content">
            <p>Привіт {{userName}},</p>
            <p>Ваша підписка на наш додаток для підготовки до іспитів закінчилася. Ваш доступ до преміум функцій тепер обмежений.</p>
            <p>Щоб відновити повний доступ та продовжити підготовку до іспиту, будь ласка, поновіть вашу підписку:</p>
            <ul>
              <li>📚 Продовжуйте доступ до всіх практичних питань</li>
              <li>📊 Зберігайте ваш прогрес та статистику</li>
              <li>🎯 Отримуйте детальні пояснення для кожної відповіді</li>
              <li>📱 Користуйтесь офлайн доступом</li>
              <li>🔄 Отримуйте останні оновлення питань</li>
            </ul>
            <a href="{{renewUrl}}" class="cta">Поновити Підписку</a>
            <p>Не втрачайте темп у ваших заняттях. Поновіть сьогодні та залишайтесь на шляху до успіху!</p>
            <p>З найкращими побажаннями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Цей email було надіслано, оскільки ваша підписка закінчилась. Якщо у вас є питання щодо оплати або поновлення, зверніться до служби підтримки.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привіт {{userName}},

Ваша підписка на наш додаток для підготовки до іспитів закінчилася. Ваш доступ до преміум функцій тепер обмежений.

Щоб відновити повний доступ та продовжити підготовку до іспиту, будь ласка, поновіть вашу підписку.

Переваги, які ви поверніте:
- Продовжуйте доступ до всіх практичних питань
- Зберігайте ваш прогрес та статистику
- Отримуйте детальні пояснення для кожної відповіді
- Користуйтесь офлайн доступом
- Отримуйте останні оновлення питань

Поновити Підписку: {{renewUrl}}

Не втрачайте темп у ваших заняттях. Поновіть сьогодні та залишайтесь на шляху до успіху!

З найкращими побажаннями,
Команда License Prep`
    },
    ru: {
        subject: "Ваша подписка истекла - Продлите для продолжения",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Ваша Подписка Истекла</h1>
          </div>
          <div class="content">
            <p>Привет {{userName}},</p>
            <p>Ваша подписка на наше приложение для подготовки к экзаменам истекла. Ваш доступ к премиум функциям теперь ограничен.</p>
            <p>Чтобы восстановить полный доступ и продолжить подготовку к экзамену, пожалуйста, продлите вашу подписку:</p>
            <ul>
              <li>📚 Продолжайте доступ ко всем практическим вопросам</li>
              <li>📊 Сохраняйте ваш прогресс и статистику</li>
              <li>🎯 Получайте подробные объяснения для каждого ответа</li>
              <li>📱 Пользуйтесь офлайн доступом</li>
              <li>🔄 Получайте последние обновления вопросов</li>
            </ul>
            <a href="{{renewUrl}}" class="cta">Продлить Подписку</a>
            <p>Не теряйте темп в ваших занятиях. Продлите сегодня и оставайтесь на пути к успеху!</p>
            <p>С наилучшими пожеланиями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Этот email был отправлен, поскольку ваша подписка истекла. Если у вас есть вопросы о платеже или продлении, свяжитесь с поддержкой.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привет {{userName}},

Ваша подписка на наше приложение для подготовки к экзаменам истекла. Ваш доступ к премиум функциям теперь ограничен.

Чтобы восстановить полный доступ и продолжить подготовку к экзамену, пожалуйста, продлите вашу подписку.

Преимущества, которые вы вернете:
- Продолжайте доступ ко всем практическим вопросам
- Сохраняйте ваш прогресс и статистику
- Получайте подробные объяснения для каждого ответа
- Пользуйтесь офлайн доступом
- Получайте последние обновления вопросов

Продлить Подписку: {{renewUrl}}

Не теряйте темп в ваших занятиях. Продлите сегодня и оставайтесь на пути к успеху!

С наилучшими пожеланиями,
Команда License Prep`
    },
    pl: {
        subject: "Twoja subskrypcja wygasła - Odnów aby kontynuować",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Twoja Subskrypcja Wygasła</h1>
          </div>
          <div class="content">
            <p>Cześć {{userName}},</p>
            <p>Twoja subskrypcja naszej aplikacji do przygotowań do egzaminów wygasła. Twój dostęp do funkcji premium jest teraz ograniczony.</p>
            <p>Aby przywrócić pełny dostęp i kontynuować przygotowania do egzaminu, proszę odnów swoją subskrypcję:</p>
            <ul>
              <li>📚 Kontynuuj dostęp do wszystkich pytań praktycznych</li>
              <li>📊 Zachowaj swoje postępy i statystyki</li>
              <li>🎯 Otrzymuj szczegółowe wyjaśnienia dla każdej odpowiedzi</li>
              <li>📱 Korzystaj z dostępu offline</li>
              <li>🔄 Otrzymuj najnowsze aktualizacje pytań</li>
            </ul>
            <a href="{{renewUrl}}" class="cta">Odnów Subskrypcję</a>
            <p>Nie trać tempa w nauce. Odnów dziś i pozostań na drodze do sukcesu!</p>
            <p>Z najlepszymi życzeniami,<br>Zespół License Prep</p>
          </div>
          <div class="footer">
            <p>Ten email został wysłany, ponieważ Twoja subskrypcja wygasła. Jeśli masz pytania dotyczące płatności lub odnowienia, skontaktuj się z pomocą techniczną.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Cześć {{userName}},

Twoja subskrypcja naszej aplikacji do przygotowań do egzaminów wygasła. Twój dostęp do funkcji premium jest teraz ograniczony.

Aby przywrócić pełny dostęp i kontynuować przygotowania do egzaminu, proszę odnów swoją subskrypcję.

Korzyści, które odzyskasz:
- Kontynuuj dostęp do wszystkich pytań praktycznych
- Zachowaj swoje postępy i statystyki
- Otrzymuj szczegółowe wyjaśnienia dla każdej odpowiedzi
- Korzystaj z dostępu offline
- Otrzymuj najnowsze aktualizacje pytań

Odnów Subskrypcję: {{renewUrl}}

Nie trać tempa w nauce. Odnów dziś i pozostań na drodze do sukcesu!

Z najlepszymi życzeniami,
Zespół License Prep`
    }
};
/**
 * Subscription renewal success email templates
 */
exports.RENEWAL_SUCCESS_TEMPLATES = {
    en: {
        subject: "Your subscription has been renewed successfully",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #28a745; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Subscription Renewed Successfully!</h1>
          </div>
          <div class="content">
            <p>Hello {{userName}},</p>
            <p>Great news! Your subscription has been renewed successfully. You can continue enjoying all premium features without interruption.</p>
            <p>Your subscription includes:</p>
            <ul>
              <li>✅ Unlimited access to all practice questions</li>
              <li>✅ Detailed explanations and rule references</li>
              <li>✅ Progress tracking and performance analytics</li>
              <li>✅ Offline access to all content</li>
              <li>✅ Regular updates with new questions</li>
            </ul>
            <p>Your next renewal date will be shown in the app. Thank you for continuing your learning journey with us!</p>
            <a href="{{appUrl}}" class="cta">Continue Learning</a>
            <p>Best regards,<br>The License Prep Team</p>
          </div>
          <div class="footer">
            <p>This email was sent to confirm your subscription renewal. For billing questions, please contact our support team.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hello {{userName}},

Great news! Your subscription has been renewed successfully. You can continue enjoying all premium features without interruption.

Your subscription includes:
- Unlimited access to all practice questions
- Detailed explanations and rule references
- Progress tracking and performance analytics
- Offline access to all content
- Regular updates with new questions

Your next renewal date will be shown in the app. Thank you for continuing your learning journey with us!

Continue Learning: {{appUrl}}

Best regards,
The License Prep Team`
    },
    es: {
        subject: "Tu suscripción se ha renovado exitosamente",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #28a745; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>¡Suscripción Renovada Exitosamente!</h1>
          </div>
          <div class="content">
            <p>Hola {{userName}},</p>
            <p>¡Buenas noticias! Tu suscripción se ha renovado exitosamente. Puedes continuar disfrutando de todas las características premium sin interrupciones.</p>
            <p>Tu suscripción incluye:</p>
            <ul>
              <li>✅ Acceso ilimitado a todas las preguntas de práctica</li>
              <li>✅ Explicaciones detalladas y referencias de reglas</li>
              <li>✅ Seguimiento de progreso y análisis de rendimiento</li>
              <li>✅ Acceso sin conexión a todo el contenido</li>
              <li>✅ Actualizaciones regulares con nuevas preguntas</li>
            </ul>
            <p>Tu próxima fecha de renovación se mostrará en la aplicación. ¡Gracias por continuar tu viaje de aprendizaje con nosotros!</p>
            <a href="{{appUrl}}" class="cta">Continuar Aprendiendo</a>
            <p>Saludos cordiales,<br>El Equipo de License Prep</p>
          </div>
          <div class="footer">
            <p>Este correo fue enviado para confirmar la renovación de tu suscripción. Para preguntas de facturación, contacta a nuestro equipo de soporte.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hola {{userName}},

¡Buenas noticias! Tu suscripción se ha renovado exitosamente. Puedes continuar disfrutando de todas las características premium sin interrupciones.

Tu suscripción incluye:
- Acceso ilimitado a todas las preguntas de práctica
- Explicaciones detalladas y referencias de reglas
- Seguimiento de progreso y análisis de rendimiento
- Acceso sin conexión a todo el contenido
- Actualizaciones regulares con nuevas preguntas

Tu próxima fecha de renovación se mostrará en la aplicación. ¡Gracias por continuar tu viaje de aprendizaje con nosotros!

Continuar Aprendiendo: {{appUrl}}

Saludos cordiales,
El Equipo de License Prep`
    },
    uk: {
        subject: "Вашу підписку успішно поновлено",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #28a745; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Підписку Успішно Поновлено!</h1>
          </div>
          <div class="content">
            <p>Привіт {{userName}},</p>
            <p>Чудові новини! Вашу підписку успішно поновлено. Ви можете продовжувати користуватися всіма преміум функціями без перерв.</p>
            <p>Ваша підписка включає:</p>
            <ul>
              <li>✅ Необмежений доступ до всіх практичних питань</li>
              <li>✅ Детальні пояснення та посилання на правила</li>
              <li>✅ Відстеження прогресу та аналіз продуктивності</li>
              <li>✅ Офлайн доступ до всього контенту</li>
              <li>✅ Регулярні оновлення з новими питаннями</li>
            </ul>
            <p>Дата вашого наступного поновлення буде показана в додатку. Дякуємо за продовження вашого навчального шляху з нами!</p>
            <a href="{{appUrl}}" class="cta">Продовжити Навчання</a>
            <p>З найкращими побажаннями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Цей email було надіслано для підтвердження поновлення вашої підписки. З питань про оплату звертайтесь до нашої служби підтримки.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привіт {{userName}},

Чудові новини! Вашу підписку успішно поновлено. Ви можете продовжувати користуватися всіма преміум функціями без перерв.

Ваша підписка включає:
- Необмежений доступ до всіх практичних питань
- Детальні пояснення та посилання на правила
- Відстеження прогресу та аналіз продуктивності
- Офлайн доступ до всього контенту
- Регулярні оновлення з новими питаннями

Дата вашого наступного поновлення буде показана в додатку. Дякуємо за продовження вашого навчального шляху з нами!

Продовжити Навчання: {{appUrl}}

З найкращими побажаннями,
Команда License Prep`
    },
    ru: {
        subject: "Ваша подписка успешно продлена",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #28a745; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Подписка Успешно Продлена!</h1>
          </div>
          <div class="content">
            <p>Привет {{userName}},</p>
            <p>Отличные новости! Ваша подписка успешно продлена. Вы можете продолжать пользоваться всеми премиум функциями без перерывов.</p>
            <p>Ваша подписка включает:</p>
            <ul>
              <li>✅ Неограниченный доступ ко всем практическим вопросам</li>
              <li>✅ Подробные объяснения и ссылки на правила</li>
              <li>✅ Отслеживание прогресса и анализ производительности</li>
              <li>✅ Офлайн доступ ко всему контенту</li>
              <li>✅ Регулярные обновления с новыми вопросами</li>
            </ul>
            <p>Дата вашего следующего продления будет показана в приложении. Спасибо за продолжение вашего учебного пути с нами!</p>
            <a href="{{appUrl}}" class="cta">Продолжить Обучение</a>
            <p>С наилучшими пожеланиями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Этот email был отправлен для подтверждения продления вашей подписки. По вопросам оплаты обращайтесь в нашу службу поддержки.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привет {{userName}},

Отличные новости! Ваша подписка успешно продлена. Вы можете продолжать пользоваться всеми премиум функциями без перерывов.

Ваша подписка включает:
- Неограниченный доступ ко всем практическим вопросам
- Подробные объяснения и ссылки на правила
- Отслеживание прогресса и анализ производительности
- Офлайн доступ ко всему контенту
- Регулярные обновления с новыми вопросами

Дата вашего следующего продления будет показана в приложении. Спасибо за продолжение вашего учебного пути с нами!

Продолжить Обучение: {{appUrl}}

С наилучшими пожеланиями,
Команда License Prep`
    },
    pl: {
        subject: "Twoja subskrypcja została pomyślnie odnowiona",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #28a745; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Subskrypcja Pomyślnie Odnowiona!</h1>
          </div>
          <div class="content">
            <p>Cześć {{userName}},</p>
            <p>Świetne wiadomości! Twoja subskrypcja została pomyślnie odnowiona. Możesz dalej korzystać ze wszystkich funkcji premium bez przerw.</p>
            <p>Twoja subskrypcja obejmuje:</p>
            <ul>
              <li>✅ Nieograniczony dostęp do wszystkich pytań praktycznych</li>
              <li>✅ Szczegółowe wyjaśnienia i odnośniki do przepisów</li>
              <li>✅ Śledzenie postępów i analizę wydajności</li>
              <li>✅ Dostęp offline do całej zawartości</li>
              <li>✅ Regularne aktualizacje z nowymi pytaniami</li>
            </ul>
            <p>Data Twojego następnego odnowienia będzie pokazana w aplikacji. Dziękujemy za kontynuowanie Twojej nauki z nami!</p>
            <a href="{{appUrl}}" class="cta">Kontynuuj Naukę</a>
            <p>Z najlepszymi życzeniami,<br>Zespół License Prep</p>
          </div>
          <div class="footer">
            <p>Ten email został wysłany w celu potwierdzenia odnowienia Twojej subskrypcji. W przypadku pytań dotyczących rozliczeń skontaktuj się z naszym zespołem wsparcia.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Cześć {{userName}},

Świetne wiadomości! Twoja subskrypcja została pomyślnie odnowiona. Możesz dalej korzystać ze wszystkich funkcji premium bez przerw.

Twoja subskrypcja obejmuje:
- Nieograniczony dostęp do wszystkich pytań praktycznych
- Szczegółowe wyjaśnienia i odnośniki do przepisów
- Śledzenie postępów i analizę wydajności
- Dostęp offline do całej zawartości
- Regularne aktualizacje z nowymi pytaniami

Data Twojego następnego odnowienia będzie pokazana w aplikacji. Dziękujemy za kontynuowanie Twojej nauki z nami!

Kontynuuj Naukę: {{appUrl}}

Z najlepszymi życzeniami,
Zespół License Prep`
    }
};
/**
 * Subscription renewal failure email templates
 */
exports.RENEWAL_FAILURE_TEMPLATES = {
    en: {
        subject: "Action required: Subscription renewal failed",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #ffc107; color: #212529; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; font-weight: bold; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Action Required: Renewal Failed</h1>
          </div>
          <div class="content">
            <p>Hello {{userName}},</p>
            <p>We were unable to renew your subscription due to a payment issue. Your access to premium features will expire soon if not resolved.</p>
            <p><strong>What happened?</strong></p>
            <p>Your payment method may have expired, insufficient funds, or there was a temporary issue with the payment processor.</p>
            <p><strong>What you need to do:</strong></p>
            <ul>
              <li>🔄 Update your payment method in the app</li>
              <li>💳 Ensure your card has sufficient funds</li>
              <li>📱 Check your app store account settings</li>
              <li>🔁 Try the renewal process again</li>
            </ul>
            <p>Your subscription is still active for now, but will expire soon without action.</p>
            <a href="{{updatePaymentUrl}}" class="cta">Update Payment Method</a>
            <p>Need help? Contact our support team - we're here to assist you!</p>
            <p>Best regards,<br>The License Prep Team</p>
          </div>
          <div class="footer">
            <p>This email was sent because your subscription renewal failed. Please take action to avoid service interruption.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hello {{userName}},

We were unable to renew your subscription due to a payment issue. Your access to premium features will expire soon if not resolved.

What happened?
Your payment method may have expired, insufficient funds, or there was a temporary issue with the payment processor.

What you need to do:
- Update your payment method in the app
- Ensure your card has sufficient funds
- Check your app store account settings
- Try the renewal process again

Your subscription is still active for now, but will expire soon without action.

Update Payment Method: {{updatePaymentUrl}}

Need help? Contact our support team - we're here to assist you!

Best regards,
The License Prep Team`
    },
    es: {
        subject: "Acción requerida: Falló la renovación de suscripción",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #ffc107; color: #212529; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; font-weight: bold; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Acción Requerida: Falló la Renovación</h1>
          </div>
          <div class="content">
            <p>Hola {{userName}},</p>
            <p>No pudimos renovar tu suscripción debido a un problema de pago. Tu acceso a las características premium expirará pronto si no se resuelve.</p>
            <p><strong>¿Qué pasó?</strong></p>
            <p>Tu método de pago puede haber expirado, fondos insuficientes, o hubo un problema temporal con el procesador de pagos.</p>
            <p><strong>Lo que necesitas hacer:</strong></p>
            <ul>
              <li>🔄 Actualiza tu método de pago en la app</li>
              <li>💳 Asegúrate de que tu tarjeta tenga fondos suficientes</li>
              <li>📱 Revisa la configuración de tu cuenta de app store</li>
              <li>🔁 Intenta el proceso de renovación nuevamente</li>
            </ul>
            <p>Tu suscripción aún está activa por ahora, pero expirará pronto sin acción.</p>
            <a href="{{updatePaymentUrl}}" class="cta">Actualizar Método de Pago</a>
            <p>¿Necesitas ayuda? Contacta a nuestro equipo de soporte - ¡estamos aquí para asistirte!</p>
            <p>Saludos cordiales,<br>El Equipo de License Prep</p>
          </div>
          <div class="footer">
            <p>Este correo fue enviado porque falló la renovación de tu suscripción. Por favor toma acción para evitar interrupción del servicio.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Hola {{userName}},

No pudimos renovar tu suscripción debido a un problema de pago. Tu acceso a las características premium expirará pronto si no se resuelve.

¿Qué pasó?
Tu método de pago puede haber expirado, fondos insuficientes, o hubo un problema temporal con el procesador de pagos.

Lo que necesitas hacer:
- Actualiza tu método de pago en la app
- Asegúrate de que tu tarjeta tenga fondos suficientes
- Revisa la configuración de tu cuenta de app store
- Intenta el proceso de renovación nuevamente

Tu suscripción aún está activa por ahora, pero expirará pronto sin acción.

Actualizar Método de Pago: {{updatePaymentUrl}}

¿Necesitas ayuda? Contacta a nuestro equipo de soporte - ¡estamos aquí para asistirte!

Saludos cordiales,
El Equipo de License Prep`
    },
    uk: {
        subject: "Потрібні дії: Не вдалося поновити підписку",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #ffc107; color: #212529; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; font-weight: bold; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Потрібні Дії: Не Вдалося Поновити</h1>
          </div>
          <div class="content">
            <p>Привіт {{userName}},</p>
            <p>Нам не вдалося поновити вашу підписку через проблеми з оплатою. Ваш доступ до преміум функцій скоро закінчиться, якщо це не буде вирішено.</p>
            <p><strong>Що сталося?</strong></p>
            <p>Ваш спосіб оплати міг закінчитися, недостатньо коштів, або була тимчасова проблема з обробником платежів.</p>
            <p><strong>Що вам потрібно зробити:</strong></p>
            <ul>
              <li>🔄 Оновіть ваш спосіб оплати в додатку</li>
              <li>💳 Переконайтесь, що на вашій картці достатньо коштів</li>
              <li>📱 Перевірте налаштування вашого акаунту в app store</li>
              <li>🔁 Спробуйте процес поновлення знову</li>
            </ul>
            <p>Ваша підписка поки що активна, але скоро закінчиться без дій.</p>
            <a href="{{updatePaymentUrl}}" class="cta">Оновити Спосіб Оплати</a>
            <p>Потрібна допомога? Зв'яжіться з нашою службою підтримки - ми тут, щоб допомогти!</p>
            <p>З найкращими побажаннями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Цей email було надіслано, оскільки не вдалося поновити вашу підписку. Будь ласка, вживіть заходів, щоб уникнути переривання сервісу.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привіт {{userName}},

Нам не вдалося поновити вашу підписку через проблеми з оплатою. Ваш доступ до преміум функцій скоро закінчиться, якщо це не буде вирішено.

Що сталося?
Ваш спосіб оплати міг закінчитися, недостатньо коштів, або була тимчасова проблема з обробником платежів.

Що вам потрібно зробити:
- Оновіть ваш спосіб оплати в додатку
- Переконайтесь, що на вашій картці достатньо коштів
- Перевірте налаштування вашого акаунту в app store
- Спробуйте процес поновлення знову

Ваша підписка поки що активна, але скоро закінчиться без дій.

Оновити Спосіб Оплати: {{updatePaymentUrl}}

Потрібна допомога? Зв'яжіться з нашою службою підтримки - ми тут, щоб допомогти!

З найкращими побажаннями,
Команда License Prep`
    },
    ru: {
        subject: "Требуется действие: Не удалось продлить подписку",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #ffc107; color: #212529; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; font-weight: bold; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Требуется Действие: Не Удалось Продлить</h1>
          </div>
          <div class="content">
            <p>Привет {{userName}},</p>
            <p>Нам не удалось продлить вашу подписку из-за проблем с оплатой. Ваш доступ к премиум функциям скоро истечет, если это не будет решено.</p>
            <p><strong>Что произошло?</strong></p>
            <p>Ваш способ оплаты мог истечь, недостаточно средств, или была временная проблема с обработчиком платежей.</p>
            <p><strong>Что вам нужно сделать:</strong></p>
            <ul>
              <li>🔄 Обновите ваш способ оплаты в приложении</li>
              <li>💳 Убедитесь, что на вашей карте достаточно средств</li>
              <li>📱 Проверьте настройки вашего аккаунта в app store</li>
              <li>🔁 Попробуйте процесс продления снова</li>
            </ul>
            <p>Ваша подписка пока активна, но скоро истечет без действий.</p>
            <a href="{{updatePaymentUrl}}" class="cta">Обновить Способ Оплаты</a>
            <p>Нужна помощь? Свяжитесь с нашей службой поддержки - мы здесь, чтобы помочь!</p>
            <p>С наилучшими пожеланиями,<br>Команда License Prep</p>
          </div>
          <div class="footer">
            <p>Этот email был отправлен, поскольку не удалось продлить вашу подписку. Пожалуйста, примите меры, чтобы избежать прерывания сервиса.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Привет {{userName}},

Нам не удалось продлить вашу подписку из-за проблем с оплатой. Ваш доступ к премиум функциям скоро истечет, если это не будет решено.

Что произошло?
Ваш способ оплаты мог истечь, недостаточно средств, или была временная проблема с обработчиком платежей.

Что вам нужно сделать:
- Обновите ваш способ оплаты в приложении
- Убедитесь, что на вашей карте достаточно средств
- Проверьте настройки вашего аккаунта в app store
- Попробуйте процесс продления снова

Ваша подписка пока активна, но скоро истечет без действий.

Обновить Способ Оплаты: {{updatePaymentUrl}}

Нужна помощь? Свяжитесь с нашей службой поддержки - мы здесь, чтобы помочь!

С наилучшими пожеланиями,
Команда License Prep`
    },
    pl: {
        subject: "Wymagane działanie: Odnowienie subskrypcji nie powiodło się",
        html: `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: #dc3545; color: white; padding: 20px; text-align: center; }
          .content { padding: 20px; }
          .cta { background: #ffc107; color: #212529; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; margin: 20px 0; font-weight: bold; }
          .footer { font-size: 12px; color: #666; text-align: center; margin-top: 30px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Wymagane Działanie: Odnowienie Nie Powiodło Się</h1>
          </div>
          <div class="content">
            <p>Cześć {{userName}},</p>
            <p>Nie mogliśmy odnowić Twojej subskrypcji z powodu problemu z płatnością. Twój dostęp do funkcji premium wkrótce wygaśnie, jeśli nie zostanie rozwiązany.</p>
            <p><strong>Co się stało?</strong></p>
            <p>Twoja metoda płatności mogła wygasnąć, niewystarczające środki, lub był tymczasowy problem z procesorem płatności.</p>
            <p><strong>Co musisz zrobić:</strong></p>
            <ul>
              <li>🔄 Zaktualizuj swoją metodę płatności w aplikacji</li>
              <li>💳 Upewnij się, że Twoja karta ma wystarczające środki</li>
              <li>📱 Sprawdź ustawienia swojego konta w app store</li>
              <li>🔁 Spróbuj ponownie procesu odnowienia</li>
            </ul>
            <p>Twoja subskrypcja jest nadal aktywna na razie, ale wkrótce wygaśnie bez działania.</p>
            <a href="{{updatePaymentUrl}}" class="cta">Zaktualizuj Metodę Płatności</a>
            <p>Potrzebujesz pomocy? Skontaktuj się z naszym zespołem wsparcia - jesteśmy tutaj, aby pomóc!</p>
            <p>Z najlepszymi życzeniami,<br>Zespół License Prep</p>
          </div>
          <div class="footer">
            <p>Ten email został wysłany, ponieważ odnowienie Twojej subskrypcji nie powiodło się. Proszę podjąć działania, aby uniknąć przerwy w usłudze.</p>
          </div>
        </div>
      </body>
      </html>
    `,
        text: `Cześć {{userName}},

Nie mogliśmy odnowić Twojej subskrypcji z powodu problemu z płatnością. Twój dostęp do funkcji premium wkrótce wygaśnie, jeśli nie zostanie rozwiązany.

Co się stało?
Twoja metoda płatności mogła wygasnąć, niewystarczające środki, lub był tymczasowy problem z procesorem płatności.

Co musisz zrobić:
- Zaktualizuj swoją metodę płatności w aplikacji
- Upewnij się, że Twoja karta ma wystarczające środki
- Sprawdź ustawienia swojego konta w app store
- Spróbuj ponownie procesu odnowienia

Twoja subskrypcja jest nadal aktywna na razie, ale wkrótce wygaśnie bez działania.

Zaktualizuj Metodę Płatności: {{updatePaymentUrl}}

Potrzebujesz pomocy? Skontaktuj się z naszym zespołem wsparcia - jesteśmy tutaj, aby pomóc!

Z najlepszymi życzeniami,
Zespół License Prep`
    }
};
/**
 * Get email template for trial expired notification
 */
function getTrialExpiredTemplate(language) {
    const lang = language;
    return exports.TRIAL_EXPIRED_TEMPLATES[lang] || exports.TRIAL_EXPIRED_TEMPLATES.en;
}
exports.getTrialExpiredTemplate = getTrialExpiredTemplate;
/**
 * Get email template for subscription expired notification
 */
function getSubscriptionExpiredTemplate(language) {
    const lang = language;
    return exports.SUBSCRIPTION_EXPIRED_TEMPLATES[lang] || exports.SUBSCRIPTION_EXPIRED_TEMPLATES.en;
}
exports.getSubscriptionExpiredTemplate = getSubscriptionExpiredTemplate;
/**
 * Get email template for renewal success notification
 */
function getRenewalSuccessTemplate(language) {
    const lang = language;
    return exports.RENEWAL_SUCCESS_TEMPLATES[lang] || exports.RENEWAL_SUCCESS_TEMPLATES.en;
}
exports.getRenewalSuccessTemplate = getRenewalSuccessTemplate;
/**
 * Get email template for renewal failure notification
 */
function getRenewalFailureTemplate(language) {
    const lang = language;
    return exports.RENEWAL_FAILURE_TEMPLATES[lang] || exports.RENEWAL_FAILURE_TEMPLATES.en;
}
exports.getRenewalFailureTemplate = getRenewalFailureTemplate;
/**
 * Replace template variables in email content
 */
function replaceTemplateVariables(template, variables) {
    let html = template.html;
    let text = template.text;
    let subject = template.subject;
    // Replace all {{variableName}} with actual values
    for (const [key, value] of Object.entries(variables)) {
        const placeholder = `{{${key}}}`;
        html = html.replace(new RegExp(placeholder, 'g'), value);
        text = text.replace(new RegExp(placeholder, 'g'), value);
        subject = subject.replace(new RegExp(placeholder, 'g'), value);
    }
    return { html, text, subject };
}
exports.replaceTemplateVariables = replaceTemplateVariables;
//# sourceMappingURL=email-templates.js.map