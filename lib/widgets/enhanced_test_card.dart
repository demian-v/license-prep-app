import 'package:flutter/material.dart';

class EnhancedTestCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon; // Kept for backward compatibility
  final VoidCallback onTap;
  final String? leftInfoText;
  final String? rightInfoText;
  final int cardType; // Used for gradient coloring

  const EnhancedTestCard({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.leftInfoText,
    this.rightInfoText,
    this.cardType = 0,
  }) : super(key: key);

  @override
  _EnhancedTestCardState createState() => _EnhancedTestCardState();
}

class _EnhancedTestCardState extends State<EnhancedTestCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  // Helper method to determine gradient colors based on card type
  LinearGradient _getGradientForCard(int cardType) {
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    // Determine subtle end color based on card type
    switch(cardType) {
      case 0: // Take Exam
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 1: // Learn by Topics
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 2: // Practice Tickets
        endColor = Colors.orange.shade50.withOpacity(0.4);
        break;
      case 3: // Saved
        endColor = Colors.purple.shade50.withOpacity(0.4);
        break;
      default:
        endColor = Colors.grey.shade50.withOpacity(0.4);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.3),
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: _getGradientForCard(widget.cardType),
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
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and description without the icon
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      // Responsive info chip row
                      if (widget.leftInfoText != null || widget.rightInfoText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return _buildResponsiveInfoRow(constraints);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build responsive info row based on available width
  Widget _buildResponsiveInfoRow(BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Use available container width rather than screen width for better responsiveness
    final isVerySmallContainer = availableWidth < 300;
    final isSmallContainer = availableWidth < 350;
    final isMediumContainer = availableWidth >= 350 && availableWidth < 500;

    // For extremely narrow containers, use vertical layout to prevent any overflow
    if (isVerySmallContainer && availableWidth < 280) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.leftInfoText != null)
            _buildInfoChip(Icons.timer, widget.leftInfoText!, isSmallScreen: true),
          if (widget.leftInfoText != null && widget.rightInfoText != null)
            SizedBox(height: 4),
          if (widget.rightInfoText != null)
            _buildInfoChip(Icons.quiz, widget.rightInfoText!, isSmallScreen: true, allowFullText: false),
        ],
      );
    }

    // For small containers, use constrained horizontal layout with flex
    if (isSmallContainer) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leftInfoText != null)
            Flexible(
              flex: 1,
              child: _buildInfoChip(Icons.timer, widget.leftInfoText!, isSmallScreen: true),
            ),
          if (widget.leftInfoText != null && widget.rightInfoText != null)
            SizedBox(width: 8),
          if (widget.rightInfoText != null)
            Flexible(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildInfoChip(Icons.quiz, widget.rightInfoText!, isSmallScreen: true, allowFullText: false),
              ),
            ),
        ],
      );
    }

    // For medium and large containers, use spaceBetween layout
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.leftInfoText != null)
          Flexible(
            child: _buildInfoChip(Icons.timer, widget.leftInfoText!, isSmallScreen: false),
          ),
        if (widget.rightInfoText != null)
          Flexible(
            child: _buildInfoChip(
              Icons.quiz, 
              widget.rightInfoText!, 
              isSmallScreen: false,
              allowFullText: !isMediumContainer || availableWidth > 380,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {bool isSmallScreen = false, bool allowFullText = false}) {
    final fontSize = isSmallScreen ? 10.0 : 12.0;
    final iconSize = isSmallScreen ? 12.0 : 14.0;
    
    // For very small screens, truncate text more aggressively
    String displayText = text;
    if (isSmallScreen && text.length > 15) {
      displayText = text.length > 15 ? '${text.substring(0, 12)}...' : text;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: Colors.grey.shade600,
        ),
        SizedBox(width: 4),
        Flexible(
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey.shade600,
            ),
            maxLines: allowFullText ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            softWrap: allowFullText,
          ),
        ),
      ],
    );
  }
}
