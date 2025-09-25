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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isExpiring 
                  ? [Colors.white, Colors.red.shade50.withOpacity(0.3)]
                  : isUrgent 
                      ? [Colors.white, Colors.orange.shade50.withOpacity(0.3)]
                      : [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpiring 
                  ? Colors.red.shade200.withOpacity(0.5) 
                  : isUrgent 
                      ? Colors.orange.shade200.withOpacity(0.5) 
                      : Colors.blue.shade200.withOpacity(0.5),
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
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isExpiring 
                        ? [Colors.white, Colors.red.shade50.withOpacity(0.4)]
                        : isUrgent 
                            ? [Colors.white, Colors.orange.shade50.withOpacity(0.4)]
                            : [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isExpiring 
                        ? Colors.red.shade200
                        : isUrgent 
                            ? Colors.orange.shade200
                            : Colors.blue.shade200,
                    width: 1,
                  ),
                ),
                child: Icon(
                  isExpiring 
                      ? Icons.warning 
                      : isUrgent 
                          ? Icons.access_time 
                          : Icons.star,
                  color: isExpiring 
                      ? Colors.red.shade600 
                      : isUrgent 
                          ? Colors.orange.shade600 
                          : Colors.blue.shade600,
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
                            ? Colors.red.shade700 
                            : isUrgent 
                                ? Colors.orange.shade700 
                                : Colors.blue.shade700,
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
                            ? Colors.red.shade600 
                            : isUrgent 
                                ? Colors.orange.shade600 
                                : Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Upgrade button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isExpiring 
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
                          color: isExpiring 
                              ? Colors.red.shade700 
                              : isUrgent 
                                  ? Colors.orange.shade700 
                                  : Colors.blue.shade700,
                        ),
                      ),
                    ),
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
