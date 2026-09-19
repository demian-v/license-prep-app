import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/auth_provider.dart';
import '../services/in_app_purchase_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/enhanced_subscription_card.dart';
import '../models/subscription.dart';

class SubscriptionScreen extends StatefulWidget {
  @override
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Run after the first frame so Provider.of is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPurchaseCallback();
    });
  }

  /// Registers the IAP success callback so the subscription card refreshes
  /// after a purchase or renewal is processed.
  ///
  /// NOTE: We intentionally do NOT call checkAndAutoRestoreIfNeeded() here.
  /// home_screen.dart already triggers it once per app launch. Calling it
  /// here too caused repeated restores every time the user opened the
  /// Subscription screen, which hit the Firebase rate limit (10 calls/hour)
  /// and attempted to validate old yearly receipts from StoreKit history.
  Future<void> _setupPurchaseCallback() async {
    if (!mounted) return;

    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final iapService = Provider.of<InAppPurchaseService>(context, listen: false);

    // Refresh subscription data in the UI after a purchase/renewal completes.
    iapService.onPurchaseSuccess = (productId) async {
      debugPrint('🔄 SubscriptionScreen: Purchase/renewal processed ($productId) — refreshing');
      if (mounted && authProvider.user != null) {
        await subscriptionProvider.refreshSubscription(authProvider.user!.id);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: true);
    final subscription = subscriptionProvider.subscription;
    // Needed for the store-reported price below. `listen: false` — the price
    // is read once per build and nothing here should rebuild on it.
    final iapService =
        Provider.of<InAppPurchaseService>(context, listen: false);

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
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: EnhancedSubscriptionCard(
            subscriptionType: SubscriptionType.monthly,
            // The store is authoritative for money, exactly as the server is
            // for entitlement (#48) and Apple is for the receipt (#56).
            // `ProductDetails.price` is already formatted for the customer's
            // storefront — "$9.99", "11,99 US$", "£7.99" — and was being
            // ignored in favour of a literal, which misquotes everyone outside
            // the storefront that literal was written for.
            //
            // The fallback is only reachable before `queryProductDetails` has
            // returned, or with the store unavailable — in which case no
            // purchase is possible anyway.
            price: iapService
                    .getProduct(InAppPurchaseService.monthlyProductId)
                    ?.price ??
                r'$9.99',
            period: AppLocalizations.of(context).translate('per_month'),
            subscription: subscription,
            subscriptionProvider: subscriptionProvider,
            packageId: 1, // Monthly package ID from Firebase
            showBestValue: false,
            // Use the real subscription status instead of hardcoded true.
            // This ensures the card correctly shows "Subscribe" when the
            // subscription is inactive/canceled/expired, and "You're subscribed!"
            // only when the user actually has a valid active subscription.
            isActive: subscriptionProvider.hasValidSubscription,
          ),
        ),
      ),
    );
  }
}
