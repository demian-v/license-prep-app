import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _language = 'en'; // Default to English

  String get language => _language;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
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
      default:
        return 'English';
    }
  }
}
