import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../models/license_type.dart';
import '../providers/progress_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/language_provider.dart';
import '../services/service_locator.dart';
import '../widgets/module_card.dart';
import '../data/license_data.dart' as license_data;

class TheoryModuleScreen extends StatefulWidget {
  final String licenseId;

  TheoryModuleScreen({required this.licenseId});

  @override
  _TheoryModuleScreenState createState() => _TheoryModuleScreenState();
}

class _TheoryModuleScreenState extends State<TheoryModuleScreen> {
  List<TheoryModule> modules = [];
  LicenseType? license;
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    loadModules();
  }
  
  Future<void> loadModules() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final language = languageProvider.language;
      final state = 'all'; // Or get from user preferences
      
      // Find the license from hard-coded data (ideally this would come from Firebase too)
      license = license_data.licenseTypes.firstWhere(
        (l) => l.id == widget.licenseId,
        orElse: () => license_data.licenseTypes.first,
      );
      
      // Fetch theory modules from Firebase
      final fetchedModules = await serviceLocator.content.getTheoryModules(
        widget.licenseId,
        language,
        state
      );
      
      if (mounted) {
        setState(() {
          modules = fetchedModules;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading theory modules: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load theory modules. Please try again.';
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    
    // Check subscription status
    final isSubscriptionActive = subscriptionProvider.isSubscriptionActive;
    
    // Common AppBar
    final appBar = AppBar(
      title: Text(license != null ? '${license!.name} - Theory' : 'Theory Modules'),
    );

    // Show loading state
    if (isLoading) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // Show error state
    if (errorMessage != null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: loadModules,
                child: Text('Повторити спробу'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state
    if (modules.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text('No theory modules available for this license type'),
        ),
      );
    }
    
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
      appBar: appBar,
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
                      backgroundColor: Colors.red.shade900,
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
                Navigator.pushNamed(context, '/practice/${widget.licenseId}');
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
