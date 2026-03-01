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
    final w = constraints.maxWidth;

    // Compute font & icon size from the actual available width.
    // < 310 px  → tiny (old small-phone behaviour, keeps ellipsis as safety)
    // 310–380px → normal (most iPhones in portrait)
    // > 380 px  → larger (iPhone Plus/Max/Pro Max, iPad, landscape)
    final double fontSize;
    final double iconSize;
    final bool allowFullText;

    if (w < 310) {
      fontSize = 10.0;
      iconSize = 12.0;
      allowFullText = false; // ellipsis safety net on tiny screens
    } else if (w < 380) {
      fontSize = 12.0;
      iconSize = 14.0;
      allowFullText = true;
    } else {
      fontSize = 14.0;
      iconSize = 16.0;
      allowFullText = true;
    }

    // Extremely narrow containers → vertical stack to avoid overflow
    if (w < 270) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.leftInfoText != null)
            _buildInfoChip(Icons.timer, widget.leftInfoText!,
                fontSize: fontSize, iconSize: iconSize, allowFullText: allowFullText),
          if (widget.leftInfoText != null && widget.rightInfoText != null)
            SizedBox(height: 4),
          if (widget.rightInfoText != null)
            _buildInfoChip(Icons.quiz, widget.rightInfoText!,
                fontSize: fontSize, iconSize: iconSize, allowFullText: allowFullText),
        ],
      );
    }

    // All other widths → horizontal row with spaceBetween
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.leftInfoText != null)
          _buildInfoChip(Icons.timer, widget.leftInfoText!,
              fontSize: fontSize, iconSize: iconSize, allowFullText: allowFullText),
        if (widget.rightInfoText != null)
          _buildInfoChip(Icons.quiz, widget.rightInfoText!,
              fontSize: fontSize, iconSize: iconSize, allowFullText: allowFullText),
      ],
    );
  }

  Widget _buildInfoChip(
    IconData icon,
    String text, {
    required double fontSize,
    required double iconSize,
    required bool allowFullText,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: Colors.grey.shade600),
        SizedBox(width: 4),
        Text(
          text, // never truncate manually — let Flutter decide
          style: TextStyle(fontSize: fontSize, color: Colors.grey.shade600),
          maxLines: allowFullText ? null : 1,
          overflow: allowFullText ? TextOverflow.visible : TextOverflow.ellipsis,
          softWrap: allowFullText,
        ),
      ],
    );
  }
}
