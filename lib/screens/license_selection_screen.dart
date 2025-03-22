import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/license_type.dart';
import '../providers/progress_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/language_provider.dart';
import '../services/service_locator.dart';
import '../widgets/license_card.dart';
import '../data/license_data.dart' as license_data;

class LicenseSelectionScreen extends StatefulWidget {
  @override
  _LicenseSelectionScreenState createState() => _LicenseSelectionScreenState();
}

class _LicenseSelectionScreenState extends State<LicenseSelectionScreen> {
  List<LicenseType> licenseTypes = [];
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    loadLicenseTypes();
  }
  
  // Since we don't have a direct getLicenseTypes method in ContentApiInterface,
  // we'll use the hard-coded license types for now
  Future<void> loadLicenseTypes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      // We could potentially enhance this by fetching module counts, etc. from Firebase
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final language = languageProvider.language;
      
      // For now, use the hard-coded license types
      // In a real implementation, you'd want to add the ContentApiInterface.getLicenseTypes method
      // and fetch this data from Firebase
      if (mounted) {
        setState(() {
          licenseTypes = license_data.licenseTypes;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading license types: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load license types. Please try again.';
          isLoading = false;
        });
      }
    }
  }
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
