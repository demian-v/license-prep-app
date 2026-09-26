import 'package:flutter/material.dart';

/// The palette.
///
/// One rule governs this file, borrowed from the subject the app teaches:
/// **on a road sign, colour is never decoration.** Green guides, red prohibits,
/// amber warns, blue informs. Every hue is load-bearing.
///
/// The app previously broke that rule — six decorative pastel washes cycled by
/// index across cards and answer options, which meant green was decorating an
/// arbitrary answer one tap before it had to mean "correct". Nothing here is
/// available for decoration. Hierarchy comes from size, weight and space.
///
/// See wiki/driveusa/Development/design system/design-tokens.md
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------- brand ---

  /// The logo blue, sampled from assets/images/logo/logo.png.
  ///
  /// The app shipped for its whole life using Flutter's stock `Colors.blue`
  /// (#2196F3) instead — lighter and cyan-leaning, and not the brand.
  static const Color signal = Color(0xFF0048C3);

  static const Color signal50 = Color(0xFFEBF1FE);
  static const Color signal100 = Color(0xFFD6E3FD);
  static const Color signal200 = Color(0xFFADC7FB);
  static const Color signal300 = Color(0xFF7AA3F8);
  static const Color signal400 = Color(0xFF3D79F0);
  static const Color signal600 = Color(0xFF003FAB);
  static const Color signal700 = Color(0xFF00338C);

  // ------------------------------------------------------------- surfaces ---

  /// Card and sheet surfaces.
  static const Color paper = Color(0xFFFFFFFF);

  /// Scaffold background. One cool grey family throughout — never mixed warm.
  static const Color field = Color(0xFFF2F4F8);

  /// Hairlines and card edges. Carries structure so tint doesn't have to.
  static const Color border = Color(0xFFE3E7EF);

  /// A stronger edge for the resting state of an interactive surface.
  static const Color borderStrong = Color(0xFFD3D9E6);

  // ----------------------------------------------------------------- text ---

  static const Color ink = Color(0xFF0E1422);
  static const Color inkSecondary = Color(0xFF5A6475);
  static const Color inkTertiary = Color(0xFF8A93A5);
  static const Color onSignal = Color(0xFFFFFFFF);

  // ------------------------------------------------------------- semantic ---
  // These four may appear ONLY when communicating correctness, risk or time
  // pressure. Never as a card background, never to distinguish one category
  // from another, never to make a screen look livelier.

  /// Answer correct. Nothing else.
  static const Color guide = Color(0xFF0F7A3D);
  static const Color guideSurface = Color(0xFFE7F6ED);

  /// Answer wrong, destructive action. Nothing else.
  static const Color stop = Color(0xFFC1272D);
  static const Color stopSurface = Color(0xFFFDECEC);

  /// Trial expiring, time running low. Nothing else.
  static const Color warn = Color(0xFFB26A00);
  static const Color warnSurface = Color(0xFFFFF4E5);

  // ---------------------------------------------------------------- depth ---

  /// Shadows carry the hue of the surface beneath them rather than generic
  /// black, so elevation reads as light falling on paper instead of grime.
  static List<BoxShadow> get shadowResting => const [
        BoxShadow(
          color: Color(0x0F0E1F4D),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0A0E1F4D),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ];

  /// For the one primary surface per screen that should sit above the rest.
  static List<BoxShadow> get shadowRaised => const [
        BoxShadow(
          color: Color(0x1F0048C3),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];

  /// The full scheme. Replaces `ColorScheme.light(secondary: Colors.green)`,
  /// which left every unspecified role to Material 3's default seed — a purple
  /// nobody chose that surfaced on focus rings, the paywall CTA and, via
  /// `surfaceTint`, the app bar of every scrolled screen.
  static ColorScheme get scheme => const ColorScheme(
        brightness: Brightness.light,
        primary: signal,
        onPrimary: onSignal,
        primaryContainer: signal50,
        onPrimaryContainer: signal700,
        secondary: signal400,
        onSecondary: onSignal,
        secondaryContainer: signal50,
        onSecondaryContainer: signal700,
        tertiary: guide,
        onTertiary: onSignal,
        tertiaryContainer: guideSurface,
        onTertiaryContainer: guide,
        error: stop,
        onError: onSignal,
        errorContainer: stopSurface,
        onErrorContainer: stop,
        surface: paper,
        onSurface: ink,
        onSurfaceVariant: inkSecondary,
        outline: borderStrong,
        outlineVariant: border,
        shadow: Color(0xFF0E1F4D),
        scrim: Color(0x800E1422),
        inverseSurface: ink,
        onInverseSurface: paper,
        inversePrimary: signal300,
        // Kills the elevation tint that turned scrolled app bars lavender.
        surfaceTint: Colors.transparent,
      );
}
