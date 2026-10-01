import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The faint bar strip every blue hero carries — the exam card's 40 question
/// bars (`EnhancedTestCard._questionBars`, frozen), larger and fainter, as on
/// the Профиль, Подписка and Поддержка heroes. Decoration only: place it in a
/// `Positioned(right: 20, bottom: 0)` inside the hero's clipped `Stack`.
class BentoHeroBars extends StatelessWidget {
  const BentoHeroBars({super.key});

  static const _heights = [
    10, 16, 12, 22, 14, 26, 18, 30, 20, 34, 24, 28, 38, 26, 42, 30, 36, 46,
    32, 40, 50, 36, 44, 54, 40, 48, 58, 44, 52, 60, 48, 56, 62, 52, 58, 64,
    56, 60, 66, 62,
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in _heights)
            Container(
              width: 3,
              height: h * 1.5,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: AppColors.onSignal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
        ],
      ),
    );
  }
}
