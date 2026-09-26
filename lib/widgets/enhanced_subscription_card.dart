import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/subscription.dart';
import '../models/user_subscription.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../services/in_app_purchase_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

class EnhancedSubscriptionCard extends StatefulWidget {
  final SubscriptionType subscriptionType;
  /// The price EXACTLY as the store formats it — "$9.99", "11,99 US$",
  /// "£7.99". It already carries its own currency, so nothing here prefixes a
  /// symbol. Prefixing a dollar sign is what made the paywall misquote every
  /// storefront but the US one (found on a device, 2026-09-19).
  final String price;
  final String period;
  final UserSubscription? subscription;
  final SubscriptionProvider subscriptionProvider;
  final int packageId;
  final bool showBestValue;
  /// Whether this card is the currently visible page in the PageView.
  /// Only the active card should own the shared InAppPurchaseService callbacks.
  final bool isActive;

  const EnhancedSubscriptionCard({
    Key? key,
    required this.subscriptionType,
    required this.price,
    required this.period,
    required this.subscription,
    required this.subscriptionProvider,
    required this.packageId,
    this.showBestValue = false,
    this.isActive = true,
  }) : super(key: key);

  @override
  _EnhancedSubscriptionCardState createState() => _EnhancedSubscriptionCardState();
}

class _EnhancedSubscriptionCardState extends State<EnhancedSubscriptionCard> {
  bool _isProcessing = false;
  String? _errorMessage;
  InAppPurchaseService? _iapService;

  // The four delayed entrance/press controllers were replaced by a one-shot
  // StaggerIn and PressScale (2026-09-26, Bento).

  List<String> _getLocalizedFeatures(BuildContext context) {
    return [
      AppLocalizations.of(context).translate('unlimited_access'),
      AppLocalizations.of(context).translate('full_practice_suite'),
      AppLocalizations.of(context).translate('progress_tracking'),
      AppLocalizations.of(context).translate('performance_analytics'),
    ];
  }

  @override
  void initState() {
    super.initState();
    
    // Setup In-App Purchase callbacks.
    // Only the ACTIVE (visible) card registers callbacks — this prevents the
    // off-screen card from overwriting the callbacks when it is first built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iapService = Provider.of<InAppPurchaseService>(context, listen: false);
      if (widget.isActive) {
        _setupPurchaseCallbacks();
      }
    });
  }

  @override
  void didUpdateWidget(EnhancedSubscriptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When this card becomes the visible page, take ownership of the shared
    // IAP callbacks so purchase results are handled by the correct context.
    // If a purchase is already in flight we skip the transfer — the card that
    // started the purchase must stay in charge until it receives the result.
    if (widget.isActive && !oldWidget.isActive && _iapService != null) {
      if (!_iapService!.isPurchasePending) {
        debugPrint('📲 ${widget.subscriptionType == SubscriptionType.yearly ? 'Yearly' : 'Monthly'} card '
            'became active — re-claiming IAP callbacks');
        _setupPurchaseCallbacks();
      } else {
        debugPrint('⚠️ Skipping callback transfer: purchase in flight on the other card');
      }
    }
  }

  void _setupPurchaseCallbacks() {
    if (_iapService == null) return;
    
    // Get auth provider to access user ID
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    
    _iapService!.setPurchaseCallbacks(
      onSuccess: (productId) async {
        debugPrint('✅ Purchase successful: $productId');
        
        if (!mounted) return;
        
        setState(() {
          _isProcessing = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('subscription_successful')),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // FIXED: Add delay to ensure Firebase has processed the receipt validation
        debugPrint('⏳ Waiting for Firebase to process subscription...');
        await Future.delayed(Duration(milliseconds: 800));
        
        // Refresh subscription data from Firebase
        if (userId != null) {
          debugPrint('🔄 Refreshing subscription data from Firebase...');
          await widget.subscriptionProvider.initialize(userId);
          
          // FIXED: Force parent screen to rebuild with updated data
          if (mounted) {
            debugPrint('🔄 Forcing UI rebuild...');
            setState(() {});
          }
        }
        
        // FIXED: Guard navigation with mounted check — the widget can be
        // disposed during the async gaps above (800ms delay + initialize()).
        // Using context after disposal causes "deactivated widget" errors.
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      },
      onError: (error) {
        debugPrint('❌ Purchase error: $error');
        
        if (!mounted) return;
        
        setState(() {
          _isProcessing = false;
          _errorMessage = error;
        });
      },
      onCanceled: (productId) {
        debugPrint('❌ Purchase canceled: $productId');
        
        if (!mounted) return;
        
        setState(() {
          _isProcessing = false;
        });
        
        // Optional: Show cancellation message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase canceled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  // Helper method to get localized plan type
  String _getLocalizedPlanType(BuildContext context, String? planType) {
    if (planType == null) return AppLocalizations.of(context).translate('trial');
    
    switch (planType.toUpperCase()) {
      case 'MONTHLY':
        return AppLocalizations.of(context).translate('plan_type_monthly');
      case 'YEARLY':
        return AppLocalizations.of(context).translate('plan_type_yearly');
      case 'TRIAL':
        return AppLocalizations.of(context).translate('trial');
      default:
        return AppLocalizations.of(context).translate('trial');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaidSubscription = widget.subscription?.isPaidSubscription == true;
    final isActiveTrial = widget.subscription?.isTrial == true && 
                         widget.subscription?.isTrialActive == true;

    // The paywall in the Тесты look (2026-09-26): the plan as the blue hero,
    // the user's plan status as a white card, what is included as a list,
    // then the action and the fine print.
    final blocks = <Widget>[
      _buildEnhancedPricingSection(),
      const SizedBox(height: AppSpacing.x3),
      _buildPlanStatusCard(),
      const SizedBox(height: AppSpacing.x8),
      _buildSectionHeader(
        AppLocalizations.of(context)
            .translate('features_include')
            .replaceFirst(RegExp(r'\s*:\s*$'), ''),
      ),
      _buildEnhancedFeaturesList(),
      const SizedBox(height: AppSpacing.x6),
      // Error message
      if (_errorMessage != null) ...[
        _buildEnhancedErrorMessage(),
        const SizedBox(height: AppSpacing.x3),
      ],
      // Button or plan status
      _buildEnhancedActionArea(isPaidSubscription, isActiveTrial),
      const SizedBox(height: AppSpacing.x4),
      _buildFinePrint(),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++)
          StaggerIn(
            index: i,
            count: blocks.length,
            curve: BentoTokens.curve,
            child: blocks[i],
          ),
      ],
    );
  }

  /// A section label, as on Тесты: 15/600 ink, 12 below.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          fontSize: 15,
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  /// Auto-renewal terms and the legal links, quiet but legible.
  Widget _buildFinePrint() {
    return Column(
      children: [
        // Fine print
        Text(
          widget.subscriptionType == SubscriptionType.yearly
              ? AppLocalizations.of(context).translate('yearly_auto_renew_text')
              : AppLocalizations.of(context).translate('auto_renew_text'),
          style: AppTypography.caption.copyWith(
            fontSize: 13,
            height: 18 / 13,
            color: AppColors.inkSecondary,
            fontVariations: const [FontVariation('wght', 400)],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x2),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: AppTypography.caption.copyWith(
              color: AppColors.inkSecondary,
              fontVariations: const [FontVariation('wght', 400)],
            ),
            children: [
              TextSpan(text: AppLocalizations.of(context).translate('legal_agree_prefix')),
              TextSpan(
                text: AppLocalizations.of(context).translate('terms_of_use'),
                style: const TextStyle(
                  color: AppColors.signal,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.signal,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                        Uri.parse('https://sites.google.com/view/driveusa/home'),
                        mode: LaunchMode.externalApplication,
                      ),
              ),
              TextSpan(text: AppLocalizations.of(context).translate('legal_and')),
              TextSpan(
                text: AppLocalizations.of(context).translate('privacy_policy'),
                style: const TextStyle(
                  color: AppColors.signal,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.signal,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrl(
                        Uri.parse('https://sites.google.com/view/driveusa/privacy-policy'),
                        mode: LaunchMode.externalApplication,
                      ),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBestValueBadgeForPriceContainer() {
    // The hero's solid white pill, as «60 минут» on the exam card.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
      ),
      child: Text(
        AppLocalizations.of(context).translate('best_value'),
        style: AppTypography.caption.copyWith(
          fontSize: 13,
          color: AppColors.signal,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  /// The plan as the page's hero, in the Тесты exam card's blue: the plan's
  /// name, the store price large, and the exam card's rising bar strip behind.
  Widget _buildEnhancedPricingSection() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentoTokens.card),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.signal600, AppColors.signal, AppColors.signal400],
          stops: [0, 0.55, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290048C3),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: AppSpacing.x4 + AppSpacing.x1,
            bottom: 0,
            child: ExcludeSemantics(child: _heroBars()),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.subscriptionType == SubscriptionType.yearly
                      ? AppLocalizations.of(context).translate('yearly_subscription')
                      : AppLocalizations.of(context).translate('monthly_subscription'),
                  style: AppTypography.title.copyWith(
                    fontSize: 22,
                    height: 28 / 22,
                    color: AppColors.onSignal,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.price,
                      style: AppTypography.display.copyWith(
                        fontSize: 44,
                        height: 50 / 44,
                        letterSpacing: -1,
                        color: AppColors.onSignal,
                        fontVariations: const [FontVariation('wght', 700)],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      widget.period,
                      style: AppTypography.body.copyWith(
                        fontSize: 17,
                        color: AppColors.signal100,
                      ),
                    ),
                  ],
                ),
                if (widget.subscriptionType == SubscriptionType.yearly) ...[
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    AppLocalizations.of(context).translate('save_per_year'),
                    style: AppTypography.label.copyWith(
                      color: AppColors.signal100,
                      fontVariations: const [FontVariation('wght', 500)],
                    ),
                  ),
                ],
                // Best Value Badge
                if (widget.showBestValue) ...[
                  const SizedBox(height: AppSpacing.x3),
                  _buildBestValueBadgeForPriceContainer(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The exam card's bar strip (`EnhancedTestCard._questionBars`, frozen —
  /// copied), larger and fainter, as on the Профиль hero.
  Widget _heroBars() {
    const heights = [
      10, 16, 12, 22, 14, 26, 18, 30, 20, 34, 24, 28, 38, 26, 42, 30, 36, 46,
      32, 40, 50, 36, 44, 54, 40, 48, 58, 44, 52, 60, 48, 56, 62, 52, 58, 64,
      56, 60, 66, 62,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in heights)
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
    );
  }

  /// The user's plan as a white card of label/value rows: trial days left
  /// (amber — access running low), when the plan ends or next bills, and the
  /// plan type. Same conditions as before, one fact per row.
  Widget _buildPlanStatusCard() {
    String formatDate(DateTime? date) {
      if (date == null) return 'N/A';
      return '${date.month}/${date.day}/${date.year}';
    }

    final l = AppLocalizations.of(context);
    final rows = <Widget>[
      // Trial countdown — only if the user has a trial AND no paid subscription
      if (widget.subscription?.isTrial == true && 
          widget.subscription?.isPaidSubscription == false)
        _statusRow(
          l.translate('trial_days_left'),
          '${widget.subscriptionProvider.trialDaysRemaining}',
          icon: SolarIcons.clockCircleLinear,
          iconColor: AppColors.warn,
          iconSurface: AppColors.warnSurface,
        ),
      // For trial subscriptions - show when trial ends
      if (widget.subscription?.isTrial == true && widget.subscription?.trialEndsAt != null)
        _statusRow(l.translate('plan_ends'), formatDate(widget.subscription!.trialEndsAt)),
      // For paid subscriptions - show next billing date  
      if (widget.subscription?.isPaidSubscription == true && widget.subscription?.nextBillingDate != null)
        _statusRow(l.translate('next_billing'), formatDate(widget.subscription!.nextBillingDate)),
      // For canceled but still active subscriptions - show when access ends
      if (widget.subscription?.status == 'canceled' && widget.subscription?.isActive == true && widget.subscription?.nextBillingDate != null)
        _statusRow(l.translate('plan_ends'), formatDate(widget.subscription!.nextBillingDate)),
      _statusRow(l.translate('plan_type'), _getLocalizedPlanType(context, widget.subscription?.planType)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.field),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _statusRow(
    String label,
    String value, {
    IconData? icon,
    Color iconColor = AppColors.signal,
    Color iconSurface = AppColors.signal50,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: iconSurface, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.x2 + 2),
          ],
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontSize: 15,
                color: AppColors.inkSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Text(
            value,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// What the plan includes, one white card: a blue tick per line.
  Widget _buildEnhancedFeaturesList() {
    final features = _getLocalizedFeatures(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        children: [for (final feature in features) _buildEnhancedFeatureItem(feature)],
      ),
    );
  }

  Widget _buildEnhancedFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.signal50,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              SolarIcons.checkLinear,
              color: AppColors.signal,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                fontSize: 15,
                height: 22 / 15,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.stopSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(SolarIcons.dangerCircleLinear, color: AppColors.stop, size: 20),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.label.copyWith(
                color: AppColors.stop,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionArea(bool isPaidSubscription, bool isActiveTrial) {
    // NEW: Check if this card matches the user's current plan
    final isCurrentPlan = _isCurrentUserPlan();
    
    // Risk #2: the monthly→yearly upgrade path is gone. It reached a callable
    // that granted 365 paid days for free, and only the 30-day plan is sold.
    final isDowngradeOpportunity = _isDowngradeOpportunity();

    // LOGIC:
    // 1. Current plan OR downgrade card → Show "Subscribed" message (no subscribe button)
    // 2. Otherwise → Show "Subscribe" button

    final isExpiredSamePlan = _isExpiredMatchingPlan();

    Widget actionWidget;
    if (isExpiredSamePlan) {
      actionWidget = _buildCanceledExpiredIndicator();
    } else if (isCurrentPlan || isDowngradeOpportunity) {
      actionWidget = _buildSubscriptionStatusIndicator();
    } else {
      actionWidget = _buildEnhancedSubscribeButton(isActiveTrial);
    }
    
    return actionWidget;
  }

  /// Returns true when this card is a LOWER-tier plan than the user's current
  /// active subscription (e.g. monthly card while user has yearly).
  /// In that case we hide the "Subscribe Now" button — the downgrade API
  /// remains intact server-side for future use.
  bool _isDowngradeOpportunity() {
    if (widget.subscription == null) return false;
    return widget.subscriptionType == SubscriptionType.monthly &&
           widget.subscription!.planType == 'yearly' &&
           widget.subscription!.isValidSubscription;
  }


  /// NEW METHOD: Check if this card represents user's current plan
  bool _isCurrentUserPlan() {
    if (widget.subscription == null) return false;
    
    // Only treat as "current plan" if the subscription is actually valid/active.
    // An inactive or expired subscription of the same type must NOT show
    // "You're subscribed!" — the user needs to see the renew flow instead.
    if (!widget.subscription!.isValidSubscription) return false;
    
    final userPlanType = widget.subscription!.planType;
    final cardType = widget.subscriptionType;
    
    // Monthly card + user has monthly = current plan
    if (cardType == SubscriptionType.monthly && userPlanType == 'monthly') {
      return true;
    }

    // Yearly card + user has yearly = current plan
    if (cardType == SubscriptionType.yearly && userPlanType == 'yearly') {
      return true;
    }

    return false;
  }

  /// Returns true when this card's plan type matches the user's subscription
  /// but the subscription is no longer valid (inactive/expired).
  /// Used to show the "Subscription Expired" banner + Renew button instead
  /// of a plain "Subscribe Now" button, giving the user clear context.
  bool _isExpiredMatchingPlan() {
    if (widget.subscription == null) return false;
    if (widget.subscription!.isValidSubscription) return false; // still active — not expired
    if (widget.subscription!.isTrial) return false; // trial expiry is handled elsewhere

    final userPlanType = widget.subscription!.planType;
    final cardType = widget.subscriptionType;

    return (cardType == SubscriptionType.monthly && userPlanType == 'monthly') ||
           (cardType == SubscriptionType.yearly  && userPlanType == 'yearly');
  }

  Widget _buildSubscriptionStatusIndicator() {
    final isCanceled = widget.subscription?.status == 'canceled';
    final isInactive = widget.subscription?.status == 'inactive';
    final isStillActive = widget.subscription?.isActive == true;
    
    if (isCanceled && isStillActive) {
      return _buildCanceledButActiveIndicator();
    } else if (isCanceled || isInactive) {
      // Both canceled-expired and inactive subscriptions show the expired + renew UI
      return _buildCanceledExpiredIndicator();
    } else {
      return _buildActiveSubscriptionIndicator();
    }
  }

  /// A status panel: a tinted surface, a tone disc with its glyph, the title
  /// and one line under it. Colour carries the state — green subscribed,
  /// amber access running out, red expired.
  Widget _statusPanel({
    required IconData icon,
    required Color tone,
    required Color surface,
    required String title,
    String? subtitle,
    String? note,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(BentoTokens.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: tone, size: 22),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body.copyWith(
                        fontSize: 17,
                        height: 22 / 17,
                        color: AppColors.ink,
                        fontVariations: const [FontVariation('wght', 600)],
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        // Ink, not the tone: amber is too light for small text.
                        style: AppTypography.label.copyWith(
                          color: AppColors.ink,
                          fontVariations: const [FontVariation('wght', 400)],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              note,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                height: 18 / 13,
                color: AppColors.ink,
                fontVariations: const [FontVariation('wght', 400)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCanceledButActiveIndicator() {
    final expiryDate = widget.subscriptionProvider.canceledExpiryDateFormatted;
    final daysRemaining = widget.subscriptionProvider.daysUntilCanceledExpiry;
    
    final l = AppLocalizations.of(context);
    return _statusPanel(
      icon: SolarIcons.clockCircleLinear,
      tone: AppColors.warn,
      surface: AppColors.warnSurface,
      title: l.translate('subscription_canceled_title'),
      subtitle: l
          .translate('access_until')
          .replaceAll('{date}', '$expiryDate')
          .replaceAll('{days}', '$daysRemaining'),
      note: l.translate('subscription_canceled_note'),
    );
  }

  Widget _buildCanceledExpiredIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Expired banner ──────────────────────────────────────────────────
        _statusPanel(
          icon: SolarIcons.closeCircleBold,
          tone: AppColors.stop,
          surface: AppColors.stopSurface,
          title: AppLocalizations.of(context).translate('subscription_expired'),
          subtitle: AppLocalizations.of(context).translate('renew_to_continue'),
        ),
        // ── Renew button (same IAP flow as Subscribe Now) ───────────────────
        const SizedBox(height: AppSpacing.x3),
        _buildEnhancedSubscribeButton(false),
      ],
    );
  }

  Widget _buildActiveSubscriptionIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusPanel(
          icon: SolarIcons.checkCircleBold,
          tone: AppColors.guide,
          surface: AppColors.guideSurface,
          title: AppLocalizations.of(context).translate('subscribed_success'),
        ),
        const SizedBox(height: AppSpacing.x3),
        _buildCancelSubscriptionButton(),
      ],
    );
  }

  Widget _buildEnhancedSubscribeButton(bool isActiveTrial) {
    Future<void> handleSubscribe() async {
      if (_iapService == null) {
        debugPrint('❌ InAppPurchaseService not initialized');
        setState(() {
          _errorMessage = 'Purchase service not available. Please restart the app.';
        });
        return;
      }
      
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      
      try {
        // Use real product IDs that match App Store Connect
        String productId = widget.subscriptionType == SubscriptionType.yearly 
            ? 'yearly'   // ✅ Real product ID
            : 'monthly'; // ✅ Real product ID
        
        debugPrint('🛒 Initiating purchase for: $productId');
        
        // Call REAL purchase method (not mock!)
        final success = await _iapService!.purchaseProduct(productId);
        
        if (!success && mounted) {
          // Purchase initiation failed
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Failed to initiate purchase. Please try again.';
          });
        }
        // Note: If success, the callbacks we setup will handle the rest
        
      } catch (e) {
        debugPrint('❌ Subscription Button: Error: $e');
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _errorMessage = 'Purchase error. Please try again.';
          });
        }
      }
    }

    // The dark `ink` pill — the page's black element, as «Сохраненные» on
    // Тесты (owner, 2026-09-26); a spinner in place of the label while the
    // store sheet is being opened.
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      enabled: !_isProcessing,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x290E1422),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isProcessing ? null : handleSubscribe,
            borderRadius: radius,
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.onSignal,
                        strokeWidth: 3,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${isActiveTrial ? AppLocalizations.of(context).translate('upgrade_now') : AppLocalizations.of(context).translate('subscribe_now')} - ${widget.price}${widget.period}',
                          maxLines: 1,
                          style: AppTypography.label.copyWith(
                            fontSize: 16,
                            color: AppColors.onSignal,
                            fontVariations: const [FontVariation('wght', 600)],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// «Отменить подписку»: a white pill with a red label — destructive, and a
  /// confirmation dialog comes first.
  Widget _buildCancelSubscriptionButton() {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: radius,
          boxShadow: AppColors.shadowCard,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showCancelConfirmation(context),
            borderRadius: radius,
            child: Center(
              child: Text(
                AppLocalizations.of(context).translate('cancel_subscription'),
                style: AppTypography.label.copyWith(
                  fontSize: 16,
                  color: AppColors.stop,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// As the exam's exit dialog: the destructive choice as red text, keeping
  /// the subscription as the blue pill.
  Future<void> _showCancelConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('cancel_subscription_title')),
        content: Text(
          AppLocalizations.of(context).translate('cancel_subscription_message'),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _handleCancelSubscription();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.stop,
              minimumSize: const Size(0, 44),
            ),
            child: Text(
              AppLocalizations.of(context).translate('cancel_subscription_confirm'),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
            },
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              shape: const StadiumBorder(),
            ),
            child: Text(
              AppLocalizations.of(context).translate('keep_subscription'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelSubscription() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final url = Platform.isIOS
          ? Uri.parse('https://apps.apple.com/account/subscriptions')
          : Uri.parse('https://play.google.com/store/account/subscriptions');

      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!launched) {
        throw Exception('Could not open subscription settings');
      }
    } catch (e) {
      debugPrint('❌ Subscription Card: Failed to open store subscription settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('cancel_subscription_open_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
