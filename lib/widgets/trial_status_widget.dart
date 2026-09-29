import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_management_service.dart';
import '../localization/app_localizations.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

/// Subscription status, shown on every tab.
///
/// The state machine in [build] is unchanged — same conditions, same order,
/// same translation keys, same destinations. Only the rendering is new.
///
/// It used to draw a tinted, bordered, shadowed card with its own gradient per
/// state (blue when fine, orange when urgent, red when expired), repeated on
/// Tests, Theory and Profile, taking roughly 12% of the viewport each time. It
/// is status, not a feature: it now renders as one quiet row, and only raises
/// its voice — amber, then red — when something actually needs doing.
class TrialStatusWidget extends StatelessWidget {
  const TrialStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        debugPrint('🎯 TrialStatusWidget: Building with isTrialActive=${subscriptionProvider.isTrialActive}');
        debugPrint('🎯 TrialStatusWidget: Subscription loaded=${subscriptionProvider.subscription != null}');
        debugPrint('🎯 TrialStatusWidget: Is loading=${subscriptionProvider.isLoading}');

        // Get subscription states
        final hasActiveTrial = subscriptionProvider.isTrialActive;
        final hasExpiredTrial = subscriptionProvider.hasExpiredTrial;
        final hasValidPaidSubscription = subscriptionProvider.hasValidSubscription &&
                                        subscriptionProvider.subscription != null &&
                                        !subscriptionProvider.subscription!.isTrial;
        final hasExpiredPaidSubscription = subscriptionProvider.hasExpiredPaidSubscription;
        final isLoading = subscriptionProvider.isLoading;

        // Show loading state
        if (isLoading) {
          debugPrint('⏳ TrialStatusWidget: Loading subscription data...');
          return _buildLoadingWidget();
        }

        // Hide widget only if user has active PAID subscription
        if (hasValidPaidSubscription) {
          debugPrint('✅ TrialStatusWidget: User has active paid subscription - hiding widget');
          return const SizedBox.shrink();
        }

        // Show widget for active trial, expired trial, or expired paid subscription
        if (hasActiveTrial) {
          debugPrint('✅ TrialStatusWidget: Showing active trial status');
          return _buildTrialWidget(context, subscriptionProvider, isActive: true);
        } else if (hasExpiredTrial) {
          debugPrint('⏰ TrialStatusWidget: Showing expired trial status');
          return _buildTrialWidget(context, subscriptionProvider, isActive: false);
        } else if (hasExpiredPaidSubscription) {
          debugPrint('💳 TrialStatusWidget: Showing expired paid subscription status');
          return _buildExpiredPaidWidget(context, subscriptionProvider);
        } else {
          // Risk #58 — this branch is reachable, and used to render nothing at
          // all. A user with no subscription (the trial was refused, or was
          // never created) saw a blank space and no explanation. The comment
          // that used to sit here said it "should theoretically never happen",
          // which is what stopped anyone treating it as real.
          debugPrint('ℹ️ TrialStatusWidget: No subscription — reason: '
              '${SubscriptionManagementService.lastTrialRejectionReason ?? "unknown"}');
          return _buildNoSubscriptionWidget(context);
        }
      },
    );
  }

  /// The shared card. Every state renders through this.
  ///
  /// [tone] is the only thing that varies visually, and it is earned: neutral
  /// while nothing is wrong, amber when the trial is nearly out, red once
  /// access has actually lapsed. It is one card, not four hand-styled ones.
  ///
  /// A small borderless card — bold label, the detail in a pill, and the
  /// action as a solid blue pill.
  ///
  /// [stacked] is for a detail that is a sentence, not a value (the no-plan
  /// state, 2026-09-26): the pill was made for «Дней осталось: 3» and wrapped a
  /// sentence into a five-line bold blob, and the long action label beside it
  /// squeezed the title small. Stacked, the sentence is plain grey text under
  /// the title and the action a full-width pill below.
  ///
  /// [pillSubtitle] keeps the detail in its pill inside the stacked layout —
  /// the active trial's «Дней осталось: 3» is a value, not a sentence, and
  /// stacks only so its action can run full width (owner, 2026-09-28).
  Widget _buildRow({
    required BuildContext context,
    required String iconAsset,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    Color tone = AppColors.inkSecondary,
    Color toneSurface = AppColors.field,
    bool stacked = false,
    bool pillSubtitle = false,
    bool softAction = false,
  }) {
    final bool hasSubtitle = subtitle != null && subtitle.trim().isNotEmpty;
    final bool hasAction = actionLabel != null && onAction != null;

    final actionStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const StadiumBorder(),
    );
    Widget actionText(String label) => Text(
          label,
          style: AppTypography.label.copyWith(
            fontSize: 13,
            color: AppColors.onSignal,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        );
    final icon = Container(
      width: stacked ? 44 : 40,
      height: stacked ? 44 : 40,
      decoration: BoxDecoration(
        color: toneSurface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: AppIcons.icon(iconAsset, size: stacked ? 20 : 18, color: tone),
    );
    Widget subtitlePill(String text) => Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: AppColors.ink,
              fontVariations: const [
                FontVariation('wght', 600),
              ],
              fontFeatures: const [
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        );
    final titleText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        maxLines: 1,
        style: AppTypography.label.copyWith(
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 700)],
        ),
      ),
    );

    if (stacked) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.x4),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(BentoTokens.card),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0E1F4D),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              // The disc sits centred on a short title + pill block; beside a
              // sentence it stays at the top.
              crossAxisAlignment: hasSubtitle && !pillSubtitle
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      titleText,
                      if (hasSubtitle && pillSubtitle) ...[
                        const SizedBox(height: AppSpacing.x1),
                        subtitlePill(subtitle),
                      ] else if (hasSubtitle) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.body.copyWith(
                            fontSize: 14,
                            height: 20 / 14,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hasAction) ...[
              const SizedBox(height: AppSpacing.x4),
              if (softAction)
                // A live trial is not an emergency: the dark `ink` pill, like
                // the other secondary actions (owner, 2026-09-28), so the card
                // does not out-shout the blue exam hero below it.
                FilledButton(
                  onPressed: onAction,
                  style: actionStyle.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                    backgroundColor: const WidgetStatePropertyAll(AppColors.ink),
                    overlayColor: WidgetStatePropertyAll(
                        AppColors.onSignal.withValues(alpha: 0.08)),
                    elevation: const WidgetStatePropertyAll(0),
                  ),
                  child: Text(
                    actionLabel,
                    style: AppTypography.label.copyWith(
                      fontSize: 15,
                      color: AppColors.onSignal,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                )
              else
                FilledButton(
                  onPressed: onAction,
                  style: actionStyle,
                  child: actionText(actionLabel),
                ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0E1F4D),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // One line (owner, 2026-09-26): a long title — «Пробный
                // период активен» — shrinks slightly rather than wrapping.
                titleText,
                if (hasSubtitle) ...[
                  const SizedBox(height: AppSpacing.x1),
                  subtitlePill(subtitle),
                ],
              ],
            ),
          ),
          if (hasAction) ...[
            const SizedBox(width: AppSpacing.x2),
            FilledButton(
              onPressed: onAction,
              style: actionStyle,
              child: actionText(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  /// A skeleton in the row's own shape, rather than a spinner that implies
  /// something is stuck.
  Widget _buildLoadingWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(BentoTokens.chip),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Container(
            width: 168,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(BentoTokens.chip),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when the user holds no subscription at all (risk #58).
  ///
  /// Where the server gave a reason, say that specific thing — an unverified
  /// email is fixable by the user in seconds, but only if we tell them.
  Widget _buildNoSubscriptionWidget(BuildContext context) {
    final reason = SubscriptionManagementService.lastTrialRejectionReason;
    final needsVerification = reason == 'email-not-verified';
    final localizations = AppLocalizations.of(context);

    // NOTE: translate() returns the KEY itself when a string is missing, never
    // null (app_localizations.dart), so a `?? fallback` here would be dead code
    // and the user would see "no_subscription_title" on screen. These four keys
    // are defined in all five l10n files — see risk #50 for the wider problem.
    final title = localizations.translate(
        needsVerification ? 'verify_email_title' : 'no_subscription_title');
    final message = localizations.translate(
        needsVerification ? 'verify_email_message' : 'no_subscription_message');

    return _buildRow(
      context: context,
      iconAsset: AppIcons.clock,
      title: title,
      subtitle: message,
      tone: AppColors.warn,
      toneSurface: AppColors.warnSurface,
      stacked: true,
      // An unverified email is fixed in the app, not on the paywall, so only
      // the genuine no-subscription case offers to subscribe.
      actionLabel: needsVerification
          ? null
          : localizations.translate('subscribe_now'),
      onAction: needsVerification
          ? null
          : () => Navigator.pushNamed(context, '/subscription'),
    );
  }

  Widget _buildTrialWidget(
    BuildContext context,
    SubscriptionProvider subscriptionProvider, {
    required bool isActive,
  }) {
    final daysRemaining = subscriptionProvider.trialDaysRemaining;
    final isUrgent = daysRemaining <= 1 && isActive;
    final isExpired = !isActive;
    final localizations = AppLocalizations.of(context);

    final title = isExpired
        ? localizations.translate('trial_expired')
        : isUrgent
            ? localizations.translate('trial_expires_soon')
            : localizations.translate('trial_active');

    final subtitle = isExpired
        ? localizations.translate('subscription_required')
        : '${localizations.translate('days_left')}: $daysRemaining';

    return _buildRow(
      context: context,
      iconAsset: AppIcons.clock,
      title: title,
      subtitle: subtitle,
      tone: isExpired
          ? AppColors.stop
          : isUrgent
              ? AppColors.warn
              : AppColors.warn,
      toneSurface: isExpired ? AppColors.stopSurface : AppColors.warnSurface,
      // Stacked in every state, so the action is a full-width pill under the
      // title (owner, 2026-09-28) and the title no longer shrinks beside it.
      // Active, the days left stay in their pill; expired, the detail is a
      // sentence («Потрібна підписка для продовження») and goes plain grey.
      stacked: true,
      pillSubtitle: !isExpired,
      softAction: !isExpired,
      actionLabel: localizations.translate('upgrade_now'),
      onAction: () => Navigator.pushNamed(context, '/subscription'),
    );
  }

  Widget _buildExpiredPaidWidget(
    BuildContext context,
    SubscriptionProvider subscriptionProvider,
  ) {
    final localizations = AppLocalizations.of(context);

    return _buildRow(
      context: context,
      iconAsset: AppIcons.clock,
      title: localizations.translate('subscription_expired'),
      subtitle: localizations.translate('renew_to_continue'),
      tone: AppColors.stop,
      toneSurface: AppColors.stopSurface,
      stacked: true,
      actionLabel: localizations.translate('renew_now'),
      onAction: () => Navigator.pushNamed(context, '/subscription'),
    );
  }
}
