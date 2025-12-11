import 'package:flutter/material.dart';
import '../services/service_locator.dart';

class AdaptiveQuestionImage extends StatelessWidget {
  final String imagePath;
  final String? assetFallback;
  final double maxHeight;
  final double minHeight;
  final String storageFolder;

  const AdaptiveQuestionImage({
    Key? key,
    required this.imagePath,
    this.assetFallback,
    this.maxHeight = 265.0,
    this.minHeight = 150.0,
    this.storageFolder = 'quiz_images', // Default for backward compatibility
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight,
            maxHeight: maxHeight,
          ),
          child: serviceLocator.storage.getImage(
            storagePath: '$storageFolder/$imagePath',
            assetFallback: assetFallback,
            fit: BoxFit.contain, // Changed from BoxFit.cover
            width: double.infinity,
            placeholderIcon: Icons.broken_image,
            placeholderColor: Colors.grey[200],
          ),
        ),
      ),
    );
  }
}
