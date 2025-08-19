import 'package:flutter/material.dart';

class EnhancedProfileCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int cardType; // For determining the gradient color
  final bool isHighlighted; // For highlighting the subtitle text if needed

  const EnhancedProfileCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.cardType = 0,
    this.isHighlighted = false,
  }) : super(key: key);

  @override
  _EnhancedProfileCardState createState() => _EnhancedProfileCardState();
}

class _EnhancedProfileCardState extends State<EnhancedProfileCard> with TickerProviderStateMixin {
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
      case 0: // Support - Green
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 1: // Language - Blue
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 2: // State - Purple
        endColor = Colors.purple.shade50.withOpacity(0.4);
        break;
      case 3: // Subscription - Amber
        endColor = Colors.amber.shade50.withOpacity(0.4);
        break;
      case 4: // Reset Statistics - Light Pink
        endColor = Colors.pink.shade50.withOpacity(0.4);
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

  // Helper method to get icon color based on card type
  Color _getIconColor(int cardType) {
    switch(cardType) {
      case 0: return Colors.green;
      case 1: return Colors.blue;
      case 2: return Colors.purple;
      case 3: return Colors.amber.shade700;
      case 4: return Colors.pink;
      default: return Colors.grey;
    }
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
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
                  padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        color: _getIconColor(widget.cardType),
                        size: 28,
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isHighlighted 
                                  ? Colors.green
                                  : Colors.grey.shade700,
                              ),
                            ),
                          ],
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
}
