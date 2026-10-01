import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

/// A tab's empty state as one white card: title first, then what will be
/// here. Placed at the top of the page, never centred (owner rule 9).
class BentoEmptyCard extends StatelessWidget {
  const BentoEmptyCard({super.key, required this.title, required this.description, this.icon});

  final String title;
  final String description;

  /// Beside the title, never alone on a row (owner rule 3).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: AppColors.signal),
                const SizedBox(width: AppSpacing.x2),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.heading.copyWith(
                    fontSize: 18,
                    height: 24 / 18,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(description, style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
        ],
      ),
    );
  }
}
