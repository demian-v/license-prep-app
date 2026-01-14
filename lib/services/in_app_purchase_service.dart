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
  
  // Product IDs that match your Firebase subscriptionsType and App Store Connect
  static const List<String> productIds = [
    monthlyProductId,
    yearlyProductId,
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;

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
      await _inAppPurchase.restorePurchases();
      debugPrint('✅ InAppPurchaseService: Restore purchases initiated');
    } catch (e) {
      debugPrint('❌ InAppPurchaseService: Restore purchases error: $e');
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
          _handleSuccessfulPurchase(purchaseDetails);
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
          _handleSuccessfulPurchase(purchaseDetails);
          break;
      }

      // Complete the purchase if it's not pending
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    _purchasePending = false;
    
    // Validate receipt with backend (you should implement this)
    _validateReceipt(purchaseDetails).then((isValid) {
      if (isValid) {
        debugPrint('✅ InAppPurchaseService: Receipt validated successfully');
        onPurchaseSuccess?.call(purchaseDetails.productID);
      } else {
        debugPrint('❌ InAppPurchaseService: Receipt validation failed');
        onPurchaseError?.call('Receipt validation failed');
      }
    }).catchError((error) {
      debugPrint('❌ InAppPurchaseService: Receipt validation error: $error');
      // Still call success callback as the purchase was successful from the store
      onPurchaseSuccess?.call(purchaseDetails.productID);
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
      
      // Call Firebase function to validate receipt
      final callable = FirebaseFunctions.instance.httpsCallable('validatePurchaseReceipt');
      
      final result = await callable.call({
        'receipt': receipt,
        'platform': platform,
        'productId': purchaseDetails.productID,
      });
      
      // Parse response from backend
      final data = result.data as Map<String, dynamic>;
      final isValid = data['valid'] == true;
      
      if (isValid) {
        final subscriptionId = data['subscriptionId'] ?? 'unknown';
        final expiresAt = data['expiresAt'] ?? 'unknown';
        debugPrint('✅ Receipt validated successfully!');
        debugPrint('📦 Subscription ID: $subscriptionId');
        debugPrint('⏰ Expires at: $expiresAt');
      } else {
        final message = data['message'] ?? 'Validation failed';
        debugPrint('❌ Receipt validation failed: $message');
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
