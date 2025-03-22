import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _language = 'uk'; // Default to Ukrainian (using proper ISO code)

  String get language => _language;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'uk';
    
    // Convert 'ua' to 'uk' if found
    if (_language == 'ua') {
      _language = 'uk';
      // Save the corrected value back to SharedPreferences
      await prefs.setString('language', 'uk');
      print('Corrected stored language code from ua to uk');
    }
    
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    // Convert 'ua' to 'uk' if provided
    if (languageCode == 'ua') {
      languageCode = 'uk';
      print('Corrected language code from ua to uk during setLanguage');
    }
    
    _language = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    notifyListeners();
  }

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
      case 'ua':
        return 'Українська';
      default:
        return 'English';
    }
  }
}
