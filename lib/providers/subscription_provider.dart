import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '../models/user_subscription.dart';
import '../models/subscription_package.dart';
import '../services/subscription_management_service.dart';

class SubscriptionProvider extends ChangeNotifier {
  // STATE MANAGEMENT
  UserSubscription? _subscription;
  List<SubscriptionPackage>? _packages;
  bool _isLoading = false;
  String? _errorMessage;
  
  // CACHE MANAGEMENT
  int? _cachedTrialDaysRemaining;
  DateTime? _cacheTimestamp;
  
  // SERVICES
  final SubscriptionManagementService _subscriptionService = SubscriptionManagementService();
  
  // GETTERS
  UserSubscription? get subscription => _subscription;
  List<SubscriptionPackage>? get packages => _packages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // TRIAL STATUS
  bool get isTrialActive {
    final result = _subscription?.isTrialActive ?? false;
    debugPrint('🆓 SubscriptionProvider.isTrialActive: $result');
    debugPrint('📋 Current subscription: ${_subscription?.planType ?? 'null'}');
    debugPrint('📅 Trial ends at: ${_subscription?.trialEndsAt?.toIso8601String() ?? 'null'}');
    debugPrint('🔄 Subscription status: ${_subscription?.status ?? 'null'}');
    debugPrint('✅ Is active: ${_subscription?.isActive ?? false}');
    return result;
  }
  
  int get trialDaysRemaining {
    final now = DateTime.now();
    
    // Invalidate cache if it's from a different day (since days remaining can change daily)
    if (_cachedTrialDaysRemaining != null && _cacheTimestamp != null) {
      final cacheAge = now.difference(_cacheTimestamp!);
      if (cacheAge.inHours >= 1) {  // Refresh every hour to catch day changes
        _clearTrialCache();
      }
    }
    
    // Return cached value if available
    if (_cachedTrialDaysRemaining != null) {
      return _cachedTrialDaysRemaining!;
    }
    
    // Calculate and cache the value
    _cachedTrialDaysRemaining = _subscription?.trialDaysRemaining ?? 0;
    _cacheTimestamp = now;
    debugPrint('📅 SubscriptionProvider.trialDaysRemaining: $_cachedTrialDaysRemaining (calculated and cached)');
    
    return _cachedTrialDaysRemaining!;
  }
  
  bool get hasValidSubscription => _subscription?.isValidSubscription ?? false;
  
  // Check if user has an expired trial (trial exists but is no longer active)
  bool get hasExpiredTrial {
    // Trial is expired if:
    // 1. Plan type is 'trial' AND
    // 2. Either (status is 'inactive' OR (isActive is true but trial time has expired))
    final result = _subscription?.planType == 'trial' && 
                   (_subscription?.status == 'inactive' || 
                   (_subscription?.isActive == true && !isTrialActive));
    debugPrint('⏰ SubscriptionProvider.hasExpiredTrial: $result');
    debugPrint('   - Plan type: ${_subscription?.planType}');
    debugPrint('   - Status: ${_subscription?.status}');
    debugPrint('   - Is active: ${_subscription?.isActive}');
    debugPrint('   - Trial time active: $isTrialActive');
    return result;
  }
  
  // Check if user has an expired paid subscription
  bool get hasExpiredPaidSubscription {
    if (_subscription == null) return false;
    
    // Expired paid subscription: not a trial AND (status inactive OR past billing date)
    final isExpiredPaid = !_subscription!.isTrial && 
                         (_subscription!.status == 'inactive' || 
                          (_subscription!.nextBillingDate != null && 
                           DateTime.now().isAfter(_subscription!.nextBillingDate!)));
    
    debugPrint('💳 SubscriptionProvider.hasExpiredPaidSubscription: $isExpiredPaid');
    debugPrint('   - Is trial: ${_subscription!.isTrial}');
    debugPrint('   - Status: ${_subscription!.status}');
    debugPrint('   - Plan type: ${_subscription!.planType}');
    debugPrint('   - Next billing: ${_subscription!.nextBillingDate?.toIso8601String()}');
    
    return isExpiredPaid;
  }
  
  // SUBSCRIPTION STATUS (for backward compatibility)
  bool get isSubscriptionActive => hasValidSubscription;
  int get trialDaysLeft => trialDaysRemaining; // For backward compatibility

  // CONSTRUCTOR
  SubscriptionProvider();

  // INITIALIZATION
  Future<void> initialize(String userId) async {
    debugPrint('🔄 SubscriptionProvider: Initializing for user: $userId');
    _setLoading(true);
    try {
      await _loadPackages();
      await _loadUserSubscriptionWithRetry(userId);
      
      // Enhanced validation and logging
      if (_subscription != null) {
        debugPrint('✅ SubscriptionProvider: Loaded subscription: ${_subscription!.planType} (${_subscription!.status})');
        
        if (_subscription!.isTrial) {
          debugPrint('📅 Trial ends at: ${_subscription!.trialEndsAt?.toIso8601String()}');
          debugPrint('⏰ Trial active: ${_subscription!.isTrialActive}');
          debugPrint('🔄 Has expired trial: $hasExpiredTrial');
        } else {
          debugPrint('📅 Next billing: ${_subscription!.nextBillingDate?.toIso8601String()}');
          debugPrint('💳 Has valid paid subscription: $hasValidSubscription');
          debugPrint('💳 Has expired paid subscription: $hasExpiredPaidSubscription');
        }
      } else {
        debugPrint('⚠️ SubscriptionProvider: No subscription found for user - this should not happen!');
      }
      
      debugPrint('✅ SubscriptionProvider: Initialized successfully');
    } catch (e) {
      debugPrint('❌ SubscriptionProvider: Initialization error: $e');
      _setError('Failed to initialize: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Add retry logic method
  Future<void> _loadUserSubscriptionWithRetry(String userId, {int maxRetries = 2}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _subscription = await _subscriptionService.getUserSubscription(userId);
        _clearTrialCache();
        debugPrint('📋 SubscriptionProvider: Loaded subscription on attempt $attempt');
        notifyListeners();
        return;
      } catch (e) {
        debugPrint('❌ SubscriptionProvider: Attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          throw e;
        }
        await Future.delayed(Duration(seconds: attempt)); // Progressive delay
      }
    }
  }

  // LOAD SUBSCRIPTION PACKAGES
  Future<void> _loadPackages() async {
    try {
      _packages = await _subscriptionService.getSubscriptionPackages();
      debugPrint('📦 SubscriptionProvider: Loaded ${_packages?.length ?? 0} packages');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ SubscriptionProvider: Error loading packages: $e');
    }
  }

  // LOAD USER SUBSCRIPTION
  Future<void> _loadUserSubscription(String userId) async {
    try {
      _subscription = await _subscriptionService.getUserSubscription(userId);
      _clearTrialCache(); // Clear cache when subscription data changes
      debugPrint('📋 SubscriptionProvider: Loaded subscription: ${_subscription?.planType ?? 'none'}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ SubscriptionProvider: Error loading user subscription: $e');
    }
  }

  // MOCK PURCHASE SUBSCRIPTION (for testing without real payments)
  Future<bool> subscribe({String? paymentMethodId, String userId = ''}) async {
    return await mockPurchaseSubscription('monthly_subscription', 1);
  }

  Future<bool> mockPurchaseSubscription(String productId, int packageId) async {
    debugPrint('🛒 SubscriptionProvider: Mock purchase - Product: $productId, Package: $packageId');
    _setLoading(true);
    _clearError();
    
    try {
      // Simulate network delay
      await Future.delayed(Duration(seconds: 2));
      
      // Simulate 90% success rate for testing
      if (Random().nextDouble() < 0.9) {
        if (_subscription != null) {
          debugPrint('💳 SubscriptionProvider: Converting trial to paid subscription');
          _subscription = await _subscriptionService.convertTrialToPaid(
            _subscription!.userId, 
            packageId
          );
          _clearTrialCache(); // Clear cache when subscription changes
          notifyListeners();
          debugPrint('✅ SubscriptionProvider: Mock purchase successful');
          return true;
        } else {
          _setError('No subscription found to convert');
          return false;
        }
      } else {
        _setError('Mock purchase failed (simulated 10% failure rate)');
        return false;
      }
    } catch (e) {
      debugPrint('❌ SubscriptionProvider: Purchase error: $e');
      _setError('Purchase error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // CANCEL SUBSCRIPTION - Updated to use dedicated service method
  Future<bool> cancelSubscription(String userId) async {
    debugPrint('❌ SubscriptionProvider: Canceling subscription for user: $userId');
    _setLoading(true);
    try {
      if (_subscription != null) {
        _subscription = await _subscriptionService.cancelSubscription(userId);
        _clearTrialCache(); // Clear cache when subscription changes
        notifyListeners();
        debugPrint('✅ SubscriptionProvider: Subscription canceled successfully');
        return true;
      } else {
        _setError('No subscription found to cancel');
        return false;
      }
    } catch (e) {
      debugPrint('❌ SubscriptionProvider: Failed to cancel: $e');
      _setError('Failed to cancel: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // CHECK SUBSCRIPTION STATUS
  Future<void> checkSubscriptionStatus(String userId) async {
    debugPrint('🔍 SubscriptionProvider: Checking subscription status for user: $userId');
    try {
      await _loadUserSubscription(userId);
    } catch (e) {
      debugPrint('❌ SubscriptionProvider: Failed to check subscription status: $e');
    }
  }

  // REFRESH SUBSCRIPTION DATA
  Future<void> refreshSubscription(String userId) async {
    debugPrint('🔄 SubscriptionProvider: Refreshing subscription data');
    await initialize(userId);
  }

  // STATE MANAGEMENT HELPERS
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // CACHE MANAGEMENT HELPERS
  void _clearTrialCache() {
    _cachedTrialDaysRemaining = null;
    _cacheTimestamp = null;
    debugPrint('🗑️ SubscriptionProvider: Trial cache cleared');
  }

  // Get package by ID
  SubscriptionPackage? getPackageById(int packageId) {
    if (_packages == null) return null;
    try {
      return _packages!.firstWhere((pkg) => pkg.id == packageId);
    } catch (e) {
      return null;
    }
  }

  // Get formatted next billing date
  String? get nextBillingDateFormatted {
    if (_subscription?.nextBillingDate == null) return null;
    final date = _subscription!.nextBillingDate!;
    return '${date.month}/${date.day}/${date.year}';
  }

  // Get formatted trial end date
  String? get trialEndDateFormatted {
    if (_subscription?.trialEndsAt == null) return null;
    final date = _subscription!.trialEndsAt!;
    return '${date.month}/${date.day}/${date.year}';
  }

  // Check if subscription is canceled but still active
  bool get isCanceledButActive {
    return _subscription?.status == 'canceled' && _subscription?.isActive == true;
  }

  // Get days remaining until canceled subscription expires
  int get daysUntilCanceledExpiry {
    if (!isCanceledButActive || _subscription?.nextBillingDate == null) return 0;
    
    final now = DateTime.now();
    final daysRemaining = _subscription!.nextBillingDate!.difference(now).inDays + 1;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  // Get formatted expiry date for canceled subscription
  String? get canceledExpiryDateFormatted {
    if (!isCanceledButActive || _subscription?.nextBillingDate == null) return null;
    final date = _subscription!.nextBillingDate!;
    return '${date.month}/${date.day}/${date.year}';
  }
}
