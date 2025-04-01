import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/state_provider.dart';
import '../localization/app_localizations.dart';
import 'login_screen.dart';

/// A developer/admin screen to reset app settings
/// This is useful for testing and debugging language and state settings
class ResetAppSettingsScreen extends StatelessWidget {
  const ResetAppSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset App Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text('Current language: ${Provider.of<LanguageProvider>(context).language}'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _resetToEnglish(context),
                      child: Text('Reset to English'),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _clearLanguagePreferences(context),
                      child: Text('Clear All Language Preferences'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'State Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text('Current state: ${Provider.of<StateProvider>(context).selectedState?.name ?? "None"}'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _clearStateSelection(context),
                      child: Text('Clear State Selection'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Full Reset',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text('This will reset all app settings and preferences'),
                    SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _resetAllSettings(context),
                      child: Text('Reset All Settings'),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        SnackBar(content: Text('Language reset to English')),
      );
    } catch (e) {
      print('Error resetting language: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting language: $e')),
      );
    }
  }

  // Clear language preferences
  Future<void> _clearLanguagePreferences(BuildContext context) async {
    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      await languageProvider.clearSavedPreferences();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language preferences cleared')),
      );
    } catch (e) {
      print('Error clearing language preferences: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing language preferences: $e')),
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
        SnackBar(content: Text('State selection cleared')),
      );
    } catch (e) {
      print('Error clearing state selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error clearing state selection: $e')),
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
          SnackBar(content: Text('All settings reset')),
        );
      }
    } catch (e) {
      print('Error resetting settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting settings: $e')),
      );
    }
  }
}
