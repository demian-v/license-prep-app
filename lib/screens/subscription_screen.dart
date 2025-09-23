import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../localization/app_localizations.dart';
import '../widgets/enhanced_subscription_card.dart';
import '../models/subscription.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _indicatorAnimationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _indicatorAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _indicatorAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final subscription = subscriptionProvider.subscription;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('subscription'),
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50.withOpacity(0.2),
            ],
          ),
        ),
        child: Column(
          children: [
            // Page View with subscription cards
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // Yearly Subscription Card (Page 0 - Default)
                  SingleChildScrollView(
                    padding: EdgeInsets.all(16.0),
                    child: EnhancedSubscriptionCard(
                      subscriptionType: SubscriptionType.yearly,
                      price: "79.99",
                      period: AppLocalizations.of(context).translate('per_year'),
                      subscription: subscription,
                      subscriptionProvider: subscriptionProvider,
                      packageId: 2, // Yearly package ID from Firebase
                      showBestValue: true,
                    ),
                  ),
                  // Monthly Subscription Card (Page 1)
                  SingleChildScrollView(
                    padding: EdgeInsets.all(16.0),
                    child: EnhancedSubscriptionCard(
                      subscriptionType: SubscriptionType.monthly,
                      price: "9.99",
                      period: AppLocalizations.of(context).translate('per_month'),
                      subscription: subscription,
                      subscriptionProvider: subscriptionProvider,
                      packageId: 1, // Monthly package ID from Firebase
                      showBestValue: false,
                    ),
                  ),
                ],
              ),
            ),
            
            // Page indicators
            _buildPageIndicators(),
            
            // Swipe hint text
            _buildSwipeHint(),
            
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIndicatorDot(0),
          SizedBox(width: 12),
          _buildIndicatorDot(1),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.orange.shade600 : Colors.grey.shade300,
        boxShadow: isActive ? [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ] : null,
      ),
    );
  }

  Widget _buildSwipeHint() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: Text(
        _currentPage == 0
            ? AppLocalizations.of(context).translate('swipe_to_see_monthly')
            : AppLocalizations.of(context).translate('swipe_to_see_yearly'),
        key: ValueKey(_currentPage),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
