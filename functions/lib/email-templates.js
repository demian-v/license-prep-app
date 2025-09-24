"use strict";
/**
 * Email templates for subscription notifications
 * Supports multiple languages: en, es, uk, ru, pl
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.replaceTemplateVariables = exports.getSubscriptionExpiredTemplate = exports.getTrialExpiredTemplate = exports.SUBSCRIPTION_EXPIRED_TEMPLATES = exports.TRIAL_EXPIRED_TEMPLATES = void 0;
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