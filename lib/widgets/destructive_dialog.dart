import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';

/// The destructive confirmation (design-patterns: red ⚠ disc, one-line
/// title, the consequence, then two stacked pills — the action a field pill
/// with a red label, the safe way out the dark ink pill). Pops true when the
/// action is confirmed.
class DestructiveDialog extends StatelessWidget {
  const DestructiveDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirm,
    required this.keep,
  });

  final String title;
  final String body;
  final String confirm;
  final String keep;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(color: AppColors.stopSurface, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: const Icon(SolarIcons.dangerTriangleLinear, color: AppColors.stop, size: 28),
      ),
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title,
          maxLines: 1,
          style: AppTypography.title.copyWith(
            fontSize: 22,
            height: 28 / 22,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
      ),
      content: Text(body),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.x6, 0, AppSpacing.x6, AppSpacing.x6),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.field,
                foregroundColor: AppColors.stop,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: AppTypography.label.copyWith(fontSize: 16, fontVariations: const [FontVariation('wght', 500)]),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirm),
            ),
            const SizedBox(height: AppSpacing.x2),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.onSignal,
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                textStyle: AppTypography.label.copyWith(fontSize: 16, fontVariations: const [FontVariation('wght', 600)]),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(keep),
            ),
          ],
        ),
      ],
    );
  }
}
