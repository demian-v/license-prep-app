import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../models/traffic_rule_topic.dart';
import '../providers/content_provider.dart';
import '../providers/progress_provider.dart';
import 'traffic_rule_content_screen.dart';

class TheoryModuleScreen extends StatefulWidget {
  final TheoryModule module;

  const TheoryModuleScreen({
    Key? key,
    required this.module,
  }) : super(key: key);

  @override
  _TheoryModuleScreenState createState() => _TheoryModuleScreenState();
}

class _TheoryModuleScreenState extends State<TheoryModuleScreen> {
  List<TrafficRuleTopic> _moduleTopics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() {
      _isLoading = true;
    });

    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    print('TheoryModuleScreen: Loading topics for module ${widget.module.id}');
    print('Module topics: ${widget.module.topics}');
    print('Module state: ${widget.module.state}, language: ${widget.module.language}');
    
    // ENHANCEMENT: Pre-warm topics for this module to improve performance
    try {
      await contentProvider.preWarmTopicsForModule(widget.module);
    } catch (e) {
      print('Warning: Pre-warming failed, continuing with normal loading: $e');
    }
    
    // Using the topics from the provider
    final allTopics = contentProvider.topics;
    
    // Get module topics list using the helper method to handle both string and list
    final topicsList = widget.module.getTopicsList();
    
    // Filter topics based on the topics listed in the module
    final filteredTopics = <TrafficRuleTopic>[];
    
    // 🔧 FIX: If module topics array is empty, match by ID pattern
    if (topicsList.isEmpty && allTopics.isNotEmpty) {
      print('Module topics array is empty, attempting to match by ID pattern...');
      
      // Extract number from module ID: traffic_rules_en_IL_01 → 01 → 1
      final moduleIdParts = widget.module.id.split('_');
      if (moduleIdParts.length >= 4) {
        final moduleNumber = moduleIdParts.last;
        final topicNumber = moduleNumber.replaceAll(RegExp(r'^0+'), ''); // Remove leading zeros: 01 → 1
        
        print('Extracted module number: $moduleNumber → topic number: $topicNumber');
        print('Looking for topic with ID: $topicNumber, state: ${widget.module.state}, language: ${widget.module.language}');
        
        // Find THE matching topic with same ID, state, and language
        try {
          final matchingTopic = allTopics.firstWhere(
            (t) => t.id == topicNumber && 
                   (t.state == widget.module.state || t.state == 'ALL') && 
                   t.language == widget.module.language,
          );
          
          print('✅ Successfully matched topic: ${matchingTopic.id} - ${matchingTopic.title}');
          filteredTopics.add(matchingTopic);
        } catch (e) {
          print('❌ Could not find matching topic for module ${widget.module.id}');
          print('Available topic IDs: ${allTopics.map((t) => "${t.id}(${t.state},${t.language})").take(5).join(", ")}...');
        }
      }
    } else {
      // Original logic: First try to match topics from the ones already loaded in memory
      for (var topicId in topicsList) {
        print('Looking for topic ID: $topicId');
        
        // Try multiple ways to match the topic ID
        TrafficRuleTopic? topic;
        try {
          topic = allTopics.firstWhere(
            (t) => t.id == topicId || 
                   t.id == topicId.replaceAll('topic_', '') || 
                   'topic_${t.id}' == topicId,
          );
          print('Found topic in memory: ${topic.id} - ${topic.title}');
          filteredTopics.add(topic);
        } catch (e) {
          print('Topic not found in memory, fetching from database: $topicId');
          // If topic not found in memory, try to fetch it directly
          final fetchedTopic = await contentProvider.getTopicById(topicId);
          if (fetchedTopic != null) {
            print('Successfully fetched topic: ${fetchedTopic.id} - ${fetchedTopic.title}');
            filteredTopics.add(fetchedTopic);
          } else {
            print('Failed to fetch topic: $topicId');
          }
        }
      }
    }
    
    // If we still don't have any topics and the content provider has topics,
    // try to match by state and language
    if (filteredTopics.isEmpty && allTopics.isNotEmpty) {
      print('No direct topic matches found. Trying to filter by state and language...');
      filteredTopics.addAll(allTopics.where((topic) => 
        (topic.state == widget.module.state || topic.state == 'ALL') && 
        topic.language == widget.module.language &&
        topic.licenseId == widget.module.licenseId
      ).toList());
      
      print('Found ${filteredTopics.length} topics by filtering');
    }
    
    // Sort by order
    filteredTopics.sort((a, b) => a.order.compareTo(b.order));
    
    setState(() {
      _moduleTopics = filteredTopics;
      _isLoading = false;
    });
    
    print('Loaded ${_moduleTopics.length} topics for module ${widget.module.id}');
    
    // 🚀 AUTO-NAVIGATE: If there's only 1 topic, go directly to content
    // (This should now be rare since TheoryScreen handles it directly)
    if (_moduleTopics.length == 1 && mounted) {
      print('📍 Auto-navigating to single topic: ${_moduleTopics[0].title}');
      // Use immediate navigation without post-frame callback to reduce flash
      Future.microtask(() {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrafficRuleContentScreen(topic: _moduleTopics[0]),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.module.title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildTopicsList(),
    );
  }

  Widget _buildTopicsList() {
    if (_moduleTopics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('No topics available for this module'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTopics,
              child: Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _moduleTopics.length,
      itemBuilder: (context, index) {
        final topic = _moduleTopics[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrafficRuleContentScreen(topic: topic),
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      (index + 1).toString(),
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Consumer<ProgressProvider>(
                    builder: (context, progressProvider, _) {
                      // Show progress indicator for this topic
                      final progress = progressProvider.progress.topicProgress[topic.id] ?? 0.0;
                      
                      if (progress > 0) {
                        return Container(
                          width: 40,
                          height: 40,
                          child: Stack(
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress >= 1.0 ? Colors.green : Colors.blue,
                                ),
                              ),
                              if (progress >= 1.0)
                                Center(
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                        );
                      } else {
                        return Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
