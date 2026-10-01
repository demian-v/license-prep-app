import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// What was checked about an instructor, as a pill (instructors plan v2
/// §6.4). Factual, never "Safe": stage 0 «Не проверен», 1 «Личность
/// подтверждена», 2 «Проверен».
///
/// Colours from the palette: amber *text* fails AA at pill size, so the
/// unchecked stages are a neutral `field` pill with `inkSecondary` text and an
/// amber icon (graphics need only 3:1); the checked stage is `guide` on
/// `guideSurface` (4.86:1).
class InstructorStageBadge extends StatelessWidget {
  const InstructorStageBadge({super.key, required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final verified = stage >= 2;
    final label = switch (stage) {
      0 => l.translate('stage_unverified'),
      1 => l.translate('stage_id_checked'),
      _ => l.translate('stage_verified'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 6),
      decoration: BoxDecoration(
        color: verified ? AppColors.guideSurface : AppColors.field,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? SolarIcons.shieldCheckBold : SolarIcons.dangerCircleLinear,
            size: 16,
            color: verified ? AppColors.guide : AppColors.warn,
          ),
          const SizedBox(width: AppSpacing.x1),
          Text(
            label,
            maxLines: 1,
            style: AppTypography.caption.copyWith(
              color: verified ? AppColors.guide : AppColors.inkSecondary,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
        ],
      ),
    );
  }
}
