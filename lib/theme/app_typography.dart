import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Six steps replace the twelve ad-hoc `fontSize` values the app accumulated
/// (10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 36, 40 — several used once).
///
/// **Family: Rubik.** Chosen from five Cyrillic-complete candidates: its
/// slightly rounded strokes are the typographic twin of the Solar icons and
/// the soft Bento cards. The obvious designer picks for a redesign (Satoshi,
/// Clash Display) are Latin-only, and this app ships Russian and Ukrainian
/// (`Подготовка к лицензии`, `Підготовка до ліцензії`) plus Polish diacritics.
/// Rubik was checked against every character in all five locale files; the
/// one gap is `→`, used in a single error message, which the platform fills.
///
/// Weight comes from the variable `wght` axis (300-900) via [FontVariation],
/// not from [FontWeight], so every weight is a real instance of the typeface
/// rather than a synthesised one.
class AppTypography {
  const AppTypography._();

  static const String family = 'Rubik';

  static const double _regular = 400;
  static const double _medium = 500;
  static const double _semibold = 600;
  static const double _bold = 700;

  static List<FontVariation> _w(double weight) => [FontVariation('wght', weight)];

  /// Digits that do not jitter as they change — the exam countdown ticks once a
  /// second for an hour, and proportional figures make it twitch sideways.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _base({
    required double size,
    required double height,
    required double weight,
    double tracking = 0,
    Color color = AppColors.ink,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: height / size,
        letterSpacing: tracking,
        color: color,
        fontVariations: _w(weight),
        fontFeatures: tabular ? _tabular : null,
      );

  // Large type gets negative tracking; small type gets a little positive, which
  // is what keeps 12px labels legible in Cyrillic.

  /// Screen hero — a score, a price, the countdown.
  static TextStyle get display =>
      _base(size: 32, height: 38, weight: _bold, tracking: -0.6);

  /// Screen titles.
  static TextStyle get title =>
      _base(size: 24, height: 30, weight: _bold, tracking: -0.4);

  /// Card titles and question text.
  static TextStyle get heading =>
      _base(size: 20, height: 26, weight: _semibold, tracking: -0.2);

  /// Answer options, paragraphs.
  static TextStyle get body => _base(size: 16, height: 24, weight: _regular);

  /// Buttons, chips, metadata.
  static TextStyle get label => _base(size: 14, height: 20, weight: _medium);

  /// Counters, footnotes.
  static TextStyle get caption => _base(
        size: 12,
        height: 16,
        weight: _medium,
        tracking: 0.1,
        color: AppColors.inkSecondary,
      );

  /// The countdown. Tabular, tight, and large enough to read at a glance on a
  /// timed test — it was a 12px grey pill before.
  static TextStyle get timer => _base(
        size: 22,
        height: 26,
        weight: _bold,
        tracking: 0.5,
        tabular: true,
      );

  /// Numerals inside the question pills.
  static TextStyle get pill =>
      _base(size: 14, height: 18, weight: _semibold, tabular: true);

  static TextTheme get textTheme => TextTheme(
        displayLarge: display,
        displayMedium: display,
        displaySmall: title,
        headlineLarge: title,
        headlineMedium: heading,
        headlineSmall: heading,
        titleLarge: heading,
        titleMedium: body.copyWith(fontVariations: _w(_semibold)),
        titleSmall: label,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: label,
        labelMedium: label,
        labelSmall: caption,
      );
}
