import 'dart:async';

import 'package:flutter/foundation.dart';

/// Risk #34 — roughly 1,839 `print` / `debugPrint` calls in `lib/`, of which
/// about 122 interpolate a user id, an email or a report id. Neither `print`
/// nor `debugPrint` is stripped from a Flutter release build, so all of that
/// reaches the device log, where any app with log access — and anyone with the
/// phone plugged into a laptop — can read it.
///
/// Rewriting 1,839 call sites would be a large, risky change for a problem
/// that has one structural answer: stop the output leaving the process in a
/// release build. Two mechanisms are needed, because they are different paths:
///
///   * `debugPrint` is a mutable top-level function, so it is replaced.
///   * `print` goes through the current [Zone], so the app is run inside a
///     zone whose print handler drops the line.
///
/// Debug and profile builds are untouched — local diagnosis keeps working
/// exactly as before, which is why the `avoid_print` lint is deliberately left
/// off: it would report 1,839 findings that this makes harmless.
///
/// [isRelease] is a parameter rather than a direct read of [kReleaseMode] so
/// both branches are testable; production callers pass [kReleaseMode].

/// The zone specification to run the app under, or null when logging should be
/// left alone.
ZoneSpecification? logSuppressionSpec({required bool isRelease}) {
  if (!isRelease) return null;
  return ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
      // Deliberately empty: the line is dropped, not forwarded.
    },
  );
}

/// Silences `debugPrint` in release builds. Safe to call more than once.
void silenceDebugPrintInRelease({required bool isRelease}) {
  if (!isRelease) return;
  debugPrint = (String? message, {int? wrapWidth}) {};
}

/// Runs [body] with release logging suppressed.
///
/// Wraps the whole of `main`, not just `runApp`, so the startup sequence is
/// covered too — several of the PII-bearing lines are logged before the first
/// frame.
R runWithReleaseLogging<R>(R Function() body, {required bool isRelease}) {
  silenceDebugPrintInRelease(isRelease: isRelease);
  return runZoned(body, zoneSpecification: logSuppressionSpec(isRelease: isRelease));
}
