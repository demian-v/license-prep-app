import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

class InAppPurchaseService {
  static const String monthlyProductId = 'monthly';
  static const String yearlyProductId = 'yearly';
  
  // All product IDs registered in App Store Connect / Play Console.
  // Kept for future use — yearly can be re-enabled here when needed.
  static const List<String> productIds = [
    monthlyProductId,
    yearlyProductId,
  ];

  // Products currently offered and supported in the UI.
  // Restored or auto-renewed transactions for products NOT in this set are
  // silently completed (to clear StoreKit's queue) but NOT sent to the backend.
  // This prevents old yearly receipts from StoreKit history being validated
  // after yearly was removed from the UI, which caused "Product 'yearly' not
  // found in receipt" errors and unnecessary Firebase function calls.
  static const Set<String> _activeProductIds = {monthlyProductId};

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _isRestoringPurchases = false;
  Timer? _restoreSessionTimer;

  // In-session deduplication: tracks purchaseIDs already sent to
  // validatePurchaseReceipt this session. Prevents redundant Firebase function
  // calls when StoreKit re-delivers the same unfinished transaction multiple
  // times on app launch (sandbox behaviour in particular).
  final Set<String> _processedPurchaseIds = {};

  // Concurrency guard: only one validation may be in flight at a time.
  // In sandbox, Apple accelerates subscription renewals to every 5 minutes, so
  // after 1 hour there may be 12+ pending renewal receipts in StoreKit's queue.
  // Each has a DIFFERENT transaction_id → _processedPurchaseIds doesn't catch
  // them. When restorePurchases() delivers all 12 simultaneously, without this
  // flag they all fire concurrent Firebase calls and exhaust the rate limit.
  // With this flag, only the first validation runs; the other 11 still call
  // completePurchase() to clear StoreKit's queue but skip Firebase.
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

      // Enable pending purchases on Android
      if (Platform.isAndroid) {
        InAppPurchaseAndroidPlatformAddition.enablePendingPurchases();
        debugPrint('✅ InAppPurchaseService: Enabled pending purchases on Android');
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

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (result) {
        debugPrint('✅ InAppPurchaseService: Purchase initiated successfully');
        return true;
      } else {
        debugPrint('❌ InAppPurchaseService: Failed to initiate purchase');
        _purchasePending = false;
        onPurchaseError?.call('Failed to initiate purchase');
        return false;
      }
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Purchase error: $e');
      _purchasePending = false;
      onPurchaseError?.call('Purchase error: $e');
      return false;
    }
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
          break;
        
        case PurchaseStatus.purchased:
          debugPrint('✅ Purchase successful: ${purchaseDetails.productID}');
          if (_purchasePending) {
            // User explicitly initiated this purchase — always process,
            // bypassing the _isValidating concurrency guard.
            _handleSuccessfulPurchase(purchaseDetails, isUserInitiated: true);
          } else if (_activeProductIds.contains(purchaseDetails.productID)) {
            // Apple auto-renewal: StoreKit delivers the renewed subscription
            // receipt automatically when the app is foregrounded after a renewal
            // has occurred. We must process it so nextBillingDate gets updated
            // in Firestore and the app correctly reflects the active subscription.
            // Only active products are processed — inactive ones (e.g. yearly)
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
            if (_activeProductIds.contains(purchaseDetails.productID)) {
              // Only validate currently-offered products. Old purchases (e.g.
              // yearly) are in StoreKit history but should not be sent to the
              // backend since they are no longer in the active product set.
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
    _purchasePending = false;

    // Concurrency guard: only one validation in flight at a time.
    // In sandbox, Apple delivers many renewal receipts simultaneously (each
    // with a different transaction_id). Without this guard they all reach
    // Firebase concurrently and exhaust the rate limit.
    // User-initiated purchases bypass this guard so they are always processed.
    if (!isUserInitiated && _isValidating) {
      debugPrint('⚠️ InAppPurchaseService: Validation already in progress — '
          'skipping concurrent receipt for ${purchaseDetails.productID}/'
          '${purchaseDetails.purchaseID} (StoreKit delivered multiple renewals at once)');
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
        _isValidating = false;
        return;
      }
      _processedPurchaseIds.add(purchaseId);
    }

    // Validate receipt with backend
    _validateReceipt(purchaseDetails).then((isValid) {
      _isValidating = false;
      if (isValid) {
        debugPrint('✅ InAppPurchaseService: Receipt validated successfully');
        onPurchaseSuccess?.call(purchaseDetails.productID);
      } else {
        debugPrint('❌ InAppPurchaseService: Receipt validation failed');
        onPurchaseError?.call('Receipt validation failed');
      }
    }).catchError((error) {
      _isValidating = false;
      // BUG FIX: Call error callback when validation throws an exception
      debugPrint('❌ InAppPurchaseService: Receipt validation error: $error');
      onPurchaseError?.call('Receipt validation error: ${error.toString()}');
    });
  }

  /// Handle purchase error
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    _purchasePending = false;
    final errorMessage = purchaseDetails.error?.message ?? 'Unknown purchase error';
    onPurchaseError?.call(errorMessage);
  }

  /// Handle purchase cancellation
  void _handlePurchaseCanceled(PurchaseDetails purchaseDetails) {
    _purchasePending = false;
    onPurchaseCanceled?.call(purchaseDetails.productID);
  }

  /// Validate receipt with backend
  Future<bool> _validateReceipt(PurchaseDetails purchaseDetails) async {
    try {
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
      }
      
      return isValid;
      
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Receipt validation error: $e');
      // Log error details for debugging
      if (e is FirebaseFunctionsException) {
        debugPrint('🔴 Firebase Functions Error: ${e.code} - ${e.message}');
        debugPrint('🔴 Details: ${e.details}');
      }
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
