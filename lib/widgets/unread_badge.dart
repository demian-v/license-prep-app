import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The unread count (instructors plan v2 §14.1): a small `stop`-red pill with
/// white tabular figures, «9+» past nine, ringed in white so it reads on a
/// tab icon or a pill. `stop` is already the saved-heart red, so a count dot
/// is within its use. Nothing is drawn for zero.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, this.ring = true});

  final int count;

  /// The white ring, for a badge sitting on top of an icon.
  final bool ring;

  static String label(int count) => count > 9 ? '9+' : '$count';

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.stop,
        borderRadius: BorderRadius.circular(9),
        border: ring ? Border.all(color: AppColors.paper, width: 1.5) : null,
      ),
      child: Text(
        label(count),
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          height: 1,
          color: AppColors.onSignal,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontVariations: const [FontVariation('wght', 700)],
        ),
      ),
    );
  }
}
