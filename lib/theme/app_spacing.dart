/// Spacing and radii, on a 4pt base.
///
/// Replaces arbitrary padding and 279 inline `BorderRadius` constructions.
class AppSpacing {
  const AppSpacing._();

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x12 = 48;

  /// Screen side gutter.
  static const double gutter = 16;

  /// Padding inside a card.
  static const double cardPadding = 16;

  /// Gap between sibling cards.
  static const double cardGap = 12;
}

/// Corner radii.
///
/// Varied by role rather than applied uniformly: inner elements are tighter
/// than the containers that hold them, which is what stops nested surfaces
/// reading as a stack of identical boxes.
class AppRadius {
  const AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;
}
