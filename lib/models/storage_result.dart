/// Enum defining different types of storage errors for better error handling
enum StorageErrorType {
  billingRequired,    // Error 412 - Firebase billing upgrade needed
  permissionDenied,   // Error 403 - Insufficient permissions
  networkError,       // Network connectivity issues
  fileNotFound,       // Error 404 - File doesn't exist
  unknown,           // Other/unexpected errors
}

/// Result class for Firebase Storage operations with enhanced error handling
class StorageResult {
  final bool isSuccess;
  final String? url;
  final StorageErrorType? errorType;
  final String? errorMessage;
  final String? userMessage;

  const StorageResult._({
    required this.isSuccess,
    this.url,
    this.errorType,
    this.errorMessage,
    this.userMessage,
  });

  /// Create a successful result with download URL
  factory StorageResult.success(String url) {
    return StorageResult._(
      isSuccess: true,
      url: url,
    );
  }

  /// Create an error result with specific error type and messages
  factory StorageResult.error({
    required StorageErrorType errorType,
    required String errorMessage,
    String? userMessage,
  }) {
    return StorageResult._(
      isSuccess: false,
      errorType: errorType,
      errorMessage: errorMessage,
      userMessage: userMessage ?? _getDefaultUserMessage(errorType),
    );
  }

  /// Get user-friendly message based on error type
  static String _getDefaultUserMessage(StorageErrorType errorType) {
    switch (errorType) {
      case StorageErrorType.billingRequired:
        return "Image temporarily unavailable due to service configuration";
      case StorageErrorType.permissionDenied:
        return "Image access temporarily restricted";
      case StorageErrorType.networkError:
        return "Unable to load image - check your connection";
      case StorageErrorType.fileNotFound:
        return "Image not yet available";
      case StorageErrorType.unknown:
        return "Image temporarily unavailable";
    }
  }

  /// Get console-friendly message for logging
  String get logMessage {
    switch (errorType) {
      case StorageErrorType.billingRequired:
        return "ℹ️ Firebase Storage: Billing upgrade required for image loading";
      case StorageErrorType.permissionDenied:
        return "🔧 Firebase Storage: Insufficient permissions - check service account settings";
      case StorageErrorType.networkError:
        return "📶 Firebase Storage: Network error - $errorMessage";
      case StorageErrorType.fileNotFound:
        return "📁 Firebase Storage: File not found - $errorMessage";
      case StorageErrorType.unknown:
        return "❓ Firebase Storage: Unknown error - $errorMessage";
      case null:
        return "✅ Firebase Storage: Success";
    }
  }

  /// Get appropriate icon for error type
  String get placeholderIconName {
    switch (errorType) {
      case StorageErrorType.billingRequired:
        return "cloud_off";
      case StorageErrorType.permissionDenied:
        return "lock";
      case StorageErrorType.networkError:
        return "wifi_off";
      case StorageErrorType.fileNotFound:
        return "image_not_supported";
      case StorageErrorType.unknown:
        return "broken_image";
      case null:
        return "image";
    }
  }
}
