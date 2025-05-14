import 'package:flutter/material.dart';
import '../models/traffic_rule_topic.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

class TrafficRuleContentScreen extends StatelessWidget {
  final TrafficRuleTopic topic;

  const TrafficRuleContentScreen({
    Key? key,
    required this.topic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          topic.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF6200EE), // Deep purple for app bar text and icons
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
      backgroundColor: Colors.white,  // Ensure consistent background color
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 24),  // Add padding at the bottom
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Remove duplicate title container, as it's already in the app bar
            Container(
              width: double.infinity,
              height: 8, // Small spacer
              decoration: BoxDecoration(
                color: Color(0xFFF8F5FF), // Very light purple background
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFD4C4FF), // Light purple border
                    width: 1,
                  ),
                ),
              ),
            ),
            // Add a bit of top padding to the content
            SizedBox(height: 8),
            
            // Safely handle sections or content display
            Builder(
              builder: (context) {
                try {
                  // First check if we have valid sections
                  if (topic.sections != null && topic.sections.isNotEmpty) {
                    return Column(
                      children: topic.sections.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final section = entry.value;
                        
                        return Column(
                          children: [
                            // Add divider between sections (not before the first one)
                            if (index > 0) 
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                                child: Divider(color: Color(0xFFD4C4FF), thickness: 1),
                              ),
                            
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (section.title != null && section.title.isNotEmpty)
                                    Text(
                                      section.title,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6200EE), // Deep purple for section titles
                                      ),
                                    ),
                                  SizedBox(height: 12),
                                  Text(
                                    section.content
                                      ?.replaceAll('\\n•', '\n• ') // Format bullet points with a space
                                      ?.replaceAll('\\n\\n', '\n\n') // Handle double newlines
                                      ?.replaceAll('\\n', '\n') // Handle regular newlines
                                      ?? "No content available",
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.5, // Better line spacing
                                      color: Colors.black87, // Slightly softer than pure black
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  } else {
                    // If no sections, try to display the full content
                    return Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        topic.fullContent
                          ?.replaceAll('\\n•', '\n• ') // Format bullet points with a space
                          ?.replaceAll('\\n\\n', '\n\n') // Handle double newlines
                          ?.replaceAll('\\n', '\n') // Handle regular newlines
                          ?? "No content available for this topic.",
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5, // Better line spacing
                          color: Colors.black87, // Slightly softer than pure black
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  print('Error rendering topic content: $e');
                  // Fallback for any rendering errors
                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error displaying content',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Please try again later or contact support if the issue persists.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
