import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../localization/app_localizations.dart';

class TrialStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        debugPrint('🎯 TrialStatusWidget: Building with isTrialActive=${subscriptionProvider.isTrialActive}');
        debugPrint('🎯 TrialStatusWidget: Subscription loaded=${subscriptionProvider.subscription != null}');
        debugPrint('🎯 TrialStatusWidget: Is loading=${subscriptionProvider.isLoading}');
        
        // Show for both active trials and expired trials
        final hasActiveTrial = subscriptionProvider.isTrialActive;
        final hasExpiredTrial = subscriptionProvider.hasExpiredTrial;
        
        if (!hasActiveTrial && !hasExpiredTrial) {
          debugPrint('❌ TrialStatusWidget: Not showing - no trial (active or inactive)');
          return SizedBox.shrink();
        }
        
        if (hasExpiredTrial) {
          debugPrint('⏰ TrialStatusWidget: Showing expired trial status');
        } else {
          debugPrint('✅ TrialStatusWidget: Showing active trial status');
        }
        
        debugPrint('✅ TrialStatusWidget: Showing trial status widget');

        final daysRemaining = subscriptionProvider.trialDaysRemaining;
        final isUrgent = daysRemaining <= 1 && hasActiveTrial;
        final isExpiring = hasExpiredTrial || (hasActiveTrial && daysRemaining == 0);
        
        return Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isExpiring 
                  ? [Colors.red.shade100, Colors.red.shade50]
                  : isUrgent 
                      ? [Colors.orange.shade100, Colors.orange.shade50]
                      : [Colors.blue.shade100, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isExpiring 
                  ? Colors.red.shade300 
                  : isUrgent 
                      ? Colors.orange.shade300 
                      : Colors.blue.shade300,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isExpiring 
                      ? Colors.red.shade600 
                      : isUrgent 
                          ? Colors.orange.shade600 
                          : Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isExpiring 
                      ? Icons.warning 
                      : isUrgent 
                          ? Icons.access_time 
                          : Icons.star,
                  color: Colors.white,
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
                      isExpiring 
                          ? AppLocalizations.of(context).translate('trial_expired')
                          : isUrgent 
                              ? AppLocalizations.of(context).translate('trial_expires_soon')
                              : AppLocalizations.of(context).translate('trial_active'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isExpiring 
                            ? Colors.red.shade800 
                            : isUrgent 
                                ? Colors.orange.shade800 
                                : Colors.blue.shade800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      isExpiring 
                          ? AppLocalizations.of(context).translate('subscription_required')
                          : '$daysRemaining ${AppLocalizations.of(context).translate('days_remaining')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpiring 
                            ? Colors.red.shade700 
                            : isUrgent 
                                ? Colors.orange.shade700 
                                : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Upgrade button
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/subscription');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpiring 
                      ? Colors.red.shade600 
                      : isUrgent 
                          ? Colors.orange.shade600 
                          : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('upgrade_now'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
