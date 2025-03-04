import 'package:flutter/material.dart';
import '../data/road_signs_data.dart';
import 'road_sign_category_screen.dart';

class RoadSignsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      ),
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
                itemCount: roadSignCategories.length,
                itemBuilder: (context, index) {
                  final category = roadSignCategories[index];
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
                            builder: (context) => RoadSignCategoryScreen(),
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