import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing the app's UI language.
///
/// Handles language selection, persistence, and defaults to English
/// for all new installations.
class LanguageProvider extends ChangeNotifier {
  // Always default to English
  String _language = 'en';
  bool _isLoaded = false;
  bool _forceReset = false;
  static const String DEFAULT_LANGUAGE = 'en';
  static const List<String> SUPPORTED_LANGUAGES = ['en', 'es', 'uk', 'ru', 'pl'];

  // Getters
  String get language => _language;
  bool get isLoaded => _isLoaded;

  // Initialize the provider with option to force English
  LanguageProvider({bool forceEnglish = false}) {
    _forceReset = forceEnglish;
    _loadLanguage();
  }

  // Wait for language to load before using
  Future<void> waitForLoad() async {
    if (_isLoaded) return;
    // Wait up to 3 seconds for language to load
    for (int i = 0; i < 30; i++) {
      if (_isLoaded) return;
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  // Load language from preferences
  Future<void> _loadLanguage() async {
    try {
      print('LanguageProvider: Loading language from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      
      // Check if this is a new install or if we need to force reset
      bool isFirstLaunch = !prefs.containsKey('app_initialized');
      
      // Force reset to English if needed (either by manual trigger or by app reset)
      if (_forceReset) {
        print('LanguageProvider: Forcing reset to English');
        _language = DEFAULT_LANGUAGE;
        await prefs.setString('language', DEFAULT_LANGUAGE);
        await prefs.setBool('app_initialized', true);
        // Clear force reset after applying
        _forceReset = false;
      } 
      // Handle first launch - set English as default
      else if (isFirstLaunch) {
        print('LanguageProvider: First app launch detected, setting English as default');
        _language = DEFAULT_LANGUAGE;
        await prefs.setString('language', DEFAULT_LANGUAGE);
        await prefs.setBool('app_initialized', true);
      }
      // Normal flow - check existing preferences
      else {
        // Check if language has been saved before
        if (!prefs.containsKey('language')) {
          print('LanguageProvider: No language key found, saving default: $_language');
          await prefs.setString('language', DEFAULT_LANGUAGE);
        } else {
          // Load saved language
          final storedLanguage = prefs.getString('language');
          print('LanguageProvider: Raw stored language: $storedLanguage');
          
          if (storedLanguage != null) {
            // Convert 'ua' to 'uk' if found (legacy code)
            if (storedLanguage == 'ua') {
              _language = 'uk';
              await prefs.setString('language', 'uk');
              print('LanguageProvider: Corrected stored language code from ua to uk');
            } 
            // Validate the stored language is a supported one
            else if (SUPPORTED_LANGUAGES.contains(storedLanguage)) {
              _language = storedLanguage;
            } else {
              print('LanguageProvider: Found unsupported language code: $storedLanguage, defaulting to English');
              _language = DEFAULT_LANGUAGE;
              await prefs.setString('language', DEFAULT_LANGUAGE);
            }
            print('LanguageProvider: Loaded language from preferences: $_language');
          } else {
            // Shouldn't happen, but handle just in case
            print('LanguageProvider: Empty language in preferences, using default: $DEFAULT_LANGUAGE');
            _language = DEFAULT_LANGUAGE;
            await prefs.setString('language', DEFAULT_LANGUAGE);
          }
        }
      }
      
      // Verify language was properly saved by reading it back
      final verifyLanguage = prefs.getString('language');
      print('LanguageProvider: Verification: language in prefs is now: $verifyLanguage');
    } catch (e) {
      print('LanguageProvider: Error loading language: $e');
      // On error, set to default language
      _language = DEFAULT_LANGUAGE;
    } finally {
      _isLoaded = true;
      notifyListeners();
      print('LanguageProvider: Finished loading language: $_language (isLoaded: $_isLoaded)');
    }
  }

  // Set language with persistence
  Future<void> setLanguage(String languageCode) async {
    // Convert 'ua' to 'uk' if provided (legacy code)
    if (languageCode == 'ua') {
      languageCode = 'uk';
      print('LanguageProvider: Corrected language code from ua to uk during setLanguage');
    }
    
    // Validate language code
    if (!SUPPORTED_LANGUAGES.contains(languageCode)) {
      print('LanguageProvider: Attempted to set unsupported language: $languageCode, using $DEFAULT_LANGUAGE instead');
      languageCode = DEFAULT_LANGUAGE;
    }
    
    print('LanguageProvider: Setting language to $languageCode (current: $_language)');
    
    // Skip if no change
    if (_language == languageCode) {
      print('LanguageProvider: Language is already $_language, no change needed');
      return;
    }
    
    // Update language
    _language = languageCode;
    
    try {
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', languageCode);
      print('LanguageProvider: Language saved to preferences: $_language');
      
      // Verify it was saved correctly
      final verifiedLanguage = prefs.getString('language');
      print('LanguageProvider: Verified saved language: $verifiedLanguage');
    } catch (e) {
      print('LanguageProvider: Error saving language preference: $e');
    }
    
    // Notify listeners about the change
    notifyListeners();
    print('LanguageProvider: Notified listeners about language change to $_language');
  }

  // Get human-readable language name
  String get languageName {
    switch (_language) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'uk':
        return 'Українська';
      case 'ru':
        return 'Русский';
      case 'pl':
        return 'Polski';
      case 'ua': // Legacy code
        return 'Українська';
      default:
        return 'English';
    }
  }
  
  // Reset language to English (for testing/debugging only)
  Future<void> resetToEnglish() async {
    print('LanguageProvider: Resetting to English');
    _forceReset = true;
    await _loadLanguage();
  }
  
  // Clear all saved language preferences and set to English
  Future<void> clearSavedPreferences() async {
    try {
      print('LanguageProvider: Clearing saved language preferences');
      final prefs = await SharedPreferences.getInstance();
      
      // Remove language key
      if (prefs.containsKey('language')) {
        await prefs.remove('language');
      }
      
      // Remove initialization flag to force defaults
      if (prefs.containsKey('app_initialized')) {
        await prefs.remove('app_initialized');
      }
      
      // Reset to English
      _language = DEFAULT_LANGUAGE;
      await prefs.setString('language', DEFAULT_LANGUAGE);
      
      notifyListeners();
      print('LanguageProvider: Successfully cleared preferences and reset to English');
    } catch (e) {
      print('LanguageProvider: Error clearing preferences: $e');
    }
  }
}
