import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Maps client-side function names to Cloud Functions names
class FunctionNameMapper {
  static const Map<String, String> _nameMap = {
    // Auth functions
    'loginUser': 'getUserData',
    'registerUser': 'createUserRecord',
    'createOrUpdateUserDocument': 'createOrUpdateUserDocument',
    
    // Content functions
    'getQuizTopics': 'getQuizTopics',
    'getQuizQuestions': 'getQuizQuestions',
    'getPracticeQuestions': 'getPracticeQuestions',
    'getRoadSignCategories': 'getRoadSignCategories',
    'getRoadSigns': 'getRoadSigns',
    'getTheoryModules': 'getTheoryModules',
    'getPracticeTests': 'getPracticeTests',
    
    // Progress functions
    'getUserProgress': 'progress-getUserProgress',
    'updateModuleProgress': 'progress-updateModuleProgress',
    'updateTopicProgress': 'progress-updateTopicProgress',
    'updateQuestionProgress': 'progress-updateQuestionProgress',
    'saveTestScore': 'progress-saveTestScore',
    'getSavedItems': 'progress-getSavedItems',
    'addSavedItem': 'progress-addSavedItem',
    'removeSavedItem': 'progress-removeSavedItem',
    
    // Subscription functions
    'getSubscriptionPlans': 'subscription-getSubscriptionPlans',
    'getUserSubscription': 'subscription-getUserSubscription',
    'subscribeToPlan': 'subscription-subscribeToPlan',
    'cancelSubscription': 'subscription-cancelSubscription',
    'applyPromoCode': 'subscription-applyPromoCode',
  };
  
  /// Translates a client-side function name to the corresponding Cloud Function name
  static String getCloudFunctionName(String clientFunctionName) {
    final cloudName = _nameMap[clientFunctionName];
    if (cloudName != null) {
      debugPrint('Mapping function name: $clientFunctionName -> $cloudName');
      return cloudName;
    }
    
    // If no mapping exists, use the original name
    debugPrint('No mapping found for function: $clientFunctionName, using as-is');
    return clientFunctionName;
  }
}

class FirebaseFunctionsClient {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final String _authTokenKey = 'auth_token';

  // Token Management (similar to ApiClient)
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: _authTokenKey);
  }

  Future<void> setAuthToken(String token) async {
    await _secureStorage.write(key: _authTokenKey, value: token);
  }

  Future<void> clearAuthToken() async {
    await _secureStorage.delete(key: _authTokenKey);
  }

  /// Enhanced debugging for authentication flow
  Future<void> _debugAuthenticationState() async {
    print('🔍 [AUTH DEBUG] Starting authentication state analysis...');
    
    final auth = firebase_auth.FirebaseAuth.instance;
    
    // 1. Current user state
    print('👤 [AUTH DEBUG] Current user: ${auth.currentUser?.uid ?? "NULL"}');
    print('📧 [AUTH DEBUG] User email: ${auth.currentUser?.email ?? "NULL"}');
    print('🔐 [AUTH DEBUG] Is anonymous: ${auth.currentUser?.isAnonymous ?? "NULL"}');
    print('⏰ [AUTH DEBUG] Creation time: ${auth.currentUser?.metadata.creationTime ?? "NULL"}');
    print('🔄 [AUTH DEBUG] Last sign in: ${auth.currentUser?.metadata.lastSignInTime ?? "NULL"}');
    
    // 2. Token state
    try {
      if (auth.currentUser != null) {
        final token = await auth.currentUser!.getIdToken(false);
        print('🎫 [AUTH DEBUG] Token exists: ${token.isNotEmpty}');
        print('🎫 [AUTH DEBUG] Token length: ${token.length}');
        print('🎫 [AUTH DEBUG] Token preview: ${token.length > 20 ? token.substring(0, 20) : token}...');
        
        // Try to get claims
        final result = await auth.currentUser!.getIdTokenResult();
        print('🏷️ [AUTH DEBUG] Token claims: ${result.claims?.keys.toList() ?? "NULL"}');
        print('📅 [AUTH DEBUG] Token issued at: ${result.issuedAtTime ?? "NULL"}');
        print('⏰ [AUTH DEBUG] Token expires at: ${result.expirationTime ?? "NULL"}');
      } else {
        print('🎫 [AUTH DEBUG] No user - cannot get token');
      }
    } catch (e) {
      print('❌ [AUTH DEBUG] Token retrieval failed: $e');
    }
    
    // 3. Network and Firebase status
    print('🌐 [AUTH DEBUG] Firebase app name: ${auth.app.name}');
    print('🌐 [AUTH DEBUG] Firebase project ID: ${auth.app.options.projectId}');
    print('🌐 [AUTH DEBUG] Auth state changes stream: ${auth.authStateChanges != null}');
  }

  /// Categorize error types for better debugging
  String _categorizeError(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('internal: INTERNAL')) {
      return 'AUTHENTICATION_FAILURE';
    } else if (errorStr.contains('unauthenticated')) {
      return 'TOKEN_INVALID';
    } else if (errorStr.contains('permission-denied')) {
      return 'PERMISSION_ISSUE';
    } else if (errorStr.contains('deadline-exceeded')) {
      return 'TIMEOUT_ERROR';
    } else if (errorStr.contains('not-found')) {
      return 'FUNCTION_NOT_FOUND';
    } else if (errorStr.contains('invalid-argument')) {
      return 'INVALID_PARAMETERS';
    }
    return 'UNKNOWN_ERROR';
  }

  // Enhanced method to call Firebase Functions with comprehensive debugging
  Future<T> callFunction<T>(String functionName, {Map<String, dynamic>? data}) async {
    print('\n🚀 [FUNCTION DEBUG] Starting function call: $functionName');
    print('📦 [FUNCTION DEBUG] Data: $data');
    
    // Translate the function name using the mapper
    final cloudFunctionName = FunctionNameMapper.getCloudFunctionName(functionName);
    print('🔄 [FUNCTION DEBUG] Mapped function name: $functionName -> $cloudFunctionName');
    
    try {
      // Step 1: Authentication debugging
      await _debugAuthenticationState();
      
      // Step 2: User validation with recovery
      print('🔄 [FUNCTION DEBUG] Step 1: Validating Firebase Auth user...');
      final auth = firebase_auth.FirebaseAuth.instance;
      
      if (auth.currentUser == null) {
        print('⚠️ [FUNCTION DEBUG] No user detected, attempting anonymous sign-in...');
        try {
          await auth.signInAnonymously();
          print('✅ [FUNCTION DEBUG] Anonymous sign-in successful');
          await _debugAuthenticationState(); // Re-check after sign-in
        } catch (signInError) {
          print('❌ [FUNCTION DEBUG] Anonymous sign-in failed: $signInError');
          throw 'Authentication failed: Unable to sign in anonymously - $signInError';
        }
      } else {
        print('✅ [FUNCTION DEBUG] User already authenticated: ${auth.currentUser!.uid}');
        print('🔍 [FUNCTION DEBUG] User type: ${auth.currentUser!.isAnonymous ? "Anonymous" : "Registered"}');
      }
      
      // Step 3: Token refresh with detailed logging
      print('🔄 [FUNCTION DEBUG] Step 2: Refreshing token...');
      try {
        final token = await auth.currentUser!.getIdToken(true);
        print('✅ [FUNCTION DEBUG] Token refresh successful');
        print('🎫 [FUNCTION DEBUG] New token length: ${token.length}');
        print('🎫 [FUNCTION DEBUG] Token starts with: ${token.length > 10 ? token.substring(0, 10) : token}...');
      } catch (tokenError) {
        print('❌ [FUNCTION DEBUG] Token refresh failed: $tokenError');
        throw 'Token refresh failed: $tokenError';
      }
      
      // Step 4: Function call with timing and detailed logging
      print('🔄 [FUNCTION DEBUG] Step 3: Calling Firebase Function...');
      print('🎯 [FUNCTION DEBUG] Target function: $cloudFunctionName');
      print('📡 [FUNCTION DEBUG] Firebase Functions instance: ${_functions.toString()}');
      
      final startTime = DateTime.now();
      
      try {
        final callable = _functions.httpsCallable(cloudFunctionName);
        print('📞 [FUNCTION DEBUG] Created callable for: $cloudFunctionName');
        
        final result = await callable.call(data ?? {});
        
        final duration = DateTime.now().difference(startTime);
        print('✅ [FUNCTION DEBUG] Function call successful in ${duration.inMilliseconds}ms');
        print('📊 [FUNCTION DEBUG] Result type: ${result.data.runtimeType}');
        
        if (result.data is List) {
          print('📊 [FUNCTION DEBUG] Result list length: ${(result.data as List).length}');
        } else if (result.data is Map) {
          print('📊 [FUNCTION DEBUG] Result map keys: ${(result.data as Map).keys.toList()}');
        }
        
        return result.data as T;
        
      } catch (callError) {
        final duration = DateTime.now().difference(startTime);
        print('❌ [FUNCTION DEBUG] Function call failed after ${duration.inMilliseconds}ms');
        rethrow;
      }
      
    } on FirebaseFunctionsException catch (e) {
      print('❌ [FUNCTION DEBUG] Firebase Functions Exception Details:');
      print('   🔍 Error Code: ${e.code}');
      print('   💬 Error Message: ${e.message}');
      print('   📋 Error Details: ${e.details}');
      print('   🏷️ Error Category: ${_categorizeError(e)}');
      
      // Enhanced error message
      final errorMsg = '${e.code}: ${e.message}${e.details != null ? " (Details: ${e.details})" : ""}';
      print('🚨 [FUNCTION DEBUG] Final error message: $errorMsg');
      throw errorMsg;
      
    } catch (e, stackTrace) {
      print('❌ [FUNCTION DEBUG] General Exception Details:');
      print('   🔍 Error Type: ${e.runtimeType}');
      print('   💬 Error Message: $e');
      print('   🏷️ Error Category: ${_categorizeError(e)}');
      print('   📍 Stack Trace: $stackTrace');
      
      // Enhanced error message
      final errorMsg = 'Error calling function $functionName: $e';
      print('🚨 [FUNCTION DEBUG] Final error message: $errorMsg');
      throw errorMsg;
    }
  }
}
