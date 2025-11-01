import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../localization/app_localizations.dart';
import '../utils/subscription_checker.dart';

class PremiumBlockDialog extends StatelessWidget {
  final String featureName;
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onClosePressed;

  const PremiumBlockDialog({
    Key? key,
    required this.featureName,
    this.onUpgradePressed,
    this.onClosePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final isExpiredTrial = subscriptionProvider.hasExpiredTrial;
        final titleKey = SubscriptionChecker.getBlockTitleKey(subscriptionProvider);
        final messageKey = SubscriptionChecker.getBlockMessageKey(subscriptionProvider);
        
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button (top right)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: onClosePressed ?? () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
                
                // Warning Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isExpiredTrial ? Colors.red.shade100 : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpiredTrial ? Icons.lock_outlined : Icons.diamond_outlined,
                    size: 40,
                    color: isExpiredTrial ? Colors.red.shade600 : Colors.orange.shade600,
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Title
                Text(
                  AppLocalizations.of(context).translate(titleKey),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 16),
                
                // Feature-specific message
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: featureName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                      TextSpan(
                        text: ' ${AppLocalizations.of(context).translate('subscription_required').toLowerCase()}',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 12),
                
                // Detailed message
                Text(
                  AppLocalizations.of(context).translate(messageKey),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 32),
                
                // Action Buttons
                Column(
                  children: [
                    // Upgrade Now Button (Primary)
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onUpgradePressed ?? () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(context, '/subscription');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isExpiredTrial 
                              ? Colors.red.shade600 
                              : Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('upgrade_now'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Close Button (Secondary)
                    Container(
                      width: double.infinity,
                      height: 45,
                      child: TextButton(
                        onPressed: onClosePressed ?? () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('close'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Static method to show the premium block dialog
  static Future<void> show(
    BuildContext context, {
    required String featureName,
    VoidCallback? onUpgradePressed,
    VoidCallback? onClosePressed,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => PremiumBlockDialog(
        featureName: featureName,
        onUpgradePressed: onUpgradePressed,
        onClosePressed: onClosePressed,
      ),
    );
  }
}
