import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'crash_reporter.dart';

class InAppPurchaseService {
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  
  // Products this app OFFERS. Only the 30-day plan is sold (owner decision
  // 2026-09-16), so yearly is not queried from the store and cannot be
  // presented in the UI.
  static const List<String> productIds = [
    monthlyProductId,
  ];

  // Products whose transactions are forwarded to the backend for validation
  // (risk #6).
  //
  // This is deliberately a SUPERSET of productIds. It previously equalled
  // {monthly}, so a restored or auto-renewed `yearly` transaction was
  // completePurchase()-ed to clear StoreKit's queue and never sent to the
  // backend — the user had paid and received nothing. Dropping a receipt is
  // never the safe default; the backend still accepts `yearly`
  // (receipt-validation PRODUCT_IDS) precisely so a legacy or in-flight
  // purchase can still be honoured.
  //
  // Yearly is here as a legacy safety net only. It is not offered above, and
  // the SKU is being withdrawn from App Store Connect and Play Console.
  static const Set<String> validatableProductIds = {
    monthlyProductId,
    yearlyProductId,
  };

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  // Tracks which product the user explicitly initiated a purchase for.
  // Prevents old pending renewal events (same or different product) from
  // stealing _purchasePending and leaving the UI stuck in a loading state.
  String? _pendingProductId;
  // Safety-net timeout: if no purchase event arrives within 60s of the user
  // tapping Subscribe, re-enable the UI. It does NOT report an error — see the
  // note at the timer itself.
  Timer? _purchasePendingTimeoutTimer;
  bool _isRestoringPurchases = false;
  Timer? _restoreSessionTimer;

  // In-session deduplication: tracks purchaseIDs already sent to
  // validatePurchaseReceipt this session. Prevents redundant Firebase function
  // calls when StoreKit re-delivers the same unfinished transaction multiple
  // times on app launch (sandbox behaviour in particular).
  final Set<String> _processedPurchaseIds = {};

  // Receipts that arrived while a validation was in flight. Drained one at a
  // time by [_onValidationSettled]. Exists because dropping them loses
  // renewals Apple has already billed — see the guard in
  // _handleSuccessfulPurchase.
  final List<PurchaseDetails> _validationQueue = [];

  // Concurrency guard: only one validation may be in flight at a time.
  // In sandbox, Apple accelerates subscription renewals to every 5 minutes, so
  // after 1 hour there may be 12+ pending renewal receipts in StoreKit's queue.
  // Each has a DIFFERENT transaction_id → _processedPurchaseIds doesn't catch
  // them. When restorePurchases() delivers all 12 simultaneously, without this
  // flag they all fire concurrent Firebase calls and exhaust the rate limit.
  // With this flag, only the first validation runs at a time; the rest go to
  // [_validationQueue] and are drained one by one. They used to be DROPPED,
  // which silently lost renewals Apple had already billed (device run,
  // 2026-09-19). Serialising was the part worth keeping.
  bool _isValidating = false;

  // Callbacks for purchase events
  void Function(String productId)? onPurchaseSuccess;
  void Function(String error)? onPurchaseError;
  void Function(String productId)? onPurchaseCanceled;

  /// Initialize the in-app purchase service
  Future<bool> initialize() async {
    debugPrint('🛒 InAppPurchaseService: Initializing...');
    
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      
      if (!_isAvailable) {
        debugPrint('❌ InAppPurchaseService: Store is not available');
        return false;
      }

      // Set up purchase stream listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => debugPrint('🛒 InAppPurchaseService: Purchase stream done'),
        onError: (error) => debugPrint('❌ InAppPurchaseService: Purchase stream error: $error'),
      );

      // Load products
      await _loadProducts();

      debugPrint('✅ InAppPurchaseService: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Initialization error: $e');
      return false;
    }
  }

  /// Load available products from the store
  Future<void> _loadProducts() async {
    debugPrint('🛒 InAppPurchaseService: Loading products...');
    
    try {
      final response = await _inAppPurchase.queryProductDetails(productIds.toSet());
      
      if (response.error != null) {
        debugPrint('❌ InAppPurchaseService: Error loading products: ${response.error}');
        return;
      }

      _products = response.productDetails;
      debugPrint('✅ InAppPurchaseService: Loaded ${_products.length} products');
      
      for (final product in _products) {
        debugPrint('📦 Product: ${product.id} - ${product.title} - ${product.price}');
      }

      // Handle any not found IDs
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ InAppPurchaseService: Products not found: ${response.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Error loading products: $e');
    }
  }

  /// Get available products
  List<ProductDetails> getProducts() => _products;

  /// Get a specific product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      debugPrint('⚠️ InAppPurchaseService: Product $productId not found');
      return null;
    }
  }

  /// Check if store is available
  bool get isAvailable => _isAvailable;

  /// Check if a purchase is currently pending
  bool get isPurchasePending => _purchasePending;

  /// Purchase a product
  Future<bool> purchaseProduct(String productId) async {
    if (!_isAvailable) {
      debugPrint('❌ InAppPurchaseService: Store is not available');
      onPurchaseError?.call('Store is not available');
      return false;
    }

    if (_purchasePending) {
      debugPrint('⚠️ InAppPurchaseService: Purchase already pending');
      onPurchaseError?.call('Purchase already in progress');
      return false;
    }

    final product = getProduct(productId);
    if (product == null) {
      debugPrint('❌ InAppPurchaseService: Product $productId not found');
      onPurchaseError?.call('Product not found');
      return false;
    }

    debugPrint('🛒 InAppPurchaseService: Starting purchase for ${product.id}');
    _purchasePending = true;
    _pendingProductId = productId;

    // Safety net: if StoreKit never delivers a purchase event (e.g. race
    // condition where an old renewal steals the flag), re-enable the UI so it
    // cannot strand in a loading state.
    //
    // It does NOT report a failure, and that is the point. Observed on a real
    // device 2026-09-19: this fired at 60s while Apple's payment sheet was
    // still open, said "Purchase timed out. Please try again.", and the
    // purchase then completed and validated. The customer was told a purchase
    // they had paid for had failed, and invited to buy it twice.
    //
    // No fixed deadline can be correct here. The App Store sheet is open-ended
    // — password, 2FA, Apple's "Terms and Conditions have changed"
    // interstitial, a slow sandbox — and under Family Sharing **Ask to Buy** a
    // purchase legitimately stays pending for days awaiting a parent. The
    // purchase stream is the source of truth; this timer only unsticks the UI.
    _purchasePendingTimeoutTimer?.cancel();
    _purchasePendingTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (_purchasePending) {
        debugPrint(
          '⏱️ InAppPurchaseService: no purchase event after 60s — re-enabling '
          'the UI. The purchase may still be in progress; the stream decides.',
        );
        _clearPurchasePending();
      }
    });

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (result) {
        debugPrint('✅ InAppPurchaseService: Purchase initiated successfully');
        return true;
      } else {
        debugPrint('❌ InAppPurchaseService: Failed to initiate purchase');
        _clearPurchasePending();
        onPurchaseError?.call('Failed to initiate purchase');
        return false;
      }
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Purchase error: $e');
      _clearPurchasePending();
      onPurchaseError?.call('Purchase error: $e');
      return false;
    }
  }

  /// Clears the purchase-pending state and cancels the safety-net timeout.
  void _clearPurchasePending() {
    _purchasePending = false;
    _pendingProductId = null;
    _purchasePendingTimeoutTimer?.cancel();
    _purchasePendingTimeoutTimer = null;
  }

  /// Restore purchases (iOS)
  Future<void> restorePurchases() async {
    if (!_isAvailable) {
      debugPrint('❌ InAppPurchaseService: Store is not available for restore');
      return;
    }

    debugPrint('🔄 InAppPurchaseService: Restoring purchases...');
    
    try {
      _isRestoringPurchases = true;
      
      // StoreKit delivers all restored transactions asynchronously one by one.
      // We keep the flag true for 10 seconds so every restored event in the
      // same session is treated as user-initiated, even if there are multiple
      // products. The timer is cancelled and restarted on each restored event
      // to extend the window as long as events keep coming.
      _restoreSessionTimer?.cancel();
      _restoreSessionTimer = Timer(Duration(seconds: 10), () {
        debugPrint('⏱️ InAppPurchaseService: Restore session window closed');
        _isRestoringPurchases = false;
        _restoreSessionTimer = null;
      });

      await _inAppPurchase.restorePurchases();
      debugPrint('✅ InAppPurchaseService: Restore purchases initiated');
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Restore purchases error: $e');
      _isRestoringPurchases = false;
      _restoreSessionTimer?.cancel();
      _restoreSessionTimer = null;
    }
  }

  /// Handle purchase updates from the stream
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    debugPrint('🛒 InAppPurchaseService: Received ${purchaseDetailsList.length} purchase updates');
    
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint('📱 Purchase update: ${purchaseDetails.productID} - ${purchaseDetails.status}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          debugPrint('⏳ Purchase pending: ${purchaseDetails.productID}');
          // Apple has confirmed this purchase is genuinely in flight, so the
          // safety net has nothing left to protect against and must not
          // outlive it. This is also where Family Sharing's **Ask to Buy**
          // sits: the answer can be days away, and the UI keeps its pending
          // state until the stream says otherwise.
          if (purchaseDetails.productID == _pendingProductId) {
            _purchasePendingTimeoutTimer?.cancel();
            _purchasePendingTimeoutTimer = null;
          }
          break;
        
        case PurchaseStatus.purchased:
          debugPrint('✅ Purchase successful: ${purchaseDetails.productID}');
          if (_purchasePending && purchaseDetails.productID == _pendingProductId) {
            // Correct product confirmed — this is the user-initiated purchase.
            // Bypass _isValidating so it's never blocked by a concurrent renewal.
            _handleSuccessfulPurchase(purchaseDetails, isUserInitiated: true);
          } else if (validatableProductIds.contains(purchaseDetails.productID)) {
            // Apple auto-renewal: StoreKit delivers the renewed subscription
            // receipt automatically when the app is foregrounded after a renewal
            // has occurred. We must process it so nextBillingDate gets updated
            // in Firestore and the app correctly reflects the active subscription.
            // Anything the backend can validate is processed (risk #6)
            // are skipped to avoid "product not found in receipt" errors.
            debugPrint('🔄 InAppPurchaseService: Apple auto-renewal receipt for '
                '${purchaseDetails.productID} — processing to update billing date');
            _handleSuccessfulPurchase(purchaseDetails);
          } else {
            // Non-subscription product delivered without user action — ignore.
            debugPrint('⚠️ InAppPurchaseService: Received purchased event without a '
                'pending purchase (auto-delivered by StoreKit for unknown product) — ignoring');
          }
          break;
        
        case PurchaseStatus.error:
          debugPrint('❌ Purchase error: ${purchaseDetails.productID} - ${purchaseDetails.error}');
          _handlePurchaseError(purchaseDetails);
          break;
        
        case PurchaseStatus.canceled:
          debugPrint('❌ Purchase canceled: ${purchaseDetails.productID}');
          _handlePurchaseCanceled(purchaseDetails);
          break;
        
        case PurchaseStatus.restored:
          debugPrint('🔄 Purchase restored: ${purchaseDetails.productID}');
          // FIXED: Only process a restore if the user explicitly tapped "Restore Purchases".
          // StoreKit automatically re-delivers restored transactions on every app start.
          // Without this guard, opening the Subscriptions screen after those events arrive
          // (and callbacks get registered) causes a phantom "purchase" to complete.
          if (_isRestoringPurchases) {
            if (validatableProductIds.contains(purchaseDetails.productID)) {
              // Forward anything the backend can validate, including a legacy
              // yearly purchase sitting in StoreKit history (risk #6). Silently
              // completing those is what left a paying user with nothing.
              _handleSuccessfulPurchase(purchaseDetails);
            } else {
              debugPrint('⚠️ InAppPurchaseService: Skipping restore for '
                  'non-active product ${purchaseDetails.productID} — completing silently');
            }
            // Extend the restore session window on every arriving event so that
            // all products in the same batch get handled correctly.
            _restoreSessionTimer?.cancel();
            _restoreSessionTimer = Timer(Duration(seconds: 10), () {
              debugPrint('⏱️ InAppPurchaseService: Restore session window closed');
              _isRestoringPurchases = false;
              _restoreSessionTimer = null;
            });
          } else {
            debugPrint('⚠️ InAppPurchaseService: Auto-restored transaction from StoreKit '
                '(no user action) - completing silently');
          }
          break;
      }

      // Complete the purchase if it's not pending
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase.
  ///
  /// [isUserInitiated] – true when the user explicitly tapped "Subscribe" or
  /// "Buy". User-initiated purchases bypass the [_isValidating] concurrency
  /// guard so they are never silently dropped, even if a background restore
  /// is already in flight.
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails,
      {bool isUserInitiated = false}) {
    if (isUserInitiated) _clearPurchasePending();

    // Concurrency guard: only one validation in flight at a time.
    // In sandbox, Apple delivers many renewal receipts simultaneously (each
    // with a different transaction_id). Without this guard they all reach
    // Firebase concurrently and exhaust the rate limit.
    // User-initiated purchases bypass this guard so they are always processed.
    if (!isUserInitiated && _isValidating) {
      // QUEUE, do not drop. Dropping here loses renewals Apple has already
      // billed: on a device 2026-09-19, 11 events arrived at once and five
      // DISTINCT transaction ids were discarded, leaving nextBillingDate
      // behind what had actually been charged.
      //
      // The guard itself stays — serialising is the point. Its call site in
      // SubscriptionProvider.checkAndAutoRestoreIfNeeded exists because a
      // burst of concurrent validations exhausts the backend rate limit.
      // One at a time, but none thrown away.
      final queuedId = purchaseDetails.purchaseID ?? '';
      final alreadyKnown = queuedId.isNotEmpty &&
          (_processedPurchaseIds.contains(queuedId) ||
              _validationQueue
                  .any((p) => (p.purchaseID ?? '') == queuedId));
      if (alreadyKnown) {
        // StoreKit redelivers unfinished transactions repeatedly; without this
        // the queue would grow on every redelivery.
        debugPrint('⚠️ InAppPurchaseService: Receipt $queuedId already '
            'processed or queued — not re-queuing');
        return;
      }
      _validationQueue.add(purchaseDetails);
      debugPrint('⏳ InAppPurchaseService: Validation in progress — queued '
          '${purchaseDetails.productID}/${purchaseDetails.purchaseID} '
          '(${_validationQueue.length} waiting)');
      return;
    }
    _isValidating = true;

    // In-session deduplication: skip if this exact purchase was already sent to
    // the Firebase function this session. StoreKit can re-deliver the same
    // unfinished transaction many times before we call completePurchase(), so
    // without this guard each re-delivery triggers a redundant Firebase call.
    // The backend has its own idempotency guard (by transactionId), but avoiding
    // the call altogether is cheaper.
    final purchaseId = purchaseDetails.purchaseID ?? '';
    if (purchaseId.isNotEmpty) {
      if (_processedPurchaseIds.contains(purchaseId)) {
        debugPrint('⚠️ InAppPurchaseService: Purchase $purchaseId already processed '
            'this session — skipping duplicate Firebase call');
        _onValidationSettled();
        return;
      }
      _processedPurchaseIds.add(purchaseId);
    }

    // Validate receipt with backend
    _validateReceipt(purchaseDetails).then((isValid) {
      if (isValid) {
        debugPrint('✅ InAppPurchaseService: Receipt validated successfully');
        onPurchaseSuccess?.call(purchaseDetails.productID);
      } else {
        debugPrint('❌ InAppPurchaseService: Receipt validation failed');
        onPurchaseError?.call('Receipt validation failed');
      }
      _onValidationSettled();
    }).catchError((error) {
      // BUG FIX: Call error callback when validation throws an exception
      debugPrint('❌ InAppPurchaseService: Receipt validation error: $error');
      onPurchaseError?.call('Receipt validation error: ${error.toString()}');
      _onValidationSettled();
    });
  }

  /// Releases the concurrency guard and starts the next queued receipt.
  ///
  /// Strictly one at a time: the guard exists because a burst of concurrent
  /// validations exhausts the backend rate limit, so draining must never fan
  /// out. A failed validation still drains — the next receipt is a different
  /// transaction and deserves its own attempt.
  void _onValidationSettled() {
    _isValidating = false;
    if (_validationQueue.isEmpty) return;
    final next = _validationQueue.removeAt(0);
    debugPrint('▶️ InAppPurchaseService: Draining queued receipt '
        '${next.productID}/${next.purchaseID} '
        '(${_validationQueue.length} still waiting)');
    _handleSuccessfulPurchase(next);
  }

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    _clearPurchasePending();
    final errorMessage = purchaseDetails.error?.message ?? 'Unknown purchase error';
    onPurchaseError?.call(errorMessage);
  }

  /// Handle purchase cancellation
  void _handlePurchaseCanceled(PurchaseDetails purchaseDetails) {
    _clearPurchasePending();
    onPurchaseCanceled?.call(purchaseDetails.productID);
  }

  /// Validate receipt with backend
  Future<bool> _validateReceipt(PurchaseDetails purchaseDetails) async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        debugPrint('⚠️ InAppPurchaseService: Skipping receipt validation — no Firebase user signed in '
            '(likely StoreKit replay on cold start). Apple/Google webhook keeps server state in sync.');
        return true;
      }

      debugPrint('🔐 InAppPurchaseService: Validating receipt for ${purchaseDetails.productID}');
      
      // Get receipt data and platform
      String receipt;
      String platform;
      
      if (Platform.isAndroid) {
        platform = 'android';
        // Android: Get purchase token from verification data
        receipt = purchaseDetails.verificationData.serverVerificationData;
        debugPrint('📱 Android receipt token: ${receipt.substring(0, 20)}...');
      } else if (Platform.isIOS) {
        platform = 'ios';
        // iOS: Get receipt data from verification data
        receipt = purchaseDetails.verificationData.serverVerificationData;
        debugPrint('🍎 iOS receipt data length: ${receipt.length} chars');
      } else {
        debugPrint('❌ Unsupported platform');
        return false;
      }
      
      debugPrint('📡 Calling Firebase function: validatePurchaseReceipt');
      debugPrint('📤 Request payload: platform=$platform, productId=${purchaseDetails.productID}');
      
      // Call Firebase function to validate receipt
      final callable = FirebaseFunctions.instance.httpsCallable('validatePurchaseReceipt');
      
      final result = await callable.call({
        'receipt': receipt,
        'platform': platform,
        'productId': purchaseDetails.productID,
      });
      
      // Parse response from backend
      debugPrint('📥 Firebase function response received');
      debugPrint('📋 Response type: ${result.data.runtimeType}');
      debugPrint('📋 Response data: ${result.data}');
      
      final data = result.data as Map<String, dynamic>;
      final isValid = data['valid'] == true;
      
      debugPrint('🔍 Parsed valid field: $isValid');
      
      if (isValid) {
        final subscriptionId = data['subscriptionId'] ?? 'unknown';
        final expiresAt = data['expiresAt'] ?? 'unknown';
        final productId = data['productId'] ?? 'unknown';
        final platform = data['platform'] ?? 'unknown';
        
        debugPrint('✅ Receipt validated successfully!');
        debugPrint('📦 Subscription ID: $subscriptionId');
        debugPrint('⏰ Expires at: $expiresAt');
        debugPrint('📦 Product ID: $productId');
        debugPrint('📱 Platform: $platform');
      } else {
        final message = data['message'] ?? 'Validation failed';
        debugPrint('❌ Receipt validation failed: $message');
        debugPrint('📋 Full response: $data');

        // The store has ALREADY charged the customer by the time this runs, and
        // the two debugPrints above are dropped in release builds (#34) — so
        // without this a paying customer who receives nothing produces no
        // signal anywhere. A non-fatal, not a crash: the app recovers, the
        // money does not.
        //
        // The receipt itself is deliberately NOT attached. It is a bearer
        // credential for the subscription (#5) and a diagnostics system is not
        // the place for one.
        crashReporter.recordNonFatal(
          ReceiptValidationRejected(message.toString()),
          StackTrace.current,
          reason: 'receipt_validation_rejected',
          keys: {
            'receipt_platform': platform,
            'receipt_product_id': purchaseDetails.productID,
          },
        );
      }
      
      return isValid;
      
    } catch (e, stack) {
      debugPrint('❌ InAppPurchaseService: Receipt validation error: $e');
      // Log error details for debugging
      if (e is FirebaseFunctionsException) {
        debugPrint('🔴 Firebase Functions Error: ${e.code} - ${e.message}');
        debugPrint('🔴 Details: ${e.details}');
      }

      // Same reasoning as the rejection path above, different failure: the
      // call did not complete at all. Kept as a SEPARATE reason so the two do
      // not group into one Crashlytics issue — "the server said no" and "we
      // could not ask" have different causes and different fixes.
      //
      // `code` is the useful discriminator here: `permission-denied` is the #5
      // receipt-binding guard refusing a receipt already bound to another
      // account, which is abuse, not a bug. `resource-exhausted` is the #19
      // rate limit. `unavailable` is usually the customer's network.
      crashReporter.recordNonFatal(
        e,
        stack,
        reason: 'receipt_validation_error',
        keys: {
          'receipt_product_id': purchaseDetails.productID,
          'functions_code': e is FirebaseFunctionsException ? e.code : 'not_a_functions_error',
        },
      );
      return false;
    }
  }

  /// Get formatted price for a product
  String getFormattedPrice(String productId) {
    final product = getProduct(productId);
    return product?.price ?? 'N/A';
  }

  /// Get product title
  String getProductTitle(String productId) {
    final product = getProduct(productId);
    return product?.title ?? productId;
  }

  /// Get product description
  String getProductDescription(String productId) {
    final product = getProduct(productId);
    return product?.description ?? '';
  }

  /// Check if a product is available
  bool isProductAvailable(String productId) {
    return getProduct(productId) != null;
  }

  /// Dispose resources
  void dispose() {
    debugPrint('🛒 InAppPurchaseService: Disposing...');
    _subscription?.cancel();
    _subscription = null;
    _restoreSessionTimer?.cancel();
    _restoreSessionTimer = null;
    _processedPurchaseIds.clear();
    _isValidating = false;
  }

  /// Set purchase callbacks
  void setPurchaseCallbacks({
    void Function(String productId)? onSuccess,
    void Function(String error)? onError,
    void Function(String productId)? onCanceled,
  }) {
    onPurchaseSuccess = onSuccess;
    onPurchaseError = onError;
    onPurchaseCanceled = onCanceled;
  }
}

/// The server completed receipt validation and answered that the receipt is
/// **not** valid — as distinct from the call failing, which arrives as
/// whatever exception the Functions SDK threw.
///
/// A named type rather than a bare string so the Crashlytics issue is titled
/// `ReceiptValidationRejected` instead of being grouped with every other
/// `_Exception`. It is never thrown: it exists to be recorded.
class ReceiptValidationRejected implements Exception {
  ReceiptValidationRejected(this.serverMessage);

  /// The server's own `message` field. Safe to attach — it is our text, not
  /// the customer's receipt.
  final String serverMessage;

  @override
  String toString() => 'ReceiptValidationRejected: $serverMessage';
}
