import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(data ?? {});
      return result.data as T;
    } catch (e) {
      // Handle errors appropriately
      rethrow;
    }
  }
}
