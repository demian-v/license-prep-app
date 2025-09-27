import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../models/user_subscription.dart';
import '../providers/subscription_provider.dart';
import '../localization/app_localizations.dart';

class EnhancedSubscriptionCard extends StatefulWidget {
  final SubscriptionType subscriptionType;
  final String price;
  final String period;
  final UserSubscription? subscription;
  final SubscriptionProvider subscriptionProvider;
  final int packageId;
  final bool showBestValue;

  const EnhancedSubscriptionCard({
    Key? key,
    required this.subscriptionType,
    required this.price,
    required this.period,
    required this.subscription,
    required this.subscriptionProvider,
    required this.packageId,
    this.showBestValue = false,
  }) : super(key: key);

  @override
  _EnhancedSubscriptionCardState createState() => _EnhancedSubscriptionCardState();
}

class _EnhancedSubscriptionCardState extends State<EnhancedSubscriptionCard> with TickerProviderStateMixin {
  bool _isProcessing = false;
  String? _errorMessage;

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
                    '\$${widget.price}',
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
              if (widget.subscription?.isTrial == true) ...[
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
              if (widget.subscription?.trialEndsAt != null)
                Text(
                  '${AppLocalizations.of(context).translate('plan_ends')}: ${formatDate(widget.subscription!.trialEndsAt)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              if (widget.subscription?.nextBillingDate != null)
                Text(
                  '${AppLocalizations.of(context).translate('next_billing')}: ${formatDate(widget.subscription!.nextBillingDate)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              Text(
                '${AppLocalizations.of(context).translate('plan_type')}: ${widget.subscription?.planType?.toUpperCase() == 'TRIAL' ? AppLocalizations.of(context).translate('trial') : widget.subscription?.planType?.toUpperCase() ?? 'TRIAL'}',
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
    return AnimatedBuilder(
      animation: _buttonAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonSlideAnimation.value),
          child: Opacity(
            opacity: _buttonFadeAnimation.value,
            child: isPaidSubscription 
              ? _buildEnhancedActiveIndicator()
              : _buildEnhancedSubscribeButton(isActiveTrial),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedActiveIndicator() {
    return Container(
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
    );
  }


  Widget _buildEnhancedSubscribeButton(bool isActiveTrial) {
    Future<void> handleSubscribe() async {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      
      try {
        String productId = widget.subscriptionType == SubscriptionType.yearly 
            ? 'yearly_subscription' 
            : 'monthly_subscription';
        
        final success = await widget.subscriptionProvider.mockPurchaseSubscription(
          productId, 
          widget.packageId
        );
        
        if (!success && mounted) {
          setState(() {
            _errorMessage = widget.subscriptionProvider.errorMessage ?? 
                AppLocalizations.of(context).translate('subscription_failed');
          });
        } else if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).translate('subscription_successful')),
              backgroundColor: Colors.green,
            ),
          );
          
          // Go back to home screen
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } catch (e) {
        debugPrint('❌ Subscription Button: Error: $e');
        if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context).translate('subscription_error');
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
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
                          '${isActiveTrial ? AppLocalizations.of(context).translate('upgrade_now') : AppLocalizations.of(context).translate('subscribe_now')} - \$${widget.price}${widget.period}',
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
}
