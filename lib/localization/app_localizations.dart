import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, String> _localizedStrings;
  
  // Track last loaded language for debug purposes
  String? _lastLoadedLanguage;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    final appLocalizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (appLocalizations == null) {
      print('🚨 [LOCALE ERROR] AppLocalizations.of() returned null! Context might be incorrect.');
      return _fallbackAppLocalizations();
    }
    return appLocalizations;
  }

  // Fallback for cases where context doesn't have AppLocalizations
  static AppLocalizations _fallbackAppLocalizations() {
    print('⚠️ [LOCALE] Creating fallback AppLocalizations with English locale');
    final fallback = AppLocalizations(Locale('en'));
    // Load synchronously to avoid issues
    rootBundle.loadString('lib/localization/l10n/en.json').then((jsonString) {
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;
      fallback._localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
    }).catchError((e) {
      print('🚨 [LOCALE] Error loading fallback language file: $e');
      fallback._localizedStrings = {};
    });
    return fallback;
  }

  // Static member to have a simple access to the delegate from the MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Future<bool> load() async {
    try {
      print('📥 [LOCALE] Loading language file for ${locale.languageCode}');
      // Load the language JSON file from the "l10n" folder
      String jsonString = await rootBundle.loadString('lib/localization/l10n/${locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        return MapEntry(key, value.toString());
      });
      
      _lastLoadedLanguage = locale.languageCode;
      print('✅ [LOCALE] Successfully loaded language file for ${locale.languageCode} with ${jsonMap.length} entries');
      
      // Print some key translations for debugging
      if (jsonMap.containsKey('state_selection')) {
        print('🔤 [LOCALE] state_selection in ${locale.languageCode} = "${jsonMap['state_selection']}"');
      }
      if (jsonMap.containsKey('select_state')) {
        print('🔤 [LOCALE] select_state in ${locale.languageCode} = "${jsonMap['select_state']}"');
      }
      return true;
    } catch (e) {
      print('🚨 [LOCALE] Error loading language file: $e');
      // Fallback to English if there's an error loading the requested language
      if (locale.languageCode != 'en') {
        try {
          String fallbackString = await rootBundle.loadString('lib/localization/l10n/en.json');
          Map<String, dynamic> fallbackMap = json.decode(fallbackString);
          
          _localizedStrings = fallbackMap.map((key, value) {
            return MapEntry(key, value.toString());
          });
          
          print('⚠️ [LOCALE] Falling back to English language');
          return true;
        } catch (fallbackError) {
          print('🚨 [LOCALE] Error loading fallback language: $fallbackError');
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
    // Check if localizedStrings is initialized
    if (!_hasInitializedStrings()) {
      print('🚨 [LOCALE ERROR] translate() called before strings were loaded for ${locale.languageCode}');
      return key;
    }
    
    if (_localizedStrings.containsKey(key)) {
      return _localizedStrings[key]!;
    }
    
    // If we don't have a translation for the key, return the key itself as fallback
    print('⚠️ [MISSING TRANSLATION] Key "$key" in language ${locale.languageCode}');
    return key;
  }
  
  // Check if strings have been initialized
  bool _hasInitializedStrings() {
    try {
      return _localizedStrings.isNotEmpty;
    } catch (e) {
      return false;
    }
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
  
  // Debugging helper to dump all translations
  String dumpTranslations() {
    if (!_hasInitializedStrings()) {
      return "Translations not loaded yet for ${locale.languageCode}";
    }
    
    final buffer = StringBuffer();
    buffer.writeln("Translations for ${locale.languageCode}:");
    _localizedStrings.forEach((key, value) {
      buffer.writeln("  $key: $value");
    });
    return buffer.toString();
  }
}

// LocalizationsDelegate is a factory for a set of localized resources
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    print('📋 [LOCALE DELEGATE] isSupported checking: ${locale.languageCode}');
    final supported = ['en', 'es', 'uk', 'ru', 'pl'].contains(locale.languageCode);
    print('${supported ? '✅' : '❌'} [LOCALE DELEGATE] Support result: $supported for ${locale.languageCode}');
    return supported;
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    print('📥 [LOCALE DELEGATE] load starting for ${locale.languageCode}');
    // AppLocalizations class is where the JSON loading actually runs
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    print('✅ [LOCALE DELEGATE] load complete for ${locale.languageCode}');
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) {
    // Always return true to force reload on language change
    print('🔄 [LOCALE DELEGATE] shouldReload called - returning true');
    return true; 
  }
}
