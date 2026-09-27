import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'bento_auth_parts.dart';

/// Shown when content was REFUSED for lack of a subscription, rather than
/// being genuinely absent (risk #3's entitlement gate).
///
/// Before that gate existed a content fetch could only come back empty, so
/// every screen treated "nothing to show" as a content or language problem.
/// A refusal now looks identical from the outside, and telling someone their
/// state has no theory modules when the real answer is "you have no
/// subscription" sends them hunting for a bug that does not exist.
///
/// Bento (2026-09-26): one white card from the top of the space — the lock
/// on a soft blue disc, the title on one line, the reason, and the dark `ink`
/// pill to the paywall, as the paywall's own buy button.
class SubscriptionRequiredView extends StatelessWidget {
  const SubscriptionRequiredView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        // The trial card's gutter, so the two cards line up on Теория.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4 + AppSpacing.x1,
          AppSpacing.x3,
          AppSpacing.x4 + AppSpacing.x1,
          AppSpacing.x6,
        ),
        child: StaggerIn(
          index: 0,
          count: 1,
          curve: BentoTokens.curve,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.x6),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: AppColors.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                bentoAuthBadge(SolarIcons.lockKeyholeMinimalisticLinear),
                const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),
                // One line; a long translation shrinks rather than wraps.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    localizations.translate('subscription_required_title'),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: AppTypography.title.copyWith(
                      fontSize: 22,
                      height: 28 / 22,
                      color: AppColors.ink,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  localizations.translate('subscription_required_message'),
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    fontSize: 15,
                    height: 22 / 15,
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                BentoAuthPrimaryButton(
                  label: localizations.translate('subscribe_now'),
                  onPressed: () => Navigator.pushNamed(context, '/subscription'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
