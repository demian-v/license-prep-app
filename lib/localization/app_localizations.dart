import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, String> _localizedStrings;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    try {
      // Load the language JSON file from the "l10n" folder (with 'lib/' prefix removed)
      String jsonString = await rootBundle.loadString('lib/localization/l10n/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });

      return true;
    } catch (e) {
      print('Error loading language file: $e');
      // Fallback to English if there's an error loading the requested language
      if (locale.languageCode != 'en') {
        try {
          String fallbackString = await rootBundle.loadString('lib/localization/l10n/en.json');
          Map<String, dynamic> fallbackMap = json.decode(fallbackString);
          
          _localizedStrings = fallbackMap.map((key, value) {
            return MapEntry(key, value.toString());
          });
          
          print('Falling back to English language');
          return true;
        } catch (fallbackError) {
          print('Error loading fallback language: $fallbackError');
          _localizedStrings = {};
          return false;
        }
      }
      _localizedStrings = {};
      return false;
    }
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    if (_localizedStrings.containsKey(key)) {
      return _localizedStrings[key]!;
    }
    // If we don't have a translation for the key, return the key itself as fallback
    return key;
  }

  // Get all supported locales for the app
  static List<Locale> supportedLocales() {
    return const [
      Locale('en', ''), // English
      Locale('es', ''), // Spanish
      Locale('uk', ''), // Ukrainian
      Locale('ru', ''), // Russian
      Locale('pl', ''), // Polish
    ];
  }
}

// LocalizationsDelegate is a factory for a set of localized resources
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'es', 'uk', 'ru', 'pl'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading actually runs
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
