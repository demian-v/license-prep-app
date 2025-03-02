import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/license_card.dart';
import '../data/license_data.dart';

class LicenseSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final showTrialBanner = subscriptionProvider.trialDaysLeft > 0 && 
                           subscriptionProvider.subscription.nextBillingDate == null;

    void handleSelectLicense(String licenseId) {
      progressProvider.selectLicense(licenseId);
      Navigator.pushNamed(context, '/theory/$licenseId');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('USA License Prep'),
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Choose a License Type',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (showTrialBanner)
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.amber.shade900),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your free trial expires in ${subscriptionProvider.trialDaysLeft} days',
                      style: TextStyle(color: Colors.amber.shade900),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                    child: Text('Subscribe Now'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.75,
              ),
              itemCount: licenseTypes.length,
              itemBuilder: (context, index) {
                final license = licenseTypes[index];
                return LicenseCard(
                  license: license,
                  isSelected: progressProvider.progress.selectedLicense == license.id,
                  onSelect: () => handleSelectLicense(license.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}