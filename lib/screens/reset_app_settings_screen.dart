import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/state_provider.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

/// A developer/admin screen to reset app settings
/// This is useful for testing and debugging language and state settings
class ResetAppSettingsScreen extends StatelessWidget {
  const ResetAppSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final l = localizations;

    // Bento (2026-09-26): the heading app bar, then each group as a white
    // card — a heading, what is set now, and its actions as field pills. The
    // full reset's pill has a red label, as the delete-account confirm.
    final blocks = <Widget>[
      _group(
        heading: l.translate('dev_reset_language_heading'),
        current: l.translate('dev_reset_current_language').replaceAll(
            '{language}',
            _nativeLanguageNames[Provider.of<LanguageProvider>(context).language] ??
                Provider.of<LanguageProvider>(context).language),
        actions: [
          BentoActionButton(
            text: l.translate('dev_reset_to_english'),
            primary: false,
            onCard: true,
            onTap: () => _resetToEnglish(context),
          ),
          BentoActionButton(
            text: l.translate('dev_reset_clear_language'),
            primary: false,
            onCard: true,
            onTap: () => _clearLanguagePreferences(context),
          ),
        ],
      ),
      _group(
        heading: l.translate('dev_reset_state_heading'),
        current: l.translate('dev_reset_current_state').replaceAll(
            '{state}',
            _titleCase(Provider.of<StateProvider>(context).selectedState?.name) ??
                l.translate('dev_reset_none')),
        actions: [
          BentoActionButton(
            text: l.translate('dev_reset_clear_state'),
            primary: false,
            onCard: true,
            onTap: () => _clearStateSelection(context),
          ),
        ],
      ),
      _group(
        heading: l.translate('dev_reset_full_heading'),
        current: l.translate('dev_reset_full_desc'),
        actions: [
          _destructivePill(
            context,
            text: l.translate('dev_reset_all'),
            onTap: () => _resetAllSettings(context),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: l.translate('dev_reset_title'),
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x2,
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x6,
          ),
          children: [
            for (var i = 0; i < blocks.length; i++)
              StaggerIn(
                index: i,
                count: blocks.length,
                curve: BentoTokens.curve,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: blocks[i],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Display only: each language in its own name, as in the pickers.
  static const Map<String, String> _nativeLanguageNames = {
    'en': 'English',
    'es': 'Español',
    'uk': 'Українська',
    'pl': 'Polski',
    'ru': 'Русский',
  };

  /// «NEW YORK» → «New York», as the state picker shows it.
  static String? _titleCase(String? name) => name
      ?.split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  /// One settings group as a white card.
  Widget _group({
    required String heading,
    required String current,
    required List<Widget> actions,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            heading,
            style: AppTypography.body.copyWith(
              fontSize: 17,
              height: 22 / 17,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            current,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              height: 22 / 15,
              color: AppColors.inkSecondary,
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(height: AppSpacing.x3),
            action,
          ],
        ],
      ),
    );
  }

  /// A field pill with a red label — destructive, but not shouting.
  Widget _destructivePill(
    BuildContext context, {
    required String text,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Material(
        color: AppColors.field,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label.copyWith(
                  fontSize: 16,
                  color: AppColors.stop,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Reset language to English
  Future<void> _resetToEnglish(BuildContext context) async {
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      await languageProvider.resetToEnglish();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_done_english')),
          backgroundColor: AppColors.guide,
        ),
      );
    } catch (e) {
      print('Error resetting language: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_err_english').replaceAll('{error}', '$e')),
          backgroundColor: AppColors.stop,
        ),
      );
    }
  }

  // Clear language preferences
  Future<void> _clearLanguagePreferences(BuildContext context) async {
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      await languageProvider.clearSavedPreferences();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_done_language_cleared')),
          backgroundColor: AppColors.guide,
        ),
      );
    } catch (e) {
      print('Error clearing language preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_err_language_cleared').replaceAll('{error}', '$e')),
          backgroundColor: AppColors.stop,
        ),
      );
    }
  }

  // Clear state selection
  Future<void> _clearStateSelection(BuildContext context) async {
    try {
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      
      // Clear state preference
      if (prefs.containsKey('selected_state')) {
        await prefs.remove('selected_state');
      }
      
      // Reset state provider
      await stateProvider.initialize();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_done_state_cleared')),
          backgroundColor: AppColors.guide,
        ),
      );
    } catch (e) {
      print('Error clearing state selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_err_state_cleared').replaceAll('{error}', '$e')),
          backgroundColor: AppColors.stop,
        ),
      );
    }
  }

  // Reset all settings
  Future<void> _resetAllSettings(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear app initialized flag
      if (prefs.containsKey('app_initialized')) {
        await prefs.remove('app_initialized');
      }
      
      // Clear language preference
      if (prefs.containsKey('language')) {
        await prefs.remove('language');
      }
      
      // Clear state preference
      if (prefs.containsKey('selected_state')) {
        await prefs.remove('selected_state');
      }

      // Clear the first-run onboarding flag, so it shows again
      if (prefs.containsKey(OnboardingGate.prefsKey)) {
        await prefs.remove(OnboardingGate.prefsKey);
      }

      // Reset providers
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      await languageProvider.resetToEnglish();
      
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      await stateProvider.initialize();
      
      // Sign out user if needed
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        await authProvider.logout();
        
        // Navigate to login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('dev_reset_done_all')),
            backgroundColor: AppColors.guide,
          ),
        );
      }
    } catch (e) {
      print('Error resetting settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('dev_reset_err_all').replaceAll('{error}', '$e')),
          backgroundColor: AppColors.stop,
        ),
      );
    }
  }
}
