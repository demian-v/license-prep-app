import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../providers/language_provider.dart';

class ModuleCard extends StatefulWidget {
  final TheoryModule module;
  final bool isCompleted;
  final VoidCallback onSelect;

  const ModuleCard({
    Key? key,
    required this.module,
    required this.isCompleted,
    required this.onSelect,
  }) : super(key: key);

  @override
  _ModuleCardState createState() => _ModuleCardState();
}

class _ModuleCardState extends State<ModuleCard> with SingleTickerProviderStateMixin {
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
  
  // Helper method to determine gradient colors based on module type
  LinearGradient _getGradientForModule(TheoryModule module) {
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    // Determine subtle end color based on module type or category
    switch(module.type) {
      case 'traffic_rules':
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 'road_signs':
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 'safety':
        endColor = Colors.orange.shade50.withOpacity(0.4);
        break;
      default:
        // Fallback based on the module order to create variety
        final int colorSeed = module.order % 5;
        switch(colorSeed) {
          case 0:
            endColor = Colors.purple.shade50.withOpacity(0.4);
            break;
          case 1:
            endColor = Colors.teal.shade50.withOpacity(0.4);
            break;
          case 2:
            endColor = Colors.indigo.shade50.withOpacity(0.4);
            break;
          case 3:
            endColor = Colors.amber.shade50.withOpacity(0.4);
            break;
          case 4:
            endColor = Colors.cyan.shade50.withOpacity(0.4);
            break;
          default:
            endColor = Colors.grey.shade50.withOpacity(0.4);
        }
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
    // Get the current language from the LanguageProvider
    final language = Provider.of<LanguageProvider>(context, listen: false).language;
    
    // Translation map for module count phrases in different languages
    final Map<String, String> moduleCountPhrases = {
      'en': 'Module count',
      'uk': 'Кількість модулів',
      'es': 'Cantidad de módulos',
      'ru': 'Количество модулей',
      'pl': 'Liczba modułów',
    };
    
    // Get the correct phrase based on the current language
    final modulePhrase = moduleCountPhrases[language] ?? 'Module count';
    
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
              gradient: _getGradientForModule(widget.module),
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
                onTap: widget.onSelect,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.module.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (widget.isCompleted)
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        widget.module.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 16), // Add spacing back
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildInfoChip(
                            Icons.list_alt,
                            '$modulePhrase: ${widget.module.theoryModulesCount}',
                          ),
                        ],
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

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
