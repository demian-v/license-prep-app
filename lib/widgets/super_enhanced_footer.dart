import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class SuperEnhancedFooter extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SuperEnhancedFooter({
    Key? key, 
    required this.currentIndex, 
    required this.onTap,
  }) : super(key: key);

  @override
  _SuperEnhancedFooterState createState() => _SuperEnhancedFooterState();
}

class _SuperEnhancedFooterState extends State<SuperEnhancedFooter> with TickerProviderStateMixin {
  // Individual animation controllers for each tab
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _colorAnimations;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers for each tab (Tests, Theory, Profile)
    _controllers = List.generate(3, (index) => 
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 200),
      )
    );
    
    // Scale animations for press effect
    _scaleAnimations = _controllers.map((controller) => 
      Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut)
      )
    ).toList();
    
    // Color animations for transitioning between selected/unselected
    _colorAnimations = _controllers.map((controller) => 
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut)
      )
    ).toList();
    
    // Initialize selected tab
    _updateSelectedTab();
  }
  
  @override
  void didUpdateWidget(SuperEnhancedFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update animations when selected tab changes
    if (oldWidget.currentIndex != widget.currentIndex) {
      _updateSelectedTab();
    }
  }
  
  void _updateSelectedTab() {
    // Reset all controllers
    for (var controller in _controllers) {
      controller.reverse();
    }
    
    // Animate the selected tab
    if (widget.currentIndex >= 0 && widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }
  }
  
  @override
  void dispose() {
    // Clean up all controllers
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    try {
      switch (languageProvider.language) {
        case 'es':
          return {
            'tests': 'Pruebas',
            'theory': 'Teoría',
            'profile': 'Perfil',
          }[key] ?? key;
        case 'uk':
          return {
            'tests': 'Тести',
            'theory': 'Теорія',
            'profile': 'Профіль',
          }[key] ?? key;
        case 'ru':
          return {
            'tests': 'Тесты',
            'theory': 'Теория',
            'profile': 'Профиль',
          }[key] ?? key;
        case 'pl':
          return {
            'tests': 'Testy',
            'theory': 'Teoria',
            'profile': 'Profil',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'tests': 'Tests',
            'theory': 'Theory',
            'profile': 'Profile',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [SUPER FOOTER] Error getting translation: $e');
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(0, 'tests', Icons.quiz, languageProvider),
                _buildTabItem(1, 'theory', Icons.menu_book, languageProvider),
                _buildTabItem(2, 'profile', Icons.person, languageProvider),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildTabItem(int index, String key, IconData icon, LanguageProvider languageProvider) {
    final bool isSelected = index == widget.currentIndex;
    final Animation<double> animation = _colorAnimations[index];
  
    // Define colors based on tab type
    Color selectedColor;
    List<Color> gradientColors;
    
    // Use the same indigo color scheme for all tabs to match the Sign Up button
    switch(index) {
      case 0: // Tests
        selectedColor = Colors.indigo.shade700;
        gradientColors = [
          Colors.white,
          Colors.indigo.shade50.withOpacity(0.7),
        ];
        break;
      case 1: // Theory
        selectedColor = Colors.indigo.shade700;
        gradientColors = [
          Colors.white,
          Colors.indigo.shade50.withOpacity(0.7),
        ];
        break;
      case 2: // Profile
        selectedColor = Colors.indigo.shade700;
        gradientColors = [
          Colors.white,
          Colors.indigo.shade50.withOpacity(0.7),
        ];
        break;
      default:
        selectedColor = Colors.indigo.shade700;
        gradientColors = [
          Colors.white,
          Colors.indigo.shade50.withOpacity(0.7),
        ];
    }
  
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _controllers[index].forward(),
        onTapUp: (_) {
          _controllers[index].reverse();
          widget.onTap(index);
        },
        onTapCancel: () => _controllers[index].reverse(),
        child: ScaleTransition(
          scale: _scaleAnimations[index],
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // Use the same icon and text colors as the Sign Up button
              final Color iconColor = Color.lerp(
                Colors.grey,           // Unselected color
                Colors.indigo.shade700, // Selected color (matching Sign Up button text)
                animation.value
              )!;
              
              final Color textColor = Color.lerp(
                Colors.grey,           // Unselected color
                Colors.indigo.shade700, // Selected color (matching Sign Up button text)
                animation.value
              )!;
              
              // Determine background gradient or solid color
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  gradient: isSelected ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.indigo.shade50.withOpacity(animation.value * 0.7),
                    ],
                  ) : null,
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2 * animation.value),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ] : null,
                ),
                child: SizedBox(
                  height: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: iconColor,
                        size: 26,
                      ),
                      SizedBox(height: 4),
                      Text(
                        _translate(key, languageProvider),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
