import 'package:flutter/material.dart';
import '../models/traffic_rule_topic.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

class TrafficRuleContentScreen extends StatefulWidget {
  final TrafficRuleTopic topic;

  const TrafficRuleContentScreen({
    Key? key,
    required this.topic,
  }) : super(key: key);

  @override
  _TrafficRuleContentScreenState createState() => _TrafficRuleContentScreenState();
}

class _TrafficRuleContentScreenState extends State<TrafficRuleContentScreen> with TickerProviderStateMixin {
  late AnimationController _titleAnimationController;
  late Animation<double> _titlePulseAnimation;
  late AnimationController _contentAnimationController;
  late Animation<double> _contentFadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Title pulse animation (3-second cycle)
    _titleAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _titlePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Content fade-in animation
    _contentAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _titleAnimationController.repeat(reverse: true);
    _contentAnimationController.forward();
  }
  
  @override
  void dispose() {
    _titleAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  // Topic-based gradient selection
  LinearGradient _getTopicGradient(String topicTitle, {double opacity = 0.6}) {
    Color endColor;
    
    if (topicTitle.toLowerCase().contains('загальн')) {
      endColor = Colors.purple.shade50.withOpacity(opacity);
    } else if (topicTitle.toLowerCase().contains('правила')) {
      endColor = Colors.blue.shade50.withOpacity(opacity);
    } else if (topicTitle.toLowerCase().contains('безпек')) {
      endColor = Colors.green.shade50.withOpacity(opacity);
    } else if (topicTitle.toLowerCase().contains('велосипед')) {
      endColor = Colors.orange.shade50.withOpacity(opacity);
    } else if (topicTitle.toLowerCase().contains('піш')) {
      endColor = Colors.teal.shade50.withOpacity(opacity);
    } else {
      endColor = Colors.indigo.shade50.withOpacity(opacity);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Section-specific gradients (cycling through colors) - EXACT match with module cards
  LinearGradient _getSectionGradient(int sectionIndex) {
    Color endColor;
    
    // Use the exact same color rotation as module cards
    switch (sectionIndex % 5) {
      case 0:
        endColor = Colors.blue.shade50.withOpacity(0.4); // General Provisions color
        break;
      case 1:
        endColor = Colors.green.shade50.withOpacity(0.4); // Traffic Rules color
        break;
      case 2:
        endColor = Colors.orange.shade50.withOpacity(0.4); // Passenger Safety color
        break;
      case 3:
        endColor = Colors.purple.shade50.withOpacity(0.4); // Pedestrian Rights color
        break;
      case 4:
        endColor = Colors.teal.shade50.withOpacity(0.4); // Bicycles and Motorcycles color
        break;
      default:
        endColor = Colors.indigo.shade50.withOpacity(0.4); // Fallback color
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, endColor],
      stops: [0.0, 1.0],
    );
  }

  // Standard shadow configuration
  List<BoxShadow> _getCardShadow() {
    return [
      BoxShadow(
        color: Colors.grey.withOpacity(0.2),
        spreadRadius: 0,
        blurRadius: 6,
        offset: Offset(0, 3),
      ),
    ];
  }

  // Topic icon selection
  IconData _getTopicIcon(String topicTitle) {
    if (topicTitle.toLowerCase().contains('загальн')) {
      return Icons.info_outline;
    } else if (topicTitle.toLowerCase().contains('правила')) {
      return Icons.rule;
    } else if (topicTitle.toLowerCase().contains('безпек')) {
      return Icons.security;
    } else if (topicTitle.toLowerCase().contains('велосипед')) {
      return Icons.directions_bike;
    } else if (topicTitle.toLowerCase().contains('піш')) {
      return Icons.directions_walk;
    } else {
      return Icons.school;
    }
  }

  // Enhanced animated title widget
  Widget _buildEnhancedTopicTitle() {
    final topicIcon = _getTopicIcon(widget.topic.title);
    final gradient = _getTopicGradient(widget.topic.title);
    
    return AnimatedBuilder(
      animation: _titlePulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _titlePulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _getCardShadow(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  topicIcon,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.topic.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Enhanced section title - EXACT match with module card styling
  Widget _buildSectionTitle(String title, int index) {
    // Use the exact same gradient as the section cards for consistency
    LinearGradient titleGradient = _getSectionGradient(index);
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: titleGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.article,
              size: 16,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87, // Match module card text color
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced content text
  Widget _buildSectionContent(String content) {
    // Process content for better formatting
    final processedContent = content
        .replaceAll('\\n•', '\n• ') // Format bullet points with space
        .replaceAll('\\n\\n', '\n\n') // Handle double newlines
        .replaceAll('\\n', '\n'); // Handle regular newlines
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        processedContent,
        style: TextStyle(
          fontSize: 16,
          height: 1.5, // Enhanced line spacing
          color: Colors.black87,
          letterSpacing: 0.2, // Slight letter spacing for readability
        ),
      ),
    );
  }

  // Enhanced section card
  Widget _buildSectionCard(section, int index) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getSectionGradient(index),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _getCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced section title
          if (section.title != null && section.title.isNotEmpty)
            _buildSectionTitle(section.title, index),
          
          if (section.title != null && section.title.isNotEmpty)
            SizedBox(height: 16),
          
          // Enhanced content text
          _buildSectionContent(section.content ?? "No content available"),
        ],
      ),
    );
  }

  // Section divider
  Widget _buildSectionDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: _getTopicGradient(widget.topic.title, opacity: 0.4),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.more_horiz,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced fallback content
  Widget _buildFallbackContent() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getTopicGradient(widget.topic.title),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _getCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic overview header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  _getTopicGradient(widget.topic.title, opacity: 0.3).colors[1],
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getTopicIcon(widget.topic.title),
                  size: 18,
                  color: Colors.indigo.shade700,
                ),
                SizedBox(width: 8),
                Text(
                  "Зміст теми",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          
          // Content container
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.topic.fullContent
                  ?.replaceAll('\\n•', '\n• ')
                  ?.replaceAll('\\n\\n', '\n\n')
                  ?.replaceAll('\\n', '\n') ?? 
                  "No content available for this topic.",
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced error state
  Widget _buildErrorState(Object error) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _getCardShadow(),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.error_outline, 
              size: 48, 
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Error displaying content',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please try again later or contact support if the issue persists.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced content rendering
  Widget _buildEnhancedContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.topic.sections != null && widget.topic.sections.isNotEmpty) 
            ...widget.topic.sections.asMap().entries.map((entry) {
              final int index = entry.key;
              final section = entry.value;
              
              return Column(
                children: [
                  // Enhanced section divider (not for first section)
                  if (index > 0) _buildSectionDivider(),
                  
                  // Enhanced section card
                  _buildSectionCard(section, index),
                ],
              );
            }).toList()
          else 
            _buildFallbackContent(),
        ],
      ),
    );
  }

  // Back to Theory button
  Widget _buildBackToTheoryButton() {
    return Container(
      height: 56,
      margin: EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: Text(
              AppLocalizations.of(context).translate('back_to_theory'),
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildEnhancedTopicTitle(),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              _getTopicGradient(widget.topic.title, opacity: 0.1).colors[1],
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: Column(
          children: [
            // Decorative top border
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                gradient: _getTopicGradient(widget.topic.title, opacity: 0.4),
                border: Border(
                  bottom: BorderSide(
                    color: _getTopicGradient(widget.topic.title, opacity: 0.6).colors[1],
                    width: 1,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            
            // Animated content
            Expanded(
              child: FadeTransition(
                opacity: _contentFadeAnimation,
                child: Builder(
                  builder: (context) {
                    try {
                      return _buildEnhancedContent();
                    } catch (e) {
                      print('Error rendering topic content: $e');
                      return _buildErrorState(e);
                    }
                  },
                ),
              ),
            ),
            
            // Bottom button area
            _buildBackToTheoryButton(),
          ],
        ),
      ),
    );
  }
}
