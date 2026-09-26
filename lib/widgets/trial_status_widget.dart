import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/subscription_management_service.dart';
import '../localization/app_localizations.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';

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
  /// The design variant changes the shape of that one card — never which
  /// state is shown, what it says, or where its action goes.
  Widget _buildRow({
    required BuildContext context,
    required String iconAsset,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
    Color tone = AppColors.inkSecondary,
    Color toneSurface = AppColors.field,
  }) {
    final bool hasSubtitle = subtitle != null && subtitle.trim().isNotEmpty;
    final bool hasAction = actionLabel != null && onAction != null;

    return ValueListenableBuilder<DesignVariant>(
      valueListenable: designVariant,
      builder: (context, variant, _) {
        final tokens = VariantTokens.of(variant);
        switch (variant) {
          case DesignVariant.refined:
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x3,
              ),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(tokens.card),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.shadowResting,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: toneSurface,
                      borderRadius: BorderRadius.circular(tokens.chip),
                    ),
                    alignment: Alignment.center,
                    child: AppIcons.icon(iconAsset, size: 18, color: tone),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _texts(title, hasSubtitle ? subtitle : null,
                        titleWeight: 600),
                  ),
                  if (hasAction) ...[
                    const SizedBox(width: AppSpacing.x2),
                    _textAction(actionLabel, onAction),
                  ],
                ],
              ),
            );

          case DesignVariant.boldA:
            // Signal: the status is a small card of its own, and its action
            // is a real button rather than a link.
            return Container(
              padding: const EdgeInsets.all(AppSpacing.x3),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(tokens.card),
                boxShadow: AppColors.shadowResting,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: toneSurface,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcons.icon(iconAsset, size: 20, color: tone),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: _texts(title, hasSubtitle ? subtitle : null,
                        titleWeight: 700),
                  ),
                  if (hasAction) ...[
                    const SizedBox(width: AppSpacing.x2),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.button),
                        ),
                      ),
                      child: Text(
                        actionLabel,
                        style: AppTypography.label.copyWith(
                          color: AppColors.onSignal,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );

          case DesignVariant.bento:
            // Bento: a small borderless card — bold label, the detail in a
            // pill, and the action as a solid blue pill.
            return Container(
              padding: const EdgeInsets.all(AppSpacing.x4),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(tokens.card),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: toneSurface,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcons.icon(iconAsset, size: 18, color: tone),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.label.copyWith(
                            color: AppColors.ink,
                            fontVariations: const [FontVariation('wght', 700)],
                          ),
                        ),
                        if (hasSubtitle) ...[
                          const SizedBox(height: AppSpacing.x1),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.x2,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.field,
                              borderRadius: BorderRadius.circular(tokens.chip),
                            ),
                            child: Text(
                              subtitle,
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
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasAction) ...[
                    const SizedBox(width: AppSpacing.x2),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        actionLabel,
                        style: AppTypography.label.copyWith(
                          fontSize: 13,
                          color: AppColors.onSignal,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );

          case DesignVariant.boldB:
            // Ledger: one quiet strip. The glyph carries the tone; the text
            // stays ink so the status never shouts louder than the content.
            return Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.only(
                left: AppSpacing.x3,
                right: AppSpacing.x1,
              ),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(tokens.card),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  AppIcons.icon(iconAsset, size: 16, color: tone),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                      // Two short lines rather than one run-on: a single
                      // wrapped line broke "Дней осталось: 3" mid-phrase.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTypography.label.copyWith(
                              color: AppColors.ink,
                              fontSize: 13,
                              height: 18 / 13,
                              fontVariations: const [
                                FontVariation('wght', 600),
                              ],
                            ),
                          ),
                          if (hasSubtitle)
                            Text(
                              subtitle,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.inkSecondary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (hasAction) _textAction(actionLabel, onAction),
                ],
              ),
            );
        }
      },
    );
  }

  Widget _texts(String title, String? subtitle, {required double titleWeight}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.label.copyWith(
            color: AppColors.ink,
            fontVariations: [FontVariation('wght', titleWeight)],
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.inkSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }

  Widget _textAction(String label, VoidCallback onAction) {
    return TextButton(
      onPressed: onAction,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          fontSize: 13,
          color: AppColors.signal,
          fontVariations: const [FontVariation('wght', 700)],
        ),
      ),
    );
  }

  /// A skeleton in the row's own shape, rather than a spinner that implies
  /// something is stuck.
  Widget _buildLoadingWidget() {
    return ValueListenableBuilder<DesignVariant>(
      valueListenable: designVariant,
      builder: (context, variant, _) {
        final tokens = VariantTokens.of(variant);
        final bool strip = variant == DesignVariant.boldB;
        final double glyph = strip
            ? 16
            : variant == DesignVariant.boldA
                ? 44
                : 36;
        return Container(
          height: strip ? 44 : null,
          padding: EdgeInsets.symmetric(
            horizontal: strip ? AppSpacing.x3 : AppSpacing.x4,
            vertical: strip ? 0 : AppSpacing.x3,
          ),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(tokens.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: glyph,
                height: glyph,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(
                    variant == DesignVariant.boldA ? glyph / 2 : tokens.chip,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Container(
                width: 168,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(tokens.chip),
                ),
              ),
            ],
          ),
        );
      },
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
      actionLabel: localizations.translate('renew_now'),
      onAction: () => Navigator.pushNamed(context, '/subscription'),
    );
  }
}
