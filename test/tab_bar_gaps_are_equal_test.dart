import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/providers/language_provider.dart';
import 'package:license_prep_app/widgets/super_enhanced_footer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner, 2026-09-26: with four tabs in equal slots, short labels («Тесты»,
/// «Теория») sat in visibly more air than «Инструкторы». The gaps between
/// the tabs, and at both ends, must be equal.
void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/Rubik.ttf').readAsBytesSync();
    await (FontLoader('Rubik')
          ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer))))
        .load();
  });

  testWidgets('gaps between the Russian tab labels are equal', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'language': 'ru', 'app_initialized': true});
    final language = LanguageProvider();
    await tester.runAsync(language.waitForLoad);
    expect(language.language, 'ru');

    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SuperEnhancedFooter(
              // The bead sits on Профиль, so the other three labels rest.
              currentIndex: 3,
              onTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labels = ['Тесты', 'Теория', 'Инструкторы']
        .map((t) => tester.getRect(find.text(t)))
        .toList();
    final gapA = labels[1].left - labels[0].right;
    final gapB = labels[2].left - labels[1].right;

    expect(gapA, greaterThan(16));
    expect((gapA - gapB).abs(), lessThan(0.5),
        reason: 'Тесты–Теория $gapA vs Теория–Инструкторы $gapB');
  });
}
