import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('🧭 [BOTTOM NAV] Building with language: ${languageProvider.language}');
        
        return BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.quiz),
              label: _translate('tests', languageProvider),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: _translate('theory', languageProvider),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: _translate('profile', languageProvider),
            ),
          ],
        );
      }
    );
  }
}
