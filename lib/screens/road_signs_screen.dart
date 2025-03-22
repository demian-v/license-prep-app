import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/road_sign_category.dart';
import '../providers/language_provider.dart';
import '../services/service_locator.dart';
import 'road_sign_category_screen.dart';

class RoadSignsScreen extends StatefulWidget {
  @override
  _RoadSignsScreenState createState() => _RoadSignsScreenState();
}

class _RoadSignsScreenState extends State<RoadSignsScreen> {
  List<RoadSignCategory> categories = [];
  bool isLoading = true;
  String? errorMessage;
  String roadSignsIntro = "Дорожні знаки є важливою частиною правил дорожнього руху. Вони надають важливу інформацію для безпечного руху на дорогах.";
  
  @override
  void initState() {
    super.initState();
    loadCategories();
  }
  
  Future<void> loadCategories() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final language = languageProvider.language;
      
      // Fetch road sign categories from Firebase
      final fetchedCategories = await serviceLocator.content.getRoadSignCategories(language);
      
      if (mounted) {
        setState(() {
          categories = fetchedCategories;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading road sign categories: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to load road sign categories. Please try again.';
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
        'Дорожні знаки',
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
                onPressed: loadCategories,
                child: Text('Повторити спробу'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show empty state
    if (categories.isEmpty) {
      return Scaffold(
        appBar: appBar,
        body: Center(
          child: Text('Немає доступних категорій дорожніх знаків'),
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
              Text(
                roadSignsIntro,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoadSignCategoryScreen(category: category),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[200],
                              // For now, use a placeholder icon based on category
                              child: getIconForCategory(category.id),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                category.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
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
        return Image.asset('assets/images/signs/warning_icon.png', 
          errorBuilder: (context, error, stackTrace) => Icon(Icons.warning, color: Colors.red));
      case 'priority':
        return Image.asset('assets/images/signs/priority_icon.png',
          errorBuilder: (context, error, stackTrace) => Icon(Icons.priority_high, color: Colors.red));
      case 'prohibition':
        return Image.asset('assets/images/signs/prohibition_icon.png',
          errorBuilder: (context, error, stackTrace) => Icon(Icons.do_not_disturb, color: Colors.red));
      case 'mandatory':
        return Image.asset('assets/images/signs/mandatory_icon.png',
          errorBuilder: (context, error, stackTrace) => Icon(Icons.arrow_upward, color: Colors.blue));
      case 'information':
        return Image.asset('assets/images/signs/information_icon.png',
          errorBuilder: (context, error, stackTrace) => Icon(Icons.info, color: Colors.green));
      case 'service':
        return Image.asset('assets/images/signs/service_icon.png',
          errorBuilder: (context, error, stackTrace) => Icon(Icons.local_hospital, color: Colors.blue));
      case 'additional':
        return Image.asset('assets/images/signs/additional_icon.png',
          errorBuilder: (context, error, stackTrace) => Icon(Icons.add_box, color: Colors.black));
      default:
        return Icon(Icons.error);
    }
  }
}
