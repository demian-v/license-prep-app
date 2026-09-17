import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';

/// Context attached to Crashlytics reports, so a crash says *who* it happened
/// to and *what they were doing*, not just that something broke.
///
/// Crash reporting was added on 2026-09-17 and reports arrive with a stack
/// trace and nothing else. For this app the diagnosis is almost always in four
/// facts — state, language, subscription status and entitlement — because the
/// content path branches on all of them: a crash that only happens to a New
/// York user on Russian with an expired trial is a different bug from the same
/// stack trace on an entitled Illinois user.
///
/// Three kinds of signal, all funnelled through here so there is one place that
/// knows about Crashlytics besides `main.dart`:
///
/// - **Custom keys** — the four facts above, refreshed whenever they change.
///   Crashlytics keeps the last value set and attaches it to every later report.
/// - **Breadcrumb logs** — the last actions before the crash.
/// - **Non-fatal errors** — paths that are deliberately swallowed and would
///   otherwise be invisible, receipt validation above all.
///
/// **Every method swallows its own errors.** Diagnostics must never be the
/// reason a screen fails to build or a purchase fails to complete. A dropped
/// breadcrumb costs a slightly worse crash report; an exception thrown out of
/// here would cost the user their session.
///
/// **Nothing here reaches production from a debug build.** `main.dart` leaves
/// collection disabled outside release and profile, so these calls are
/// discarded locally — there is no Crashlytics emulator, and anything collected
/// would go to the real project.
class CrashReporter {
  CrashReporter({FirebaseCrashlytics? crashlytics}) : _crashlytics = crashlytics;

  final FirebaseCrashlytics? _crashlytics;

  FirebaseCrashlytics get _instance => _crashlytics ?? FirebaseCrashlytics.instance;

  /// Links a crash to an account so support can look someone up.
  ///
  /// Approved by the owner on 2026-09-17 as a deliberate decision, not just
  /// code: it places a stable user identifier into Google's diagnostics
  /// system. `privacy_policy.md` says so explicitly under Crash Diagnostics.
  ///
  /// Pass null on logout, which clears it — otherwise the next person to use
  /// the device inherits the previous account's identifier on their reports.
  Future<void> setUserIdentifier(String? uid) =>
      _guard(() => _instance.setUserIdentifier(uid ?? ''));

  /// The user's selected state (`IL`, `NY`), or null before they pick one.
  Future<void> setUserState(String? stateId) =>
      _setKey('state', stateId ?? 'none');

  /// The UI/content language code (`en`, `ru`, `es`, `pl`, `uk`).
  Future<void> setLanguage(String? language) =>
      _setKey('language', language ?? 'unknown');

  /// Subscription status and entitlement, which are **not** the same question
  /// and are worth keeping apart on a report.
  ///
  /// [status] is what the subscription document says (`trial`, `active`,
  /// `expired`, `canceled`, or `none` when there is no document at all).
  /// [entitled] is what the app decided that means for access — a canceled
  /// subscription inside its paid period is still entitled, and a trial past
  /// its end date is not. A crash where the two disagree is a different bug
  /// from one where they agree.
  Future<void> setSubscription({String? status, required bool entitled}) async {
    await _setKey('subscription_status', status ?? 'none');
    await _setKey('entitled', entitled.toString());
  }

  /// A breadcrumb. Crashlytics keeps the most recent of these and attaches
  /// them to the next report, giving the last actions before the crash.
  ///
  /// Must never carry a user id, an email or content — those are the exact
  /// values risk #34 stopped writing to release logs, and a crash report is
  /// not a more private place than a log.
  Future<void> log(String breadcrumb) => _guard(() => _instance.log(breadcrumb));

  /// Reports something the app caught and handled, so it is visible without
  /// needing a crash.
  ///
  /// This is the point of the whole file. The paths that matter here are the
  /// ones deliberately swallowed: a receipt validation that fails returns
  /// `false` and writes a `debugPrint` that release builds drop (#34), so a
  /// customer charged by Apple who receives nothing produces **no signal
  /// anywhere**. A non-fatal makes that visible.
  ///
  /// [reason] is a short stable slug — it is what the Crashlytics issue is
  /// grouped and searched by, so keep it constant across call sites for the
  /// same failure.
  Future<void> recordNonFatal(
    Object error,
    StackTrace? stack, {
    required String reason,
    Map<String, Object?> keys = const {},
  }) async {
    await _guard(() async {
      for (final entry in keys.entries) {
        await _instance.setCustomKey(entry.key, entry.value?.toString() ?? 'null');
      }
      await _instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: false,
      );
    });
  }

  Future<void> _setKey(String key, String value) =>
      _guard(() => _instance.setCustomKey(key, value));

  /// Crash reporting must never be the thing that breaks the app. Failures here
  /// are reported to the debug console and otherwise dropped.
  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      // Deliberately debugPrint and not rethrow: see the class comment.
      debugPrint('⚠️ CrashReporter: ignoring $e');
    }
  }
}

/// Matches the `analyticsService` idiom already used across `lib/services`.
final crashReporter = CrashReporter();

/// Records named-route navigation as Crashlytics breadcrumbs.
///
/// Installed in `MaterialApp.navigatorObservers`, so it covers every route in
/// `main.dart`'s `routes` map — login, signup, home, theory, tests, profile,
/// subscription and the password-reset funnel — without a call site in any of
/// them.
///
/// **It cannot see the other half.** About half this app's navigation uses
/// `MaterialPageRoute` with no `RouteSettings.name`, and a `Route` does not
/// expose the widget it will build, so there is nothing to name. Those
/// transitions — opening a theory module, starting a quiz, an exam or a
/// practice test — call `crashReporter.log` directly instead. Naming them here
/// would mean adding `settings:` to 30-odd routes, which changes what
/// `popUntil` and `ModalRoute.of(context)?.settings.name` see; a one-line log
/// at each is the cheaper, more honest change.
class CrashBreadcrumbObserver extends NavigatorObserver {
  CrashBreadcrumbObserver([CrashReporter? reporter])
      : _reporter = reporter ?? crashReporter;

  final CrashReporter _reporter;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _record('push', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _record('pop', route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _record('replace', newRoute);
  }

  void _record(String verb, Route<dynamic> route) {
    final name = route.settings.name;
    // Unnamed routes are the MaterialPageRoute half described above. A
    // breadcrumb reading "push null" is worse than no breadcrumb.
    if (name == null || name.isEmpty) return;
    _reporter.log('nav: $verb $name');
  }
}
