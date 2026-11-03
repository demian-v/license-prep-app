import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/theme/solar_icons.dart';
import 'package:license_prep_app/widgets/enhanced_profile_card.dart';

/// Profile's State row: the description ran up against the chip (owner,
/// 2026-11-02). The title says State and the chip names it, so the description
/// says only what the setting drives.
void main() {
  test('the State description stays short in every language', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();
    for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
      final strings = jsonDecode(File('lib/localization/l10n/$locale.json').readAsStringSync());
      final text = strings['state_desc'] as String;
      expect(text.length, lessThanOrEqualTo(20), reason: locale);
      expect(profile.contains("'state_desc': '$text'"), isTrue,
          reason: '$locale: Profile has its own copy of this text');
    }
  });

  testWidgets('the longest state never touches the text on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EnhancedProfileCard(
            title: 'State',
            subtitle: 'District Of Columbia',
            icon: SolarIcons.mapPointBold,
            cardType: 2,
            isHighlighted: true,
            onTap: () {},
            description: 'Rules and questions',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final text = tester.getRect(find.text('Rules and questions'));
    final value = tester.getRect(find.text('District Of Columbia'));
    expect(value.left - text.right, greaterThanOrEqualTo(12));
  });
}
