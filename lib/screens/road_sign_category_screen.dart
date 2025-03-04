import 'package:flutter/material.dart';
import '../models/road_sign_category.dart';
import 'road_sign_detail_screen.dart';
import '../data/road_signs_data.dart';

class RoadSignCategoryScreen extends StatefulWidget {
  @override
  _RoadSignCategoryScreenState createState() => _RoadSignCategoryScreenState();
}

class _RoadSignCategoryScreenState extends State<RoadSignCategoryScreen> {
  // Track which categories are expanded
  Map<String, bool> expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // Initialize all categories as collapsed
    for (var category in roadSignCategories) {
      expandedCategories[category.id] = false;
    }
  }

  void toggleCategory(String categoryId) {
    setState(() {
      expandedCategories[categoryId] = !(expandedCategories[categoryId] ?? false);
    });
  }

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
                  final isExpanded = expandedCategories[category.id] ?? false;
                  
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Category header (always visible)
                        InkWell(
                          onTap: () => toggleCategory(category.id),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(16),
                            bottom: isExpanded ? Radius.zero : Radius.circular(16),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey[200],
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
                                AnimatedRotation(
                                  turns: isExpanded ? 0.5 : 0,
                                  duration: Duration(milliseconds: 300),
                                  child: Icon(Icons.keyboard_arrow_down),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Expandable content
                        AnimatedCrossFade(
                          firstChild: Container(height: 0),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(category.description),
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 5,
                                    childAspectRatio: 0.8,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: category.signs.length,
                                  itemBuilder: (context, index) {
                                    final sign = category.signs[index];
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
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: Colors.grey[200],
                                            child: Icon(
                                              getIconForSign(sign.id),
                                              color: getColorForSign(sign.id),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Знак ' + sign.id,
                                            style: TextStyle(fontSize: 12),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          crossFadeState: isExpanded 
                              ? CrossFadeState.showSecond 
                              : CrossFadeState.showFirst,
                          duration: Duration(milliseconds: 300),
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