import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Cache downloaded URLs to avoid unnecessary downloads
  final Map<String, String> _urlCache = {};
  
  /// Get download URL for a file in Firebase Storage
  Future<String?> getDownloadURL(String path) async {
    // Return cached URL if available
    if (_urlCache.containsKey(path)) {
      return _urlCache[path];
    }
    
    try {
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      
      // Cache the URL
      _urlCache[path] = url;
      
      return url;
    } catch (e) {
      print('Error getting download URL for $path: $e');
      return null;
    }
  }
  
  /// Clear the URL cache
  void clearCache() {
    _urlCache.clear();
  }
  
  /// Create an image widget that loads from Firebase Storage with fallback to local asset
  /// or placeholder
  Widget getImage({
    required String storagePath, 
    String? assetFallback,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Color? placeholderColor,
    IconData placeholderIcon = Icons.image,
  }) {
    return FutureBuilder<String?>(
      future: getDownloadURL(storagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          return Image.network(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / 
                          (loadingProgress.expectedTotalBytes ?? 1)
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // If network image fails, try asset fallback
              if (assetFallback != null) {
                return Image.asset(
                  assetFallback,
                  width: width,
                  height: height,
                  fit: fit,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(
                    width, height, placeholderColor, placeholderIcon),
                );
              }
              return _buildPlaceholder(width, height, placeholderColor, placeholderIcon);
            },
          );
        }
        
        // If no storage URL, try asset fallback
        if (assetFallback != null) {
          return Image.asset(
            assetFallback,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(
              width, height, placeholderColor, placeholderIcon),
          );
        }
        
        // If all else fails, show placeholder
        return _buildPlaceholder(width, height, placeholderColor, placeholderIcon);
      },
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
}
