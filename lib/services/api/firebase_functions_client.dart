import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// Maps client-side function names to Cloud Functions names
class FunctionNameMapper {
  // ⚠️ Risk #21 — SIXTEEN of the names mapped below have NO server-side
  // implementation in functions/src/index.ts. Every call to them throws
  // `not-found`, and the callers swallow it, so the app silently behaves as if
  // the call succeeded:
  //
  //   loginUser, registerUser, getRoadSignCategories, getRoadSigns,
  //   getUserProgress, updateModuleProgress, updateTopicProgress,
  //   updateQuestionProgress, saveTestScore, getSavedItems, addSavedItem,
  //   removeSavedItem, getSubscriptionPlans, getUserSubscription,
  //   subscribeToPlan, applyPromoCode
  //
  // The five progress ones are why cross-device sync does not exist: progress
  // lives only in device-local storage (see ProgressStorage) and is lost with
  // the device. `progress/{uid}` is also rule-denied, so a direct write would
  // fail too.
  //
  // The mappings are kept, not deleted, so implementing a function server-side
  // makes the client work with no further change. Do not assume a name here
  // means the endpoint exists.
  static const Map<String, String> _nameMap = {
    // Auth functions
    'loginUser': 'getUserData',
    'registerUser': 'createUserRecord',
    'createOrUpdateUserDocument': 'createOrUpdateUserDocument',
    'deleteUserAccount': 'deleteUserAccount',
    'updateProfile': 'updateProfile',
    'updateUserLanguage': 'updateUserLanguage',
    'updateUserState': 'updateUserState',
    'getUserData': 'getUserData',
    
    // Content functions
    'getQuizTopics': 'getQuizTopics',
    'getQuizQuestions': 'getQuizQuestions',
    'getPracticeQuestions': 'getPracticeQuestions',
    'getRoadSignCategories': 'getRoadSignCategories',
    'getRoadSigns': 'getRoadSigns',
    'getTheoryModules': 'getTheoryModules',
    'getPracticeTests': 'getPracticeTests',
    
    // Saved Questions functions
    'addSavedQuestion': 'addSavedQuestion',
    'removeSavedQuestion': 'removeSavedQuestion',
    'getSavedQuestions': 'getSavedQuestions',
    'getSavedQuestionsWithContent': 'getSavedQuestionsWithContent',
    
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
        print('🎫 [AUTH DEBUG] Token exists: ${token?.isNotEmpty ?? false}');
        print('🎫 [AUTH DEBUG] Token length: ${token?.length ?? 0}');
        print('🎫 [AUTH DEBUG] Token preview: ${token != null && token.length > 20 ? token.substring(0, 20) : token ?? "null"}...');
        
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

  /// Helper method to safely convert Firebase Functions response data
  /// Handles the conversion from _Map<Object?, Object?> to Map<String, dynamic>
  dynamic _convertResponseData(dynamic data) {
    if (data == null) {
      return null;
    }
    
    if (data is Map<Object?, Object?>) {
      // Convert Map<Object?, Object?> to Map<String, dynamic>
      return Map<String, dynamic>.from(data.map(
        (key, value) => MapEntry(key.toString(), _convertNestedData(value)),
      ));
    }
    
    if (data is List) {
      // Convert List items recursively
      return data.map((item) => _convertResponseData(item)).toList();
    }
    
    // Return primitive types as-is
    return data;
  }

  /// Recursively convert nested data structures
  dynamic _convertNestedData(dynamic value) {
    if (value == null) {
      return null;
    }
    
    if (value is Map<Object?, Object?>) {
      return Map<String, dynamic>.from(value.map(
        (k, v) => MapEntry(k.toString(), _convertNestedData(v)),
      ));
    }
    
    if (value is List) {
      return value.map((item) => _convertNestedData(item)).toList();
    }
    
    return value;
  }

  /// Debug method to analyze response data structure
  void _debugResponseStructure(dynamic data, [String prefix = '']) {
    print('🔍 [RESPONSE DEBUG] $prefix Type: ${data.runtimeType}');
    
    if (data is Map) {
      print('🔍 [RESPONSE DEBUG] $prefix Map keys: ${data.keys.toList()}');
      if (data.isNotEmpty) {
        final firstEntry = data.entries.first;
        print('🔍 [RESPONSE DEBUG] $prefix First key type: ${firstEntry.key.runtimeType}');
        print('🔍 [RESPONSE DEBUG] $prefix First value type: ${firstEntry.value.runtimeType}');
      }
    } else if (data is List) {
      print('🔍 [RESPONSE DEBUG] $prefix List length: ${data.length}');
      if (data.isNotEmpty) {
        print('🔍 [RESPONSE DEBUG] $prefix First item type: ${data.first.runtimeType}');
      }
    }
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
        print('🎫 [FUNCTION DEBUG] New token length: ${token?.length ?? 0}');
        print('🎫 [FUNCTION DEBUG] Token starts with: ${token != null && token.length > 10 ? token.substring(0, 10) : token ?? "null"}...');
      } catch (tokenError) {
        print('❌ [FUNCTION DEBUG] Token refresh failed: $tokenError');
        throw 'Token refresh failed: $tokenError';
      }
      
      // Step 4: Function call with timing and detailed logging
      print('🔄 [FUNCTION DEBUG] Step 3: Calling Firebase Function...');
      print('🎯 [FUNCTION DEBUG] Target function: $cloudFunctionName');
      print('📡 [FUNCTION DEBUG] Firebase Functions instance: ${_functions.toString()}');
      
      final startTime = DateTime.now();
      dynamic result;
      
      try {
        final callable = _functions.httpsCallable(cloudFunctionName);
        print('📞 [FUNCTION DEBUG] Created callable for: $cloudFunctionName');
        
        result = await callable.call(data ?? {});
        
        final duration = DateTime.now().difference(startTime);
        print('✅ [FUNCTION DEBUG] Function call successful in ${duration.inMilliseconds}ms');
        print('📊 [FUNCTION DEBUG] Raw result type: ${result.data.runtimeType}');

        // 🔧 CONVERSION: Convert Firebase Functions response to proper Dart types
        final convertedData = _convertResponseData(result.data);
        print('📊 [FUNCTION DEBUG] Converted result type: ${convertedData.runtimeType}');

        if (convertedData is List) {
          print('📊 [FUNCTION DEBUG] Result list length: ${(convertedData as List).length}');
        } else if (convertedData is Map) {
          print('📊 [FUNCTION DEBUG] Result map keys: ${(convertedData as Map).keys.toList()}');
        }

        return convertedData as T;
        
      } catch (callError) {
        final duration = DateTime.now().difference(startTime);
        print('❌ [FUNCTION DEBUG] Function call failed after ${duration.inMilliseconds}ms');
        
        // Check if it's a conversion error
        if (callError.toString().contains('type') && callError.toString().contains('subtype')) {
          print('🔧 [CONVERSION ERROR] Type conversion issue detected');
          if (result != null) {
            _debugResponseStructure(result.data, '[ERROR] ');
          }
        }
        
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
