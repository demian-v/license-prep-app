import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with TickerProviderStateMixin {
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

  final List<String> _features = [
    'Unlimited access to all license materials',
    'Full practice test suite',
    'Progress tracking',
    'Performance analytics',
  ];

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
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Colors.purple.shade50.withOpacity(0.3)],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for pricing section
  LinearGradient _getPricingGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.purple.shade50, Colors.blue.shade50.withOpacity(0.5)],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for subscribe button
  LinearGradient _getButtonGradient(bool isActive) {
    if (isActive) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.green.shade400, Colors.green.shade600],
        stops: [0.0, 1.0],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.purple.shade400, Colors.blue.shade500],
        stops: [0.0, 1.0],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final subscription = subscriptionProvider.subscription;
    
    final isActive = subscription.isActive && subscription.nextBillingDate != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Subscription',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade50.withOpacity(0.3),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8),
              
              // Enhanced subscription card
              _buildEnhancedSubscriptionCard(isActive, subscription, subscriptionProvider),
              
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSubscriptionCard(bool isActive, subscription, SubscriptionProvider subscriptionProvider) {
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
                      'USA License Prep Premium',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    
                    // Enhanced pricing section
                    _buildEnhancedPricingSection(subscription),
                    
                    SizedBox(height: 24),
                    
                    // Features section
                    Text(
                      'Features Include:',
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
                    _buildEnhancedActionArea(isActive, subscriptionProvider),
                    
                    SizedBox(height: 12),
                    
                    // Fine print
                    Text(
                      'Your subscription will automatically renew each month until canceled.',
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

  Widget _buildEnhancedPricingSection(subscription) {
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
            color: Colors.purple.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '\$2.50',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
              Text(
                '/month',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (subscription.trialEndsAt != null)
            Text(
              'Trial Ends: ${formatDate(subscription.trialEndsAt)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          if (subscription.nextBillingDate != null)
            Text(
              'Next Billing: ${formatDate(subscription.nextBillingDate)}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          Text(
            'Plan Type: ${subscription.planType.toUpperCase()}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFeaturesList() {
    return Column(
      children: _features.asMap().entries.map((entry) {
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
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              color: Colors.white,
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
          colors: [Colors.red.shade50, Colors.red.shade100.withOpacity(0.5)],
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

  Widget _buildEnhancedActionArea(bool isActive, SubscriptionProvider subscriptionProvider) {
    return AnimatedBuilder(
      animation: _buttonAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonSlideAnimation.value),
          child: Opacity(
            opacity: _buttonFadeAnimation.value,
            child: isActive 
              ? _buildEnhancedActiveIndicator()
              : _buildEnhancedSubscribeButton(subscriptionProvider),
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
          colors: [Colors.green.shade100, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
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
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, color: Colors.white, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You\'re subscribed! Enjoy full access to all content.',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSubscribeButton(SubscriptionProvider subscriptionProvider) {
    Future<void> handleSubscribe() async {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      
      try {
        final success = await subscriptionProvider.subscribe();
        
        if (!success && mounted) {
          setState(() {
            _errorMessage = 'Subscription failed. Please try again.';
          });
        } else if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Subscription successful!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Go back to licenses screen
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'An error occurred. Please try again.';
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
                color: Colors.purple.withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 8,
                offset: Offset(0, 4),
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
                          'Subscribe Now - \$2.50/month',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
