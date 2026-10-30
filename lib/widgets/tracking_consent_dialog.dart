import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

/// Android's stand-in for iOS's tracking prompt: the system has none, so the
/// app asks. Both answers are the same size and nothing stands behind either.
class TrackingConsentDialog extends StatelessWidget {
  const TrackingConsentDialog({super.key});

  /// True for Allow. It can't be dismissed without an answer.
  static Future<bool> show(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TrackingConsentDialog(),
    );
    return yes ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget answer(String key, bool value) => TextButton(
          style: TextButton.styleFrom(
            backgroundColor: AppColors.field,
            foregroundColor: AppColors.ink,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: AppTypography.label.copyWith(fontSize: 16, fontVariations: const [FontVariation('wght', 500)]),
          ),
          onPressed: () => Navigator.of(context).pop(value),
          child: Text(l.translate(key)),
        );
    return AlertDialog(
      title: Text(
        l.translate('tracking_title'),
        style: AppTypography.title.copyWith(
          fontSize: 22,
          height: 28 / 22,
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
      content: Text(l.translate('tracking_body')),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.x6, 0, AppSpacing.x6, AppSpacing.x6),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            answer('tracking_allow', true),
            const SizedBox(height: AppSpacing.x2),
            answer('tracking_decline', false),
          ],
        ),
      ],
    );
  }
}
