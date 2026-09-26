import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../localization/app_localizations.dart';
import '../utils/subscription_checker.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

class PremiumBlockDialog extends StatelessWidget {
  final String featureName;
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onClosePressed;

  const PremiumBlockDialog({
    Key? key,
    required this.featureName,
    this.onUpgradePressed,
    this.onClosePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final isExpiredTrial = subscriptionProvider.hasExpiredTrial;
        final titleKey = SubscriptionChecker.getBlockTitleKey(subscriptionProvider);
        final messageKey = SubscriptionChecker.getBlockMessageKey(subscriptionProvider);
        final l = AppLocalizations.of(context);
        final close = onClosePressed ?? () => Navigator.of(context).pop();

        // Bento (2026-09-26): a white dialog card; the state as a tinted disc
        // — red when the trial has ended, amber otherwise (access running
        // out); the way forward as the dark `ink` pill, as the paywall's buy
        // button, and «Закрыть» as a field pill.
        return Dialog(
          backgroundColor: AppColors.paper,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BentoTokens.card),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x6,
              AppSpacing.x3,
              AppSpacing.x3,
              AppSpacing.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button (top right), a full 44pt target
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: close,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.field,
                      fixedSize: const Size(44, 44),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(SolarIcons.closeLinear, color: AppColors.inkSecondary, size: 22),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.x3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: isExpiredTrial ? AppColors.stopSurface : AppColors.warnSurface,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: isExpiredTrial
                              ? Image.asset(
                                  'assets/images/trial/locker.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.contain,
                                  excludeFromSemantics: true,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback to the Solar glyph if the asset fails to load
                                    return const Icon(
                                      SolarIcons.lockKeyholeMinimalisticLinear,
                                      size: 40,
                                      color: AppColors.stop,
                                    );
                                  },
                                )
                              : const Icon(
                                  SolarIcons.crownStarLinear,
                                  size: 40,
                                  color: AppColors.warn,
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),

                      // Title — one line, shrinking rather than wrapping
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l.translate(titleKey),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: AppTypography.title.copyWith(
                            fontSize: 22,
                            height: 28 / 22,
                            color: AppColors.ink,
                            fontVariations: const [FontVariation('wght', 600)],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x3),

                      // Feature-specific message
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: featureName,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontVariations: [FontVariation('wght', 600)],
                              ),
                            ),
                            TextSpan(
                              text: ' ${l.translate('subscription_required').toLowerCase()}',
                            ),
                          ],
                        ),
                        style: AppTypography.body.copyWith(color: AppColors.ink),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.x2),

                      // Detailed message
                      Text(
                        l.translate(messageKey),
                        style: AppTypography.body.copyWith(
                          fontSize: 15,
                          height: 22 / 15,
                          color: AppColors.inkSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.x6),

                      // Upgrade (primary)
                      FilledButton(
                        onPressed: onUpgradePressed ?? () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(context, '/subscription');
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: AppColors.onSignal,
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                          textStyle: AppTypography.label.copyWith(
                            fontSize: 16,
                            fontVariations: const [FontVariation('wght', 500)],
                          ),
                        ),
                        child: Text(l.translate('upgrade_now')),
                      ),
                      const SizedBox(height: AppSpacing.x2),

                      // Close (secondary)
                      TextButton(
                        onPressed: close,
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.field,
                          foregroundColor: AppColors.ink,
                          minimumSize: const Size.fromHeight(52),
                          shape: const StadiumBorder(),
                          textStyle: AppTypography.label.copyWith(
                            fontSize: 16,
                            fontVariations: const [FontVariation('wght', 500)],
                          ),
                        ),
                        child: Text(l.translate('close')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Static method to show the premium block dialog
  static Future<void> show(
    BuildContext context, {
    required String featureName,
    VoidCallback? onUpgradePressed,
    VoidCallback? onClosePressed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => PremiumBlockDialog(
        featureName: featureName,
        onUpgradePressed: onUpgradePressed,
        onClosePressed: onClosePressed,
      ),
    );
  }
}
