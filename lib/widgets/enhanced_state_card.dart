import 'package:flutter/material.dart';

class EnhancedStateCard extends StatefulWidget {
  final String stateName;
  final bool isSelected;
  final VoidCallback onTap;
  final String subtitleText;
  
  const EnhancedStateCard({
    Key? key,
    required this.stateName,
    required this.isSelected,
    required this.onTap,
    required this.subtitleText,
  }) : super(key: key);

  @override
  _EnhancedStateCardState createState() => _EnhancedStateCardState();
}

class _EnhancedStateCardState extends State<EnhancedStateCard> with SingleTickerProviderStateMixin {
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
  
  // Helper method to get softer pastel icon colors that are still visible
  Color _getBrighterIconColor(String stateName) {
    final int stateNameHash = stateName.length + (stateName.isNotEmpty ? stateName.codeUnitAt(0) : 0);
    final int colorIndex = stateNameHash % 7;
    
    // Softer pastel colors that are still visible
    switch (colorIndex) {
      case 0:
        // Soft purple
        return Color(0xFFB39DDB); // Purple 200
      case 1:
        // Soft green
        return Color(0xFFA5D6A7); // Green 200
      case 2:
        // Soft orange
        return Color(0xFFFFCC80); // Orange 200
      case 3:
        // Soft blue
        return Color(0xFF90CAF9); // Blue 200
      case 4:
        // Soft pink
        return Color(0xFFF48FB1); // Pink 200
      case 5:
        // Soft yellow-green
        return Color(0xFFE6EE9C); // Lime 200
      case 6:
        // Soft cyan
        return Color(0xFF80DEEA); // Cyan 200
      default:
        // Default color
        return Color(0xFF80CBC4); // Teal 200
    }
  }
  
  // Helper method to get gradient for state cards with consistent pastel colors
  LinearGradient _getGradientForState(bool isSelected, String stateName) {
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    // Create a more uniform color distribution based on state names
    // Using modulo with a prime number to distribute colors more evenly
    final int stateNameHash = stateName.length + (stateName.isNotEmpty ? stateName.codeUnitAt(0) : 0);
    final int colorIndex = stateNameHash % 7;
    
    // Softer pastel colors with consistent opacity
    const double baseOpacity = 0.3; // Lower base opacity for all states
    
    switch (colorIndex) {
      case 0:
        // Lavender - very soft purple
        endColor = Color(0xFFE6E6FA).withOpacity(baseOpacity);
        break;
      case 1:
        // Mint - soft green
        endColor = Color(0xFFF5FFFA).withOpacity(baseOpacity);
        break;
      case 2:
        // Peach - softer orange (similar to Passenger Safety card)
        endColor = Color(0xFFFFF0E6).withOpacity(baseOpacity);
        break;
      case 3:
        // Sky - soft blue
        endColor = Color(0xFFF0F8FF).withOpacity(baseOpacity);
        break;
      case 4:
        // Rose - soft pink
        endColor = Color(0xFFFFF0F5).withOpacity(baseOpacity);
        break;
      case 5:
        // Honeydew - soft yellow-green
        endColor = Color(0xFFF0FFF0).withOpacity(baseOpacity);
        break;
      case 6:
        // Misty - soft cyan
        endColor = Color(0xFFE0FFFF).withOpacity(baseOpacity);
        break;
      default:
        // Almond - soft beige
        endColor = Color(0xFFFFEBCD).withOpacity(baseOpacity);
    }
    
    // If selected, make the color slightly more vivid but still soft
    if (isSelected) {
      // Increase opacity for selected state but maintain pastel tone
      endColor = endColor.withOpacity(baseOpacity + 0.1);
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
              gradient: _getGradientForState(widget.isSelected, widget.stateName),
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
                  child: Row(
                    children: [
                      // State icon/label with background color matching the card gradient (like language cards)
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          // Use a brighter color for the icon background
                          color: _getBrighterIconColor(widget.stateName),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.25),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.stateName.isNotEmpty ? widget.stateName.substring(0, 2).toUpperCase() : "",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      // State name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Convert state name to title case for display
                              widget.stateName.split(' ').map((word) => 
                                word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                              ).join(' '),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.subtitleText,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Checkmark for selected state
                      if (widget.isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      // Arrow icon if not selected
                      if (!widget.isSelected)
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
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
