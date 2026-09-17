import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Risk #50 — the auth funnel was hardcoded English in a five-language product,
/// and `translate()` returns the KEY when a lookup misses, so any refactor
/// toward AppLocalizations puts raw keys like `no_subscription_title` on screen.
/// That failure mode was seen for real earlier in this work.
///
/// Two guards:
///   1. every key the code asks for exists in every locale file, so nobody can
///      ship a screen that renders raw keys in Russian but reads fine in English;
///   2. the auth screens carry no hardcoded user-visible strings.
const authScreens = [
  'lib/screens/login_screen.dart',
  'lib/screens/signup_screen.dart',
  'lib/screens/forgot_password_screen.dart',
  'lib/screens/reset_password_screen.dart',
  'lib/screens/reset_email_sent_screen.dart',
  'lib/screens/password_reset_success_screen.dart',
];

Map<String, Map<String, dynamic>> loadLocales() {
  final out = <String, Map<String, dynamic>>{};
  for (final file in Directory('lib/localization/l10n').listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final name = file.uri.pathSegments.last.replaceAll('.json', '');
    out[name] = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
  return out;
}

Set<String> translateKeysInCode() {
  final keys = <String>{};
  final pattern = RegExp(r"""translate\(\s*(['"])([^'"]+)\1\s*\)""");
  for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    for (final m in pattern.allMatches(file.readAsStringSync())) {
      keys.add(m.group(2)!);
    }
  }
  return keys;
}

void main() {
  group('Risk #50 — every key the code asks for exists in every language', () {
    late Map<String, Map<String, dynamic>> locales;
    late Set<String> used;

    setUpAll(() {
      locales = loadLocales();
      used = translateKeysInCode();
    });

    test('the scan found locales and keys (positive control)', () {
      // Guards against a broken path making every assertion below vacuous.
      expect(locales.keys, containsAll(['en', 'es', 'pl', 'ru', 'uk']));
      expect(used.length, greaterThan(50));
    });

    test('no locale is missing a key the code uses', () {
      final problems = <String>[];
      for (final entry in locales.entries) {
        final missing = used.where((k) => !entry.value.containsKey(k)).toList()..sort();
        if (missing.isNotEmpty) {
          problems.add('${entry.key}: ${missing.join(', ')}');
        }
      }
      expect(problems, isEmpty,
          reason: 'translate() returns the key itself on a miss, so these would '
              'render as raw keys on screen:\n${problems.join('\n')}');
    });

    test('every locale carries the same key set as English', () {
      final en = locales['en']!.keys.toSet();
      for (final entry in locales.entries) {
        if (entry.key == 'en') continue;
        expect(en.difference(entry.value.keys.toSet()), isEmpty,
            reason: '${entry.key} is missing keys that English has');
      }
    });

    test('no translation is left as an empty string', () {
      // An empty value is worse than a missing one: it renders as nothing at
      // all, and the missing-key warning never fires.
      final blanks = <String>[];
      for (final entry in locales.entries) {
        entry.value.forEach((k, v) {
          if (v is String && v.trim().isEmpty) blanks.add('${entry.key}.$k');
        });
      }
      expect(blanks, isEmpty);
    });
  });

  group('Risk #50 — the auth funnel is localised', () {
    test('no auth screen renders a hardcoded English sentence', () {
      // Matches Text('Some words here') — a literal with a space and letters,
      // which is what a user actually reads.
      final hardcoded = RegExp(r"""Text\(\s*(['"])([A-Za-z][^'"]*\s[^'"]*)\1""");
      final offenders = <String>[];

      for (final path in authScreens) {
        final file = File(path);
        if (!file.existsSync()) continue;
        for (final m in hardcoded.allMatches(file.readAsStringSync())) {
          offenders.add('$path: "${m.group(2)}"');
        }
      }

      expect(offenders, isEmpty,
          reason: 'A returning Russian, Ukrainian, Polish or Spanish user meets '
              'these in English:\n${offenders.join('\n')}');
    });

    test('each auth screen actually calls translate (positive control)', () {
      // Without this, deleting the strings entirely would pass the test above.
      for (final path in authScreens) {
        final file = File(path);
        if (!file.existsSync()) continue;
        expect(file.readAsStringSync().contains('translate('), isTrue,
            reason: '$path renders no localised text at all');
      }
    });
  });
}
