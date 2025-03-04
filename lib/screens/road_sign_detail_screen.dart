import 'package:flutter/material.dart';
import '../models/road_sign.dart';

class RoadSignDetailScreen extends StatelessWidget {
  final RoadSign sign;

  const RoadSignDetailScreen({
    Key? key,
    required this.sign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          sign.signCode.length > 0 ?
            'Знак ' + sign.signCode.substring(sign.signCode.indexOf(' ') + 1) : '',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    child: Image.asset(
                      sign.imageUrl,
                      errorBuilder: (context, error, stackTrace) => 
                        Icon(Icons.image_not_supported, size: 40),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sign.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          sign.signCode,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
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
                    sign.description,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  Text(
                    sign.installationGuidelines,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            if (sign.exampleImageUrl != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Фото-приклад:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 200,
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: AssetImage(sign.exampleImageUrl!),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) => {},
                      ),
                    ),
                    child: Center(
                      child: Icon(Icons.image, size: 50, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}