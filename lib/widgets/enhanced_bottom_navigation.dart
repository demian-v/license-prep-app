import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class EnhancedBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const EnhancedBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  _EnhancedBottomNavigationState createState() => _EnhancedBottomNavigationState();
}

class _EnhancedBottomNavigationState extends State<EnhancedBottomNavigation> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  
  @override
  void initState() {
    super.initState();
    // Initialize controllers for each tab
    _controllers = List.generate(3, (index) => 
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300),
      )
    );
    
    // Create animations for each tab
    _animations = _controllers.map((controller) => 
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut)
      )
    ).toList();
  }
  
  @override
  void dispose() {
    // Dispose all controllers when widget is removed
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language based on the language provider
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
      print('🚨 [BOTTOM NAV] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  Widget _buildTabItem(int index, String label, IconData icon, bool isSelected) {
    // Get theme colors
    final primaryColor = Theme.of(context).primaryColor;
    final unselectedColor = Colors.grey;
    
    // Start or reverse animation based on tab selection
    if (isSelected) {
      _controllers[index].forward();
    } else {
      _controllers[index].reverse();
    }
    
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onTap(index),
        child: AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            // Calculate the gradient stops based on animation value
            final animValue = _animations[index].value;
            return Container(
              height: 56, // Standard bottom navigation height
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    isSelected ? primaryColor.withOpacity(0.05) : Colors.transparent,
                    isSelected ? primaryColor.withOpacity(0.05) : Colors.transparent,
                    Colors.transparent,
                  ],
                  // Animate gradient stops to create the "disappearing from sides" effect
                  stops: [
                    0.0,
                    0.3 + (animValue * 0.2), // Left edge moves inward
                    0.7 - (animValue * 0.2), // Right edge moves inward
                    1.0,
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? primaryColor : unselectedColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? primaryColor : unselectedColor,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        // Define tab data
        final tabs = [
          {'key': 'tests', 'icon': Icons.quiz},
          {'key': 'theory', 'icon': Icons.menu_book},
          {'key': 'profile', 'icon': Icons.person},
        ];
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white.withOpacity(0.95)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isSelected = index == widget.currentIndex;
                final label = _translate(tab['key'] as String, languageProvider);
                
                return _buildTabItem(
                  index, 
                  label,
                  tab['icon'] as IconData,
                  isSelected,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
