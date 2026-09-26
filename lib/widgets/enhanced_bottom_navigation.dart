import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

/// The tab bar.
///
/// Rebuilt to the pattern Instagram and Telegram both use: a hairline rule, a
/// flat surface, and **selection carried by the icon itself** — filled when
/// active, outline when not.
///
/// What it replaces: each tab was an animated `LinearGradient` that painted a
/// lavender wash behind the active item, running three `AnimationController`s.
/// The colour came from Material 3's default seed, not from the brand, so the
/// most persistent chrome in the app was tinted a purple nobody chose.
///
/// Labels are kept, unlike Instagram's icon-only bar: the app ships in five
/// languages to people learning a new country's road rules, and an unlabelled
/// glyph is a guess. Telegram keeps its labels for the same reason.
class EnhancedBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const EnhancedBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  static const List<_Tab> _tabs = [
    _Tab('tests', AppIcons.tests, AppIcons.testsFilled),
    _Tab('theory', AppIcons.theory, AppIcons.theoryFilled),
    _Tab('profile', AppIcons.profile, AppIcons.profileFilled),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.paper,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final tab = _tabs[index];
                  final selected = index == currentIndex;
                  final label = _translate(tab.key, languageProvider);
                  final color =
                      selected ? AppColors.signal : AppColors.inkTertiary;

                  return Expanded(
                    child: Semantics(
                      selected: selected,
                      button: true,
                      child: InkWell(
                        onTap: () => onTap(index),
                        // No ink splash box: the bar is flat, and a rectangular
                        // highlight would reintroduce the shape just removed.
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppIcons.icon(
                              selected ? tab.filled : tab.outline,
                              size: 25,
                              color: color,
                            ),
                            const SizedBox(height: AppSpacing.x1),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: color,
                                fontSize: 11,
                                fontVariations: [
                                  FontVariation('wght', selected ? 700 : 500),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

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
}

class _Tab {
  const _Tab(this.key, this.outline, this.filled);

  final String key;
  final String outline;
  final String filled;
}
