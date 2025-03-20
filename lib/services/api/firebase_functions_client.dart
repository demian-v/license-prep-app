import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Maps client-side function names to Cloud Functions names
class FunctionNameMapper {
  static const Map<String, String> _nameMap = {
    // Auth functions
    'loginUser': 'getUserData',
    'registerUser': 'createUserRecord',
    'createOrUpdateUserDocument': 'createOrUpdateUserDocument',
    
    // Content functions
    'getQuizTopics': 'content-getQuizTopics',
    'getQuizQuestions': 'content-getQuizQuestions',
    'getRoadSignCategories': 'content-getRoadSignCategories',
    'getRoadSigns': 'content-getRoadSigns',
    'getTheoryModules': 'content-getTheoryModules',
    'getPracticeTests': 'content-getPracticeTests',
    
    // Progress functions
    'getUserProgress': 'progress-getUserProgress',
    'updateModuleProgress': 'progress-updateModuleProgress',
    'updateTopicProgress': 'progress-updateTopicProgress',
    'updateQuestionProgress': 'progress-updateQuestionProgress',
    'saveTestScore': 'progress-saveTestScore',
    'getSavedItems': 'progress-getSavedItems',
    
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

  // Generic method to call Firebase Functions
  Future<T> callFunction<T>(String functionName, {Map<String, dynamic>? data}) async {
    // Translate the function name using the mapper
    final cloudFunctionName = FunctionNameMapper.getCloudFunctionName(functionName);
    
    try {
      final callable = _functions.httpsCallable(cloudFunctionName);
      final result = await callable.call(data ?? {});
      return result.data as T;
    } on FirebaseFunctionsException catch (e) {
      // Handle specific Firebase Functions errors
      throw '${e.code}: ${e.message}${e.details != null ? " (Details: ${e.details})" : ""}';
    } catch (e) {
      // Handle other errors
      throw 'Error calling function $functionName: $e';
    }
  }
}
