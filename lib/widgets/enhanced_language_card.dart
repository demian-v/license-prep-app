import 'package:flutter/material.dart';

class EnhancedLanguageCard extends StatefulWidget {
  final String language;
  final String languageCode;
  final VoidCallback onTap;
  
  const EnhancedLanguageCard({
    Key? key,
    required this.language,
    required this.languageCode,
    required this.onTap,
  }) : super(key: key);

  @override
  _EnhancedLanguageCardState createState() => _EnhancedLanguageCardState();
}

class _EnhancedLanguageCardState extends State<EnhancedLanguageCard> with SingleTickerProviderStateMixin {
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
  
  // Helper method to get icon for each language
  IconData _getLanguageIcon(String code) {
    // Language-specific icons that better represent each language
    final Map<String, IconData> languageIcons = {
      'en': Icons.language_outlined, // English - world language
      'es': Icons.text_format,       // Spanish - text format for Latin alphabet
      'uk': Icons.translate,         // Ukrainian - translation icon
      'pl': Icons.font_download,     // Polish - font icon
      'ru': Icons.translate_outlined, // Russian - alternate translation icon
    };
    
    return languageIcons[code] ?? Icons.language;
  }
  
  // Helper method to get vibrant colors for language labels
  Color _getLabelColor(String code) {
    switch(code) {
      case 'en': // English
        return Colors.blue;
      case 'es': // Spanish
        return Colors.pink;
      case 'uk': // Ukrainian
        return Colors.cyan;
      case 'pl': // Polish
        return Colors.green;
      case 'ru': // Russian
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Helper method to get softer pastel colors for language icons
  Color _getSofterPastelColor(String code) {
    switch(code) {
      case 'en': // English - soft blue
        return Color(0xFF90CAF9); // Blue 200
      case 'es': // Spanish - soft pink
        return Color(0xFFF48FB1); // Pink 200
      case 'uk': // Ukrainian - soft cyan
        return Color(0xFF80DEEA); // Cyan 200
      case 'pl': // Polish - soft green
        return Color(0xFFA5D6A7); // Green 200
      case 'ru': // Russian - soft red
        return Color(0xFFEF9A9A); // Red 200
      default:
        return Color(0xFFB0BEC5); // Blue Grey 200
    }
  }
  
  // Helper method to get gradient for language cards
  LinearGradient _getGradientForLanguage(String code) {
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    // Apply the same pattern as ModuleCard
    switch(code) {
      case 'en': // English
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 'es': // Spanish
        endColor = Colors.pink.shade50.withOpacity(0.4);
        break;
      case 'uk': // Ukrainian
        endColor = Colors.cyan.shade50.withOpacity(0.4);
        break;
      case 'pl': // Polish
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 'ru': // Russian
        endColor = Colors.red.shade50.withOpacity(0.4);
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
              gradient: _getGradientForLanguage(widget.languageCode),
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
                      // Language code label with moderately visible background (20% more visible than original)
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          // Use softer pastel colors for language icons
                          color: _getSofterPastelColor(widget.languageCode),
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
                            widget.languageCode.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      // Language name
                      Expanded(
                        child: Text(
                          widget.language,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Arrow icon
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
