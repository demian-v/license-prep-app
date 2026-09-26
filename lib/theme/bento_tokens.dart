import 'package:flutter/animation.dart';

import 'app_motion.dart';
import 'app_spacing.dart';

/// Radius and motion roles for the Bento direction: large soft cards, every
/// control a pill. Every value resolves to an [AppRadius] or [AppMotion]
/// token — a role picks from the scale, never invents a number.
///
/// Bento was chosen on 2026-09-26 from four live variants (Refined, Signal,
/// Ledger, Bento); the other three were deleted once the choice was made.
abstract final class BentoTokens {
  /// Cards and option surfaces.
  static const double card = AppRadius.xl;

  /// Buttons.
  static const double button = AppRadius.pill;

  /// Chips, pills, keys.
  static const double chip = AppRadius.pill;

  /// Trays and bars, such as the exam's question strip.
  static const double bar = AppRadius.pill;

  /// Selection and press feedback.
  static const Duration state = AppMotion.fast;

  /// Correct/wrong verdict.
  static const Duration reveal = AppMotion.base;

  /// Question-to-question transition.
  static const Duration swap = AppMotion.base;

  static const Curve curve = AppMotion.enter;

  /// Bento cards lift rather than shrink under the finger — the touch
  /// version of a hover lift — so the press scale is 1.
  static const double pressScale = 1;
}
