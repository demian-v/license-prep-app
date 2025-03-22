import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/road_sign_category.dart';
import '../models/road_sign.dart';
import '../providers/language_provider.dart';
import '../services/service_locator.dart';
import 'road_sign_detail_screen.dart';

class RoadSignCategoryScreen extends StatefulWidget {
  final RoadSignCategory category;
  
  const RoadSignCategoryScreen({
    Key? key,
    required this.category,
  }) : super(key: key);
  
  @override
  _RoadSignCategoryScreenState createState() => _RoadSignCategoryScreenState();
}

class _RoadSignCategoryScreenState extends State<RoadSignCategoryScreen> {
  List<RoadSign> signs = [];
  bool isLoading = true;
  String? errorMessage;
  
  // Track expanded state for current category
  bool isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    loadSigns();
  }
  
  Future<void> loadSigns() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final language = languageProvider.language;
      
      // Fetch road signs from Firebase for this category
      final fetchedSigns = await serviceLocator.content.getRoadSigns(
        widget.category.id,
        language
      );
      
      if (mounted) {
        setState(() {
          signs = fetchedSigns;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading road signs: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load road signs. Please try again.';
          isLoading = false;
        });
      }
    }
  }
  
  void toggleCategory() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Create common app bar
    final appBar = AppBar(
      title: Text(
        widget.category.title,
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
                onPressed: loadSigns,
                child: Text('Повторити спробу'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state
    if (signs.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text('У цій категорії немає дорожніх знаків'),
        ),
      );
    }
    
    return Scaffold(
      appBar: appBar,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category description
              Text(
                widget.category.description,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              
              // Signs grid
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: signs.length,
                itemBuilder: (context, index) {
                  final sign = signs[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoadSignDetailScreen(sign: sign),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: sign.imageUrl.isNotEmpty
                                ? serviceLocator.storage.getImage(
                                    storagePath: 'signs/${sign.imageUrl}',
                                    assetFallback: 'assets/images/signs/${sign.id}.png',
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.contain,
                                    placeholderIcon: getIconForSign(sign.id),
                                    placeholderColor: Colors.grey[200],
                                  )
                                : Icon(
                                    getIconForSign(sign.id),
                                    color: getColorForSign(sign.id),
                                    size: 40,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Знак ${sign.id}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          sign.name,
                          style: TextStyle(
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget getIconForCategory(String categoryId) {
    switch (categoryId) {
      case 'warning':
        return Icon(Icons.warning, color: Colors.red);
      case 'priority':
        return Icon(Icons.priority_high, color: Colors.red);
      case 'prohibition':
        return Icon(Icons.do_not_disturb, color: Colors.red);
      case 'mandatory':
        return Icon(Icons.arrow_upward, color: Colors.blue);
      case 'information':
        return Icon(Icons.info, color: Colors.green);
      case 'service':
        return Icon(Icons.local_hospital, color: Colors.blue);
      case 'additional':
        return Icon(Icons.add_box, color: Colors.black);
      default:
        return Icon(Icons.error);
    }
  }
  
  IconData getIconForSign(String signId) {
    if (signId.startsWith('1.')) return Icons.warning;
    if (signId.startsWith('2.')) return Icons.priority_high;
    if (signId.startsWith('3.')) return Icons.do_not_disturb_on;
    if (signId.startsWith('4.')) return Icons.arrow_upward;
    if (signId.startsWith('5.')) return Icons.info;
    if (signId.startsWith('6.')) return Icons.local_hospital;
    if (signId.startsWith('7.')) return Icons.add_box;
    return Icons.sign_language;
  }
  
  Color getColorForSign(String signId) {
    if (signId.startsWith('1.')) return Colors.red;
    if (signId.startsWith('2.')) return Colors.red;
    if (signId.startsWith('3.')) return Colors.red;
    if (signId.startsWith('4.')) return Colors.blue;
    if (signId.startsWith('5.')) return Colors.blue;
    if (signId.startsWith('6.')) return Colors.blue;
    if (signId.startsWith('7.')) return Colors.black;
    return Colors.grey;
  }
}
