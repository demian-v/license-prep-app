import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/traffic_light_info.dart';
import '../providers/language_provider.dart';
import '../services/service_locator.dart';

class TrafficLightScreen extends StatefulWidget {
  @override
  _TrafficLightScreenState createState() => _TrafficLightScreenState();
}

class _TrafficLightScreenState extends State<TrafficLightScreen> {
  TrafficLightInfo? trafficLightInfo;
  bool isLoading = true;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    loadTrafficLightInfo();
  }
  
  Future<void> loadTrafficLightInfo() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final language = languageProvider.language;
      
      // Fetch traffic light information from Firebase
      final info = await serviceLocator.content.getTrafficLightInfo(language);
      
      if (mounted) {
        setState(() {
          trafficLightInfo = info;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading traffic light information: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load traffic light information. Please try again.';
          isLoading = false;
        });
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    // Create common app bar
    final appBar = AppBar(
      title: Text(
        'Світлофор',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: Colors.black,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            // Search functionality
          },
        ),
      ],
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
                onPressed: loadTrafficLightInfo,
                child: Text('Повторити спробу'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state or if traffic light info isn't available
    if (trafficLightInfo == null) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text('Інформація про світлофори тимчасово недоступна'),
        ),
      );
    }
    
    // Split content for display
    final contentParts = trafficLightInfo!.content.split('\n\n');
    final partsCount = contentParts.length;
    
    return Scaffold(
      appBar: appBar,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First section with title and first paragraph
            Container(
              width: double.infinity,
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trafficLightInfo!.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  if (partsCount > 0)
                    Text(
                      contentParts[0],
                      style: TextStyle(fontSize: 16),
                    ),
                ],
              ),
            ),
            
            // Second paragraph
            if (partsCount > 1)
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contentParts[1],
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            
            // Third paragraph
            if (partsCount > 2)
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contentParts[2],
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            
            // Fourth paragraph with images and remaining content
            if (partsCount > 3)
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contentParts[3],
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    
                    // First image
                    if (trafficLightInfo!.imageUrls.isNotEmpty)
                      Center(
                        child: serviceLocator.storage.getImage(
                          storagePath: 'traffic_lights/${trafficLightInfo!.imageUrls[0]}',
                          assetFallback: 'assets/images/traffic_lights/phases.png',
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.contain,
                          placeholderIcon: Icons.traffic,
                        ),
                      ),
                    SizedBox(height: 16),
                    
                    // Fifth paragraph
                    if (partsCount > 4)
                      Text(
                        contentParts[4],
                        style: TextStyle(fontSize: 16),
                      ),
                    SizedBox(height: 16),
                    
                    // Sixth paragraph
                    if (partsCount > 5)
                      Text(
                        contentParts[5],
                        style: TextStyle(fontSize: 16),
                      ),
                    SizedBox(height: 16),
                    
                    // Second image
                    if (trafficLightInfo!.imageUrls.length > 1)
                      Center(
                        child: serviceLocator.storage.getImage(
                          storagePath: 'traffic_lights/${trafficLightInfo!.imageUrls[1]}',
                          assetFallback: 'assets/images/traffic_lights/intersection.png',
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.contain,
                          placeholderIcon: Icons.map,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
