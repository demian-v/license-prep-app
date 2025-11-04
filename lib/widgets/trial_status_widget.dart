import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../localization/app_localizations.dart';

class TrialStatusWidget extends StatelessWidget {
  // Helper method to get custom trial icon asset path
  String? _getTrialIconAsset(bool isExpired) {
    return isExpired 
        ? 'assets/images/trial/warning.png'
        : 'assets/images/trial/star.png';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        debugPrint('🎯 TrialStatusWidget: Building with isTrialActive=${subscriptionProvider.isTrialActive}');
        debugPrint('🎯 TrialStatusWidget: Subscription loaded=${subscriptionProvider.subscription != null}');
        debugPrint('🎯 TrialStatusWidget: Is loading=${subscriptionProvider.isLoading}');
        
        // Get subscription states
        final hasActiveTrial = subscriptionProvider.isTrialActive;
        final hasExpiredTrial = subscriptionProvider.hasExpiredTrial;
        final hasValidPaidSubscription = subscriptionProvider.hasValidSubscription && 
                                        subscriptionProvider.subscription != null &&
                                        !subscriptionProvider.subscription!.isTrial;
        final hasExpiredPaidSubscription = subscriptionProvider.hasExpiredPaidSubscription;
        final isLoading = subscriptionProvider.isLoading;
        
        // Show loading state
        if (isLoading) {
          debugPrint('⏳ TrialStatusWidget: Loading subscription data...');
          return _buildLoadingWidget();
        }
        
        // Hide widget only if user has active PAID subscription
        if (hasValidPaidSubscription) {
          debugPrint('✅ TrialStatusWidget: User has active paid subscription - hiding widget');
          return SizedBox.shrink();
        }
        
        // Show widget for active trial, expired trial, or expired paid subscription
        if (hasActiveTrial) {
          debugPrint('✅ TrialStatusWidget: Showing active trial status');
          return _buildTrialWidget(context, subscriptionProvider, isActive: true);
        } else if (hasExpiredTrial) {
          debugPrint('⏰ TrialStatusWidget: Showing expired trial status');
          return _buildTrialWidget(context, subscriptionProvider, isActive: false);
        } else if (hasExpiredPaidSubscription) {
          debugPrint('💳 TrialStatusWidget: Showing expired paid subscription status');
          return _buildExpiredPaidWidget(context, subscriptionProvider);
        } else {
          // This should theoretically never happen since every user has a trial
          debugPrint('⚠️ TrialStatusWidget: No subscription state matched - this should not happen!');
          return SizedBox.shrink();
        }
      },
    );
  }

  // Loading widget with existing design
  Widget _buildLoadingWidget() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey.shade50.withOpacity(0.4)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loading subscription...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Please wait...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced trial widget (preserves existing design, adds expired state)
  Widget _buildTrialWidget(BuildContext context, SubscriptionProvider subscriptionProvider, {required bool isActive}) {
    final daysRemaining = subscriptionProvider.trialDaysRemaining;
    final isUrgent = daysRemaining <= 1 && isActive;
    final isExpired = !isActive;
    
    // Use existing color logic, enhanced for expired state
    final colors = isExpired 
        ? [Colors.white, Colors.red.shade50.withOpacity(0.3)]
        : isUrgent 
            ? [Colors.white, Colors.orange.shade50.withOpacity(0.3)]
            : [Colors.white, Colors.blue.shade50.withOpacity(0.3)];
    
    final borderColor = isExpired 
        ? Colors.red.shade200.withOpacity(0.5) 
        : isUrgent 
            ? Colors.orange.shade200.withOpacity(0.5) 
            : Colors.blue.shade200.withOpacity(0.5);
    
    final iconColor = isExpired 
        ? Colors.red.shade600 
        : isUrgent 
            ? Colors.orange.shade600 
            : Colors.blue.shade600;
    
    final textColor = isExpired 
        ? Colors.red.shade700 
        : isUrgent 
            ? Colors.orange.shade700 
            : Colors.blue.shade700;

    // Keep exact same container design as current widget
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Keep exact same icon container design
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isExpired 
                    ? [Colors.white, Colors.red.shade50.withOpacity(0.4)]
                    : isUrgent 
                        ? [Colors.white, Colors.orange.shade50.withOpacity(0.4)]
                        : [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isExpired 
                    ? Colors.red.shade200
                    : isUrgent 
                        ? Colors.orange.shade200
                        : Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: _getTrialIconAsset(isExpired) != null
                ? Image.asset(
                    _getTrialIconAsset(isExpired)!,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to Material icon if custom asset fails to load
                      debugPrint('❌ TrialStatusWidget: Failed to load trial icon: ${_getTrialIconAsset(isExpired)}');
                      return Icon(
                        isExpired 
                            ? Icons.warning 
                            : isUrgent 
                                ? Icons.access_time 
                                : Icons.star,
                        color: iconColor,
                        size: 20,
                      );
                    },
                  )
                : Icon(
                    isExpired 
                        ? Icons.warning 
                        : isUrgent 
                            ? Icons.access_time 
                            : Icons.star,
                    color: iconColor,
                    size: 20,
                  ),
          ),
          SizedBox(width: 12),
          
          // Keep exact same text layout
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired 
                      ? AppLocalizations.of(context).translate('trial_expired')
                      : isUrgent 
                          ? AppLocalizations.of(context).translate('trial_expires_soon')
                          : AppLocalizations.of(context).translate('trial_active'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  isExpired 
                      ? AppLocalizations.of(context).translate('subscription_required')
                      : '${AppLocalizations.of(context).translate('days_left')}: $daysRemaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: isExpired 
                        ? Colors.red.shade600 
                        : isUrgent 
                            ? Colors.orange.shade600 
                            : Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 12),
          
          // Keep exact same button design
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isExpired 
                    ? [Colors.white, Colors.red.shade50.withOpacity(0.4)]
                    : isUrgent 
                        ? [Colors.white, Colors.orange.shade50.withOpacity(0.4)]
                        : [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/subscription');
                },
                borderRadius: BorderRadius.circular(8),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    AppLocalizations.of(context).translate('upgrade_now'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New widget for expired paid subscription (using same design pattern)
  Widget _buildExpiredPaidWidget(BuildContext context, SubscriptionProvider subscriptionProvider) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.shade200.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon container (same design as trial widget)
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.red.shade50.withOpacity(0.4)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.credit_card_off,
              color: Colors.red.shade600,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('subscription_expired'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  AppLocalizations.of(context).translate('renew_to_continue'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(width: 12),
          
          // Renew button (same design as upgrade button)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.red.shade50.withOpacity(0.4)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pushNamed(context, '/subscription');
                },
                borderRadius: BorderRadius.circular(8),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    AppLocalizations.of(context).translate('renew_now'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
