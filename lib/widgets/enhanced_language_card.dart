import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// A language in the signup picker, as a Bento row: the flag, the language in
/// its own name with the English name under it, a chevron. The chosen row
/// turns the dark `ink` row while the app switches, as the Профиль pickers
/// (owner: "select black, not blue… no check"). The old per-language pastel
/// washes are gone.
class EnhancedLanguageCard extends StatefulWidget {
  final String language;
  final String languageCode;
  final VoidCallback? onTap;
  final bool isEnabled;
  final bool isSelected;
  
  const EnhancedLanguageCard({
    Key? key,
    required this.language,
    required this.languageCode,
    this.onTap,
    this.isEnabled = true,
    this.isSelected = false,
  }) : super(key: key);

  @override
  _EnhancedLanguageCardState createState() => _EnhancedLanguageCardState();
}

class _EnhancedLanguageCardState extends State<EnhancedLanguageCard> {
  /// Each language in its own name, as the Профиль picker — display only;
  /// [EnhancedLanguageCard.language] (English) still goes to analytics.
  static const Map<String, String> _nativeNames = {
    'en': 'English',
    'es': 'Español',
    'uk': 'Українська',
    'pl': 'Polski',
    'ru': 'Русский',
  };

  // Helper method to get language icon asset path
  String? _getLanguageIconAsset(String languageCode) {
    // Map language codes to their corresponding asset paths
    final Map<String, String> languageIcons = {
      'en': 'assets/images/languages/EN.png',
      'es': 'assets/images/languages/ES.png',
      'uk': 'assets/images/languages/UA.png',  // Ukrainian uses UA file
      'pl': 'assets/images/languages/PL.png',
      'ru': 'assets/images/languages/RU.png',
    };
    
    return languageIcons[languageCode];
  }
  
  // Helper method to get icon for each language (kept for fallback)
  IconData _getLanguageIcon(String code) {
    // Language-specific icons that better represent each language
    final Map<String, IconData> languageIcons = {
      'en': SolarIcons.globalLinear, // English - world language
      'es': SolarIcons.textSquareLinear,       // Spanish - text format for Latin alphabet
      'uk': SolarIcons.chatRoundLineBold,         // Ukrainian - translation icon
      'pl': SolarIcons.textSquareBold,     // Polish - font icon
      'ru': SolarIcons.chatRoundLineLinear, // Russian - alternate translation icon
    };
    
    return languageIcons[code] ?? SolarIcons.globalLinear;
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
  
  /// The language code on a grey chip, if a flag picture is missing.
  Widget _buildFallbackFlag() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.languageCode.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: AppColors.inkSecondary,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    final asset = _getLanguageIconAsset(widget.languageCode);
    final nativeName = _nativeNames[widget.languageCode] ?? widget.language;
    final showEnglish = nativeName != widget.language;

    return Opacity(
      opacity: widget.isEnabled || selected ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: PressScale(
          enabled: widget.isEnabled,
          child: DecoratedBox(
            // The fill and shadow sit under the Material, so the shadow does
            // not paint over the white.
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: selected ? null : AppColors.shadowCard,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(BentoTokens.card),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                      vertical: AppSpacing.x3,
                    ),
                    child: Row(
                      children: [
                        // The mark on a tile, so the blue letters still
                        // read on the dark row.
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.paper : AppColors.field,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Center(
                            child: asset != null
                                ? Image.asset(
                                    asset,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildFallbackFlag(),
                                  )
                                : _buildFallbackFlag(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nativeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body.copyWith(
                                  fontSize: 17,
                                  height: 22 / 17,
                                  color: selected ? AppColors.onSignal : AppColors.ink,
                                  fontVariations: const [FontVariation('wght', 600)],
                                ),
                              ),
                              if (showEnglish)
                                Text(
                                  widget.language,
                                  maxLines: 1,
                                  style: AppTypography.label.copyWith(
                                    color: selected
                                        ? AppColors.onSignal.withValues(alpha: 0.7)
                                        : AppColors.inkSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        Icon(
                          SolarIcons.altArrowRightLinear,
                          color: selected ? AppColors.onSignal : AppColors.inkTertiary,
                          size: 20,
                        ),
                      ],
                    ),
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
