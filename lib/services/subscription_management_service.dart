import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user_subscription.dart';
import '../models/subscription_package.dart';
import '../models/user.dart';
import 'billing_calculator.dart';

class SubscriptionManagementService {
  static const int trialDurationDays = 3;
  static const String subscriptionCacheKey = 'user_subscription_cache';
  static const String packagesCacheKey = 'subscription_packages_cache';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = Uuid();

  /// Initialize trial for new user
  Future<UserSubscription> initializeTrial(String userId) async {
    debugPrint('🆓 SubscriptionManagementService: Initializing trial for user: $userId');
    
    try {
      final now = DateTime.now();
      final trialEndsAt = BillingCalculator.calculateTrialEndDate(now);
      
      final subscription = UserSubscription(
        id: _uuid.v4(),
        userId: userId,
        packageId: 3, // Trial package ID from your Firebase subscriptionsType
        status: 'active',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        trialEndsAt: trialEndsAt,
        trialUsed: 0,
        duration: BillingCalculator.TRIAL_DAYS,
        planType: 'trial',
        nextBillingDate: trialEndsAt, // CRITICAL: Must match user.nextBillingDate
      );
      
      // Save to Firebase
      await _saveSubscriptionToFirebase(subscription);
      
      // Save to local cache
      await _saveSubscriptionToCache(subscription);
      
      // Sync billing dates between user and subscription tables
      await _syncUserBillingDates(userId, now, trialEndsAt);
      
      debugPrint('✅ SubscriptionManagementService: Trial initialized successfully');
      debugPrint('📅 Trial ends at: ${trialEndsAt.toIso8601String()}');
      debugPrint('🔄 User and subscription billing dates synchronized');
      
      return subscription;
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error initializing trial: $e');
      throw Exception('Failed to initialize trial: $e');
    }
  }

  /// Check if trial is active for a given subscription
  bool isTrialActive(UserSubscription subscription) {
    if (!subscription.isTrial || subscription.trialUsed == 1) {
      return false;
    }
    
    if (subscription.trialEndsAt == null) {
      return false;
    }
    
    final now = DateTime.now();
    final isActive = now.isBefore(subscription.trialEndsAt!);
    
    debugPrint('🆓 SubscriptionManagementService: Trial active check: $isActive');
    debugPrint('📅 Current time: ${now.toIso8601String()}');
    debugPrint('📅 Trial ends: ${subscription.trialEndsAt!.toIso8601String()}');
    
    return isActive;
  }

  /// Get days remaining in trial
  int getTrialDaysRemaining(UserSubscription subscription) {
    if (!isTrialActive(subscription)) return 0;
    
    final now = DateTime.now();
    final daysRemaining = subscription.trialEndsAt!.difference(now).inDays + 1;
    return daysRemaining > 0 ? daysRemaining : 0;
  }

  /// Convert trial to paid subscription
  Future<UserSubscription> convertTrialToPaid(String userId, int packageId) async {
    debugPrint('💳 SubscriptionManagementService: Converting trial to paid for user: $userId, packageId: $packageId');
    
    try {
      // Get current subscription
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No current subscription found');
      }
      
      // Get the subscription package details
      final packages = await getSubscriptionPackages();
      final selectedPackage = packages.firstWhere(
        (pkg) => pkg.id == packageId,
        orElse: () => throw Exception('Package not found'),
      );
      
      final now = DateTime.now();

      // Calculate next billing date preserving remaining trial days
      // Use trial end date as base to ensure user gets full value of remaining trial
      final nextBillingDate = currentSubscription.trialEndsAt != null
          ? BillingCalculator.calculateTrialToPaidBillingDate(
              currentSubscription.trialEndsAt!,
              selectedPackage.planType,
              currentDate: now,
            )
          : now.add(Duration(days: selectedPackage.duration)); // Fallback for edge cases

      debugPrint('💳 Trial conversion billing calculation:');
      debugPrint('📅 Trial ends at: ${currentSubscription.trialEndsAt?.toIso8601String()}');
      debugPrint('📅 Upgrade date: ${now.toIso8601String()}');
      debugPrint('📅 Next billing date: ${nextBillingDate.toIso8601String()}');
      if (currentSubscription.trialEndsAt != null) {
        final remainingDays = currentSubscription.trialEndsAt!.difference(now).inDays;
        debugPrint('📊 Remaining trial days preserved: $remainingDays');
      }
      
      // Create updated subscription
      final updatedSubscription = currentSubscription.copyWith(
        packageId: packageId,
        status: 'active',
        isActive: true,
        updatedAt: now,
        trialUsed: 1, // Mark trial as used
        duration: selectedPackage.duration,
        planType: selectedPackage.planType,
        nextBillingDate: nextBillingDate,
        // Keep trialEndsAt for historical purposes - do not clear it
      );
      
      // Save to Firebase
      await _saveSubscriptionToFirebase(updatedSubscription);
      
      // Save to local cache
      await _saveSubscriptionToCache(updatedSubscription);
      
      // Sync billing dates between user and subscription tables
      await _syncUserBillingDates(userId, now, nextBillingDate);
      
      debugPrint('✅ SubscriptionManagementService: Trial converted to paid successfully');
      debugPrint('📅 Next billing date: ${nextBillingDate.toIso8601String()}');
      
      return updatedSubscription;
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error converting trial to paid: $e');
      throw Exception('Failed to convert trial to paid: $e');
    }
  }

  /// Get user's current subscription - Enhanced to load expired trials and paid subscriptions
  Future<UserSubscription?> getUserSubscription(String userId) async {
    debugPrint('📋 SubscriptionManagementService: Getting subscription for user: $userId');
    
    try {
      // STEP 1: Try to get active subscription first (preserves current behavior for active users)
      debugPrint('🔍 Step 1: Searching for active subscriptions...');
      final activeQuery = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (activeQuery.docs.isNotEmpty) {
        final doc = activeQuery.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        
        final subscription = UserSubscription.fromJson(data);
        await _saveSubscriptionToCache(subscription);
        
        debugPrint('✅ Found active subscription: ${subscription.planType} (${subscription.status})');
        debugPrint('📅 Next billing: ${subscription.nextBillingDate?.toIso8601String()}');
        return subscription;
      }
      
      // STEP 2: If no active subscription, get most recent subscription (any status)
      // This catches expired trials and expired paid subscriptions
      debugPrint('🔍 Step 2: No active subscription found, searching for any subscription...');
      final anyQuery = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (anyQuery.docs.isNotEmpty) {
        final doc = anyQuery.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        
        final subscription = UserSubscription.fromJson(data);
        await _saveSubscriptionToCache(subscription);
        
        debugPrint('✅ Found subscription: ${subscription.planType} (${subscription.status})');
        if (subscription.isTrial) {
          debugPrint('📅 Trial ends at: ${subscription.trialEndsAt?.toIso8601String()}');
          debugPrint('⏰ Is trial active: ${subscription.isTrialActive}');
        } else {
          debugPrint('📅 Next billing: ${subscription.nextBillingDate?.toIso8601String()}');
          debugPrint('💳 Is paid subscription active: ${subscription.isValidSubscription}');
        }
        return subscription;
      }
      
      // STEP 3: If not found in Firebase, try cache
      debugPrint('ℹ️ No subscription found in Firebase, checking cache');
      return await _getSubscriptionFromCache(userId);
      
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error getting subscription: $e');
      
      // Fallback to cache
      try {
        debugPrint('🔄 Attempting cache fallback...');
        return await _getSubscriptionFromCache(userId);
      } catch (cacheError) {
        debugPrint('❌ SubscriptionManagementService: Cache fallback failed: $cacheError');
        return null;
      }
    }
  }

  /// Get available subscription packages from Firebase
  Future<List<SubscriptionPackage>> getSubscriptionPackages() async {
    debugPrint('📦 SubscriptionManagementService: Getting subscription packages');
    
    try {
      // Try to get from cache first
      final cachedPackages = await _getPackagesFromCache();
      if (cachedPackages.isNotEmpty) {
        debugPrint('✅ SubscriptionManagementService: Packages loaded from cache');
        return cachedPackages;
      }
      
      // Get from Firebase
      final query = await _firestore
          .collection('subscriptionsType')
          .orderBy('id')
          .get();

      debugPrint('📦 SubscriptionManagementService: Processing ${query.docs.length} package documents from Firebase');
      
      final packages = query.docs.map((doc) {
        try {
          final data = doc.data();
          debugPrint('📋 Processing package document: ${doc.id}');
          return SubscriptionPackage.fromJson(data);
        } catch (e) {
          debugPrint('⚠️ SubscriptionManagementService: Skipping malformed package document ${doc.id}: $e');
          return null;
        }
      }).where((pkg) => pkg != null).cast<SubscriptionPackage>().toList();
      
      // Cache the packages
      await _savePackagesToCache(packages);
      
      debugPrint('✅ SubscriptionManagementService: Successfully loaded ${packages.length} valid packages from Firebase');
      if (packages.length != query.docs.length) {
        debugPrint('⚠️ SubscriptionManagementService: ${query.docs.length - packages.length} packages were skipped due to errors');
      }
      return packages;
      
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error getting packages: $e');
      
      // Return cached packages as fallback
      return await _getPackagesFromCache();
    }
  }

  /// Update subscription status (e.g., when billing fails or subscription is canceled)
  /// Enhanced version for SessionManager integration with proper Firebase document handling
  Future<UserSubscription> updateSubscriptionStatus(
    String userId, 
    String status, 
    {bool? isActive}
  ) async {
    debugPrint('🔄 SubscriptionManagementService: Updating subscription status to: $status for user: $userId');
    
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No current subscription found for user: $userId');
      }
      
      final now = DateTime.now();
      final updatedSubscription = currentSubscription.copyWith(
        status: status,
        isActive: isActive ?? (status == 'active'),
        updatedAt: now,
      );
      
      // Enhanced Firebase update - ensure we find and update the correct document
      await _updateSubscriptionInFirebase(updatedSubscription);
      
      // Save to local cache
      await _saveSubscriptionToCache(updatedSubscription);
      
      debugPrint('✅ SubscriptionManagementService: Subscription status updated successfully');
      debugPrint('📊 Status: ${currentSubscription.status} → $status');
      debugPrint('📊 IsActive: ${currentSubscription.isActive} → ${updatedSubscription.isActive}');
      
      return updatedSubscription;
      
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error updating subscription status: $e');
      throw Exception('Failed to update subscription status: $e');
    }
  }

  /// Renew subscription (extend billing period)
  Future<UserSubscription> renewSubscription(String userId) async {
    debugPrint('🔄 SubscriptionManagementService: Renewing subscription for user: $userId');
    
    try {
      final currentSubscription = await getUserSubscription(userId);
      if (currentSubscription == null) {
        throw Exception('No current subscription found');
      }
      
      final now = DateTime.now();
      final newNextBillingDate = (currentSubscription.nextBillingDate ?? now)
          .add(Duration(days: currentSubscription.duration));
      
      final renewedSubscription = currentSubscription.copyWith(
        updatedAt: now,
        nextBillingDate: newNextBillingDate,
        status: 'active',
        isActive: true,
      );
      
      // Save to Firebase
      await _saveSubscriptionToFirebase(renewedSubscription);
      
      // Save to local cache
      await _saveSubscriptionToCache(renewedSubscription);
      
      debugPrint('✅ SubscriptionManagementService: Subscription renewed successfully');
      debugPrint('📅 New next billing date: ${newNextBillingDate.toIso8601String()}');
      
      return renewedSubscription;
      
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error renewing subscription: $e');
      throw Exception('Failed to renew subscription: $e');
    }
  }

  /// Check if subscription is expired
  bool isSubscriptionExpired(UserSubscription subscription) {
    if (subscription.isTrial) {
      return !isTrialActive(subscription);
    }
    
    if (subscription.nextBillingDate == null) return true;
    
    final now = DateTime.now();
    final isExpired = now.isAfter(subscription.nextBillingDate!);
    
    debugPrint('⏰ SubscriptionManagementService: Subscription expired check: $isExpired');
    return isExpired;
  }

  /// Save subscription to Firebase
  Future<void> _saveSubscriptionToFirebase(UserSubscription subscription) async {
    try {
      await _firestore
          .collection('subscriptions')
          .doc(subscription.id)
          .set(subscription.toJson());
      
      debugPrint('💾 SubscriptionManagementService: Subscription saved to Firebase');
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error saving to Firebase: $e');
      throw e;
    }
  }

  /// Save subscription to local cache
  Future<void> _saveSubscriptionToCache(UserSubscription subscription) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(subscription.toCacheJson()); // Use cache-compatible method
      await prefs.setString('${subscriptionCacheKey}_${subscription.userId}', jsonString);
      
      debugPrint('💾 SubscriptionManagementService: Subscription saved to cache');
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error saving to cache: $e');
    }
  }

  /// Get subscription from local cache
  Future<UserSubscription?> _getSubscriptionFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('${subscriptionCacheKey}_$userId');
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final subscription = UserSubscription.fromJson(json);
        
        debugPrint('📱 SubscriptionManagementService: Subscription loaded from cache');
        return subscription;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error loading from cache: $e');
      return null;
    }
  }

  /// Save packages to local cache
  Future<void> _savePackagesToCache(List<SubscriptionPackage> packages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = packages.map((pkg) => pkg.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(packagesCacheKey, jsonString);
      
      debugPrint('💾 SubscriptionManagementService: Packages saved to cache');
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error saving packages to cache: $e');
    }
  }

  /// Get packages from local cache
  Future<List<SubscriptionPackage>> _getPackagesFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(packagesCacheKey);
      
      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        final packages = jsonList
            .map((json) => SubscriptionPackage.fromJson(json as Map<String, dynamic>))
            .toList();
        
        debugPrint('📱 SubscriptionManagementService: ${packages.length} packages loaded from cache');
        return packages;
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error loading packages from cache: $e');
      return [];
    }
  }

  /// Clear cache (useful for logout or data reset)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys that start with our cache prefixes
      final keys = prefs.getKeys().where((key) => 
          key.startsWith(subscriptionCacheKey) || 
          key == packagesCacheKey
      ).toList();
      
      // Remove all subscription-related cache entries
      for (final key in keys) {
        await prefs.remove(key);
      }
      
      debugPrint('🧹 SubscriptionManagementService: Cache cleared');
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error clearing cache: $e');
    }
  }

  /// Synchronize billing dates between user and subscription tables
  /// 
  /// CRITICAL: This ensures user.nextBillingDate = subscription.nextBillingDate
  /// for consistent billing management across the application
  Future<void> _syncUserBillingDates(
    String userId, 
    DateTime lastBillingDate, 
    DateTime nextBillingDate
  ) async {
    try {
      debugPrint('� SubscriptionManagementService: Syncing billing dates for user: $userId');
      debugPrint('📅 Last billing date: ${lastBillingDate.toIso8601String()}');
      debugPrint('📅 Next billing date: ${nextBillingDate.toIso8601String()}');
      
      await _firestore.collection('users').doc(userId).update({
        'lastBillingDate': Timestamp.fromDate(lastBillingDate),
        'nextBillingDate': Timestamp.fromDate(nextBillingDate),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ SubscriptionManagementService: User billing dates synchronized');
    } catch (e) {
      debugPrint('⚠️ SubscriptionManagementService: Error syncing user billing dates: $e');
      // Don't throw error - subscription should still work even if user sync fails
    }
  }

  /// Update subscription in Firebase
  Future<void> _updateSubscriptionInFirebase(UserSubscription subscription) async {
    try {
      final subscriptionData = {
        'status': subscription.status,
        'isActive': subscription.isActive,
        'updatedAt': Timestamp.fromDate(subscription.updatedAt),
      };
      
      // Find subscription document by userId
      final querySnapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: subscription.userId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        await _firestore
            .collection('subscriptions')
            .doc(docId)
            .update(subscriptionData);
        
        debugPrint('✅ SubscriptionManagementService: Firebase subscription updated');
      } else {
        throw Exception('Subscription document not found for user: ${subscription.userId}');
      }
      
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Firebase update failed: $e');
      rethrow;
    }
  }

  /// Validate billing date synchronization between user and subscription
  /// 
  /// This method helps detect and fix any inconsistencies between
  /// user.nextBillingDate and subscription.nextBillingDate
  Future<bool> validateBillingSynchronization(String userId) async {
    try {
      debugPrint('� SubscriptionManagementService: Validating billing sync for user: $userId');
      
      // Get user billing dates
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ User document not found');
        return false;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final userNextBilling = userData['nextBillingDate'] != null 
          ? (userData['nextBillingDate'] as Timestamp).toDate()
          : null;
      
      // Get subscription billing dates
      final subscription = await getUserSubscription(userId);
      if (subscription == null) {
        debugPrint('⚠️ Subscription not found');
        return false;
      }
      
      // Check if dates are in sync using BillingCalculator
      final isInSync = BillingCalculator.areBillingDatesInSync(
        userNextBilling, 
        subscription.nextBillingDate
      );
      
      debugPrint('🔍 Billing sync validation result: $isInSync');
      debugPrint('📅 User nextBillingDate: ${userNextBilling?.toIso8601String()}');
      debugPrint('📅 Subscription nextBillingDate: ${subscription.nextBillingDate?.toIso8601String()}');
      
      // If not in sync, fix it
      if (!isInSync && subscription.nextBillingDate != null) {
        debugPrint('🔧 Fixing billing date sync...');
        await _syncUserBillingDates(
          userId,
          DateTime.now(),
          subscription.nextBillingDate!,
        );
        debugPrint('✅ Billing dates have been synchronized');
        return true;
      }
      
      return isInSync;
    } catch (e) {
      debugPrint('❌ SubscriptionManagementService: Error validating billing sync: $e');
      return false;
    }
  }
}
