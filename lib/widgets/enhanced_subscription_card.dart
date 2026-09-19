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

class _EnhancedSubscriptionCardState extends State<EnhancedSubscriptionCard> with TickerProviderStateMixin {
  bool _isProcessing = false;
  String? _errorMessage;
  InAppPurchaseService? _iapService;

  late AnimationController _cardAnimationController;
  late AnimationController _featuresAnimationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _scaleController;

  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _buttonSlideAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

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
    
    // Initialize animation controllers
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _featuresAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );

    // Setup animations
    _cardSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    ));

    _cardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeIn,
    ));

    _buttonSlideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeOut,
    ));

    _buttonFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeIn,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Start animations with delays
    _startAnimations();
    
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

  void _startAnimations() {
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) _cardAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) _featuresAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 600), () {
      if (mounted) _buttonAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    _featuresAnimationController.dispose();
    _buttonAnimationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Helper method to get gradient for subscription card
  LinearGradient _getCardGradient() {
    if (widget.subscriptionType == SubscriptionType.yearly) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.orange.shade50.withOpacity(0.3)],
        stops: [0.0, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for pricing section
  LinearGradient _getPricingGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Colors.green.shade50.withOpacity(0.4)],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for subscribe button
  LinearGradient _getButtonGradient(bool isActive) {
    if (isActive) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.green.shade50.withOpacity(0.4)],
        stops: [0.0, 1.0],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.orange.shade50.withOpacity(0.4)],
        stops: [0.0, 1.0],
      );
    }
  }

  // Helper method to get gradient for trial countdown widget
  LinearGradient _getTrialCountdownGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Colors.orange.shade50.withOpacity(0.4)],
      stops: [0.0, 1.0],
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

    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlideAnimation.value),
          child: Opacity(
            opacity: _cardFadeAnimation.value,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _getCardGradient(),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    
                    // Title
                    Text(
                      widget.subscriptionType == SubscriptionType.yearly
                          ? AppLocalizations.of(context).translate('yearly_subscription')
                          : AppLocalizations.of(context).translate('monthly_subscription'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    
                    // Enhanced pricing section
                    _buildEnhancedPricingSection(),
                    
                    SizedBox(height: 24),
                    
                    // Features section
                    Text(
                      AppLocalizations.of(context).translate('features_include'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    // Enhanced features list
                    _buildEnhancedFeaturesList(),
                    
                    SizedBox(height: 24),
                    
                    // Error message
                    if (_errorMessage != null) ...[
                      _buildEnhancedErrorMessage(),
                      SizedBox(height: 16),
                    ],
                    
                    // Enhanced button/active indicator
                    _buildEnhancedActionArea(isPaidSubscription, isActiveTrial),
                    
                    SizedBox(height: 12),
                    
                    // Fine print
                    Text(
                      widget.subscriptionType == SubscriptionType.yearly
                          ? AppLocalizations.of(context).translate('yearly_auto_renew_text')
                          : AppLocalizations.of(context).translate('auto_renew_text'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        children: [
                          TextSpan(text: 'By subscribing you agree to our '),
                          TextSpan(
                            text: 'Terms of Use',
                            style: TextStyle(decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => launchUrl(
                                    Uri.parse('https://sites.google.com/view/driveusa/home'),
                                    mode: LaunchMode.externalApplication,
                                  ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(decoration: TextDecoration.underline),
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBestValueBadgeForPriceContainer() {
    return Positioned(
      top: -8,
      right: -8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          AppLocalizations.of(context).translate('best_value'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedPricingSection() {
    String formatDate(DateTime? date) {
      if (date == null) return 'N/A';
      return '${date.month}/${date.day}/${date.year}';
    }

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getPricingGradient(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.price,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    widget.period,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              if (widget.subscriptionType == SubscriptionType.yearly) ...[
                SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).translate('save_per_year'),
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
              SizedBox(height: 8),
              // NEW: Enhanced trial countdown display
              // FIXED: Only show if user has trial AND not paid subscription
              if (widget.subscription?.isTrial == true && 
                  widget.subscription?.isPaidSubscription == false) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: _getTrialCountdownGradient(),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.15),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.white, Colors.orange.shade100],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.access_time, 
                          size: 14, 
                          color: Colors.orange.shade700
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '${AppLocalizations.of(context).translate('trial_days_left')}: ${widget.subscriptionProvider.trialDaysRemaining}',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4),
              ],
              // For trial subscriptions - show when trial ends
              if (widget.subscription?.isTrial == true && widget.subscription?.trialEndsAt != null)
                Text(
                  '${AppLocalizations.of(context).translate('plan_ends')}: ${formatDate(widget.subscription!.trialEndsAt)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              // For paid subscriptions - show next billing date  
              if (widget.subscription?.isPaidSubscription == true && widget.subscription?.nextBillingDate != null)
                Text(
                  '${AppLocalizations.of(context).translate('next_billing')}: ${formatDate(widget.subscription!.nextBillingDate)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              // For canceled but still active subscriptions - show when access ends
              if (widget.subscription?.status == 'canceled' && widget.subscription?.isActive == true && widget.subscription?.nextBillingDate != null)
                Text(
                  '${AppLocalizations.of(context).translate('plan_ends')}: ${formatDate(widget.subscription!.nextBillingDate)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              Text(
                '${AppLocalizations.of(context).translate('plan_type')}: ${_getLocalizedPlanType(context, widget.subscription?.planType)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          // Best Value Badge positioned in price container
          if (widget.showBestValue) _buildBestValueBadgeForPriceContainer(),
        ],
      ),
    );
  }

  Widget _buildEnhancedFeaturesList() {
    final features = _getLocalizedFeatures(context);
    
    return Column(
      children: features.asMap().entries.map((entry) {
        int index = entry.key;
        String feature = entry.value;
        
        return AnimatedBuilder(
          animation: _featuresAnimationController,
          builder: (context, child) {
            final delay = index * 0.1;
            final progress = (_featuresAnimationController.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
            
            return Transform.translate(
              offset: Offset(-30 * (1 - progress), 0),
              child: Opacity(
                opacity: progress,
                child: _buildEnhancedFeatureItem(feature),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildEnhancedFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50.withOpacity(0.6)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade200, width: 1),
            ),
            child: Icon(
              Icons.check,
              color: Colors.green.shade700,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedErrorMessage() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.red.shade50.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500),
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
    
    return AnimatedBuilder(
      animation: _buttonAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonSlideAnimation.value),
          child: Opacity(
            opacity: _buttonFadeAnimation.value,
            child: actionWidget,
          ),
        );
      },
    );
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

  Widget _buildCanceledButActiveIndicator() {
    final expiryDate = widget.subscriptionProvider.canceledExpiryDateFormatted;
    final daysRemaining = widget.subscriptionProvider.daysUntilCanceledExpiry;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.orange.shade50.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.orange.shade100],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade300, width: 2),
                ),
                child: Icon(Icons.schedule, color: Colors.orange.shade700, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Canceled',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Access until $expiryDate ($daysRemaining days)',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Your subscription has been canceled. You\'ll continue to have access to premium features until your current billing period ends.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanceledExpiredIndicator() {
    return Column(
      children: [
        // ── Expired banner ──────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.red.shade50.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.red.shade100],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red.shade300, width: 2),
                ),
                child: Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Expired',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Renew to continue access',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ── Renew button (same IAP flow as Subscribe Now) ───────────────────
        SizedBox(height: 12),
        _buildEnhancedSubscribeButton(false),
      ],
    );
  }

  Widget _buildActiveSubscriptionIndicator() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.green.shade50.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.green.shade100],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('subscribed_success'),
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _buildCancelSubscriptionButton(),
      ],
    );
  }

  Widget _buildEnhancedActiveIndicator() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.green.shade50.withOpacity(0.6)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.green.shade100],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate('subscribed_success'),
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
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

    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _buttonScaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: _getButtonGradient(false),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isProcessing ? null : handleSubscribe,
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _isProcessing
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          '${isActiveTrial ? AppLocalizations.of(context).translate('upgrade_now') : AppLocalizations.of(context).translate('subscribe_now')} - ${widget.price}${widget.period}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
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

  Widget _buildCancelSubscriptionButton() {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _buttonScaleAnimation,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.red.shade50.withOpacity(0.4)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showCancelConfirmation(context),
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).translate('cancel_subscription'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
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

  Future<void> _showCancelConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('cancel_subscription_title')),
        content: Text(
          AppLocalizations.of(context).translate('cancel_subscription_message'),
        ),
        actions: [
          // Cancel subscription button (red gradient)
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.red.shade50.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  Navigator.of(context).pop(); // Close dialog
                  await _handleCancelSubscription();
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).translate('cancel_subscription_confirm'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Keep subscription button (green gradient)
          Container(
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.green.shade50.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context).translate('keep_subscription'),
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
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
