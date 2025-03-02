import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/progress_provider.dart';
import '../providers/subscription_provider.dart';
import '../widgets/module_card.dart';
import '../data/license_data.dart';

class TheoryModuleScreen extends StatelessWidget {
  final String licenseId;

  TheoryModuleScreen({required this.licenseId});

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    
    // Find the license
    final license = licenseTypes.firstWhere(
      (l) => l.id == licenseId,
      orElse: () => licenseTypes.first,
    );
    
    // Get modules for this license
    final modules = theoryModules.where((m) => m.licenseId == licenseId).toList();
    
    // Check subscription status
    final isSubscriptionActive = subscriptionProvider.isSubscriptionActive;

    void handleModuleSelect(String moduleId) {
      if (!isSubscriptionActive) {
        Navigator.pushNamed(context, '/subscription');
        return;
      }
      
      // Mark module as completed for demo purposes
      progressProvider.completeModule(moduleId);
      
      // In a real app, this would navigate to module content
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Module completed!'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${license.name} - Theory'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isSubscriptionActive)
            Container(
              margin: EdgeInsets.all(16.0),
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Column(
                children: [
                  Text(
                    'Your trial has ended. Subscribe to continue learning.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                    child: Text('Subscribe Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,  // Updated from primary
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.0),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: ModuleCard(
                    module: module,
                    isCompleted: progressProvider.progress.completedModules.contains(module.id),
                    onSelect: () => handleModuleSelect(module.id),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/practice/$licenseId');
              },
              child: Text('Go to Practice Tests'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}