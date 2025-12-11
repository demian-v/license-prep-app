import 'dart:io';
import 'dart:collection';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/storage_result.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Cache downloaded URLs to avoid unnecessary downloads
  final Map<String, String> _urlCache = {};
  
  /// Track usage order for LRU cache management
  final Queue<String> _cacheOrder = Queue<String>();
  
  /// Maximum number of cached entries
  final int _maxCacheEntries = 200;
  
  /// Track logged errors to prevent spam
  final Set<String> _loggedErrors = {};
  
  /// Track if billing error has been logged this session
  bool _billingErrorLogged = false;
  
  /// Add to cache with size management (LRU strategy)
  void _addToCache(String key, String value) {
    // Remove oldest entry if cache is full
    if (_cacheOrder.length >= _maxCacheEntries) {
      final oldestKey = _cacheOrder.removeFirst();
      _urlCache.remove(oldestKey);
    }
    
    // Add new entry
    _urlCache[key] = value;
    _cacheOrder.add(key);
  }
  
  /// Get download URL for a file in Firebase Storage with enhanced error handling
  Future<StorageResult> getDownloadURL(String path) async {
    // Return cached URL if available
    if (_urlCache.containsKey(path)) {
      // Move to end of queue (mark as recently used)
      _cacheOrder.remove(path);
      _cacheOrder.add(path);
      return StorageResult.success(_urlCache[path]!);
    }
    
    try {
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      
      // Cache the URL with LRU management
      _addToCache(path, url);
      
      return StorageResult.success(url);
    } on FirebaseException catch (e) {
      return _handleFirebaseError(e, path);
    } catch (e) {
      return _handleGenericError(e, path);
    }
  }

  /// Handle Firebase-specific errors with proper categorization
  StorageResult _handleFirebaseError(FirebaseException e, String path) {
    final errorCode = e.code;
    final errorMessage = e.message ?? 'Unknown Firebase error';
    
    StorageErrorType errorType;
    
    // Categorize error based on Firebase error code
    switch (errorCode) {
      case 'storage/object-not-found':
        errorType = StorageErrorType.fileNotFound;
        break;
      case 'storage/unauthorized':
        errorType = StorageErrorType.permissionDenied;
        break;
      case 'storage/unknown':
        // Check for billing error in the message
        if (errorMessage.contains('service account') || 
            errorMessage.contains('permissions') ||
            errorMessage.contains('412')) {
          errorType = StorageErrorType.billingRequired;
        } else {
          errorType = StorageErrorType.unknown;
        }
        break;
      default:
        errorType = StorageErrorType.unknown;
    }
    
    final result = StorageResult.error(
      errorType: errorType,
      errorMessage: errorMessage,
    );
    
    // Smart logging to prevent spam
    if (_shouldLogError(errorType, path)) {
      print(result.logMessage);
      if (errorType == StorageErrorType.billingRequired) {
        print('📱 Image placeholders enabled - app functionality maintained');
      }
    }
    
    return result;
  }

  /// Handle generic (non-Firebase) errors
  StorageResult _handleGenericError(dynamic e, String path) {
    final errorMessage = e.toString();
    StorageErrorType errorType;
    
    // Try to categorize generic errors
    if (errorMessage.toLowerCase().contains('network') ||
        errorMessage.toLowerCase().contains('connection') ||
        errorMessage.toLowerCase().contains('timeout')) {
      errorType = StorageErrorType.networkError;
    } else {
      errorType = StorageErrorType.unknown;
    }
    
    final result = StorageResult.error(
      errorType: errorType,
      errorMessage: errorMessage,
    );
    
    // Log generic errors (but prevent spam)
    if (_shouldLogError(errorType, path)) {
      print(result.logMessage);
    }
    
    return result;
  }

  /// Determine if an error should be logged (prevents spam)
  bool _shouldLogError(StorageErrorType errorType, String path) {
    switch (errorType) {
      case StorageErrorType.billingRequired:
        // Log billing error only once per session
        if (_billingErrorLogged) return false;
        _billingErrorLogged = true;
        return true;
      
      case StorageErrorType.permissionDenied:
        // Log permission errors once per session
        final key = 'permission_error';
        if (_loggedErrors.contains(key)) return false;
        _loggedErrors.add(key);
        return true;
      
      case StorageErrorType.fileNotFound:
        // Don't spam for missing files, but log occasionally
        final key = 'file_not_found_$path';
        if (_loggedErrors.contains(key)) return false;
        _loggedErrors.add(key);
        return _loggedErrors.length % 10 == 1; // Log every 10th missing file
      
      case StorageErrorType.networkError:
        // Log network errors but limit frequency
        final key = 'network_error';
        if (_loggedErrors.contains(key)) return false;
        _loggedErrors.add(key);
        return true;
      
      case StorageErrorType.unknown:
        // Log unknown errors for debugging
        return true;
    }
  }
  
  /// Clear the URL cache
  void clearCache() {
    _urlCache.clear();
    _cacheOrder.clear();
  }
  
  /// Create an image widget that loads from Firebase Storage with enhanced error handling
  Widget getImage({
    required String storagePath, 
    String? assetFallback,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain, // Changed default from BoxFit.cover to prevent cropping
    Color? placeholderColor,
    IconData placeholderIcon = Icons.image,
  }) {
    return FutureBuilder<StorageResult>(
      future: getDownloadURL(storagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator(width, height);
        }
        
        if (snapshot.hasData) {
          final result = snapshot.data!;
          
          if (result.isSuccess && result.url != null) {
            // Success: Load image from Firebase Storage
            return CachedNetworkImage(
              imageUrl: result.url!,
              width: width,
              height: height,
              fit: fit,
              placeholder: (context, url) => _buildLoadingIndicator(width, height),
              errorWidget: (context, url, error) {
                // If network image fails, try asset fallback
                if (assetFallback != null) {
                  return Image.asset(
                    assetFallback,
                    width: width,
                    height: height,
                    fit: fit,
                    errorBuilder: (context, error, stackTrace) => 
                        _buildEnhancedErrorPlaceholder(StorageErrorType.networkError, width, height),
                  );
                }
                return _buildEnhancedErrorPlaceholder(StorageErrorType.networkError, width, height);
              },
            );
          } else {
            // Firebase Storage failed, try asset fallback first
            if (assetFallback != null) {
              return Image.asset(
                assetFallback,
                width: width,
                height: height,
                fit: fit,
                errorBuilder: (context, error, stackTrace) => 
                    _buildEnhancedErrorPlaceholder(result.errorType!, width, height),
              );
            }
            
            // No asset fallback, show enhanced error placeholder
            return _buildEnhancedErrorPlaceholder(result.errorType!, width, height);
          }
        }
        
        // Connection error or other issue - try asset fallback
        if (assetFallback != null) {
          return Image.asset(
            assetFallback,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => 
                _buildEnhancedErrorPlaceholder(StorageErrorType.unknown, width, height),
          );
        }
        
        // Final fallback - show error placeholder
        return _buildEnhancedErrorPlaceholder(StorageErrorType.unknown, width, height);
      },
    );
  }
  
  /// Build a loading indicator
  Widget _buildLoadingIndicator(double? width, double? height) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  /// Build a placeholder container with an icon
  Widget _buildPlaceholder(double? width, double? height, Color? color, IconData icon) {
    return Container(
      width: width,
      height: height,
      color: color ?? Colors.grey[300],
      child: Center(
        child: Icon(
          icon,
          size: (width != null && height != null) ? 
            (width < height ? width / 2 : height / 2) : 50,
          color: Colors.grey[500],
        ),
      ),
    );
  }
  
  /// Build an enhanced error placeholder with specific styling based on error type
  Widget _buildEnhancedErrorPlaceholder(StorageErrorType errorType, double? width, double? height) {
    // Get appropriate icon for error type
    IconData icon;
    Color backgroundColor;
    Color iconColor;
    String message;
    
    switch (errorType) {
      case StorageErrorType.billingRequired:
        icon = Icons.cloud_off;
        backgroundColor = Colors.orange.shade50;
        iconColor = Colors.orange.shade600;
        message = "Service upgrade required";
        break;
      case StorageErrorType.permissionDenied:
        icon = Icons.lock;
        backgroundColor = Colors.red.shade50;
        iconColor = Colors.red.shade600;
        message = "Access restricted";
        break;
      case StorageErrorType.networkError:
        icon = Icons.wifi_off;
        backgroundColor = Colors.blue.shade50;
        iconColor = Colors.blue.shade600;
        message = "Connection error";
        break;
      case StorageErrorType.fileNotFound:
        icon = Icons.image_not_supported;
        backgroundColor = Colors.grey.shade100;
        iconColor = Colors.grey.shade600;
        message = "Image not available";
        break;
      case StorageErrorType.unknown:
        icon = Icons.broken_image;
        backgroundColor = Colors.grey.shade100;
        iconColor = Colors.grey.shade600;
        message = "Image unavailable";
        break;
    }
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, backgroundColor],
          stops: [0.0, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: (width != null && height != null) ? 
              ((width < height ? width : height) * 0.25).clamp(24.0, 48.0) : 32,
            color: iconColor,
          ),
          if (height == null || height > 80) ...[
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
