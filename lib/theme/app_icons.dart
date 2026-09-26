import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_colors.dart';

/// The icon set: Solar (480 Design), bundled as SVGs under `assets/icons/`.
///
/// Chosen from five candidate sets for its rounded, fuller shapes, which match
/// the soft cards of the Bento direction. It replaces Phosphor here and
/// Material's built-in glyphs everywhere else: screens that take `IconData`
/// use the same set through the `SolarIcons` font (lib/theme/solar_icons.dart).
///
/// Solar ships a matched Linear/Bold pair for every glyph, which is what
/// carries selected state: Bold when active, Linear when not.
///
/// Licence: Solar Icons, CC BY 4.0. Credit is given on the Support screen.
class AppIcons {
  const AppIcons._();

  static const String _base = 'assets/icons';

  // Tab bar — each has a fill counterpart.
  static const String tests = '$_base/clipboard-check-linear.svg';
  static const String testsFilled = '$_base/clipboard-check-bold.svg';
  static const String theory = '$_base/book-2-linear.svg';
  static const String theoryFilled = '$_base/book-2-bold.svg';
  static const String profile = '$_base/user-rounded-linear.svg';
  static const String profileFilled = '$_base/user-rounded-bold.svg';

  // Content.
  static const String practice = '$_base/layers-minimalistic-linear.svg';
  static const String chevron = '$_base/alt-arrow-right-linear.svg';
  static const String clock = '$_base/clock-circle-linear.svg';
  static const String close = '$_base/close-linear.svg';
  static const String check = '$_base/check-linear.svg';
  static const String zoom = '$_base/magnifier-zoom-in-linear.svg';

  /// Save a question, and the list of saved questions.
  ///
  /// A heart, not a bookmark. The app has always used `Icons.favorite` for this
  /// action, and the empty state tells people "tap the heart" — swapping the
  /// metaphor would break a learned affordance and make that copy wrong.
  static const String saved = '$_base/heart-linear.svg';
  static const String savedFilled = '$_base/heart-bold.svg';

  /// Report a problem with a question. Opens `ReportSheet`.
  static const String report = '$_base/danger-triangle-linear.svg';
  static const String reportFilled = '$_base/danger-triangle-bold.svg';

  /// Draws one icon at [size], tinted [color].
  ///
  /// Solar's SVGs paint with `currentColor`, so a [ColorFilter] recolours
  /// them without touching the asset.
  static Widget icon(
    String asset, {
    double size = 24,
    Color color = AppColors.ink,
    String? semanticLabel,
  }) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
