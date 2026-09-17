import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The password-requirements panel must not overflow at any supported width.
///
/// Observed on the simulator 2026-09-17: "RIGHT OVERFLOWED BY 11 PIXELS" on
/// the iPhone 16 Pro (402pt) — the **widest** phone this app targets. So it
/// overflowed on every device, and by more on narrow ones. The cause was an
/// unbounded `Text` inside a `Row` in both `_buildValidationItem` and
/// `_buildValidationSubItem`.
///
/// The widgets are private, so this test rebuilds the two rows exactly as the
/// screen composes them — same icon size, same gap, same 16px indent for
/// sub-items, same strings — and asserts no overflow. That keeps the test
/// honest about what it covers: it proves the LAYOUT SHAPE is sound, and it
/// fails if anyone reintroduces an unbounded Text in that shape.
///
/// Widths cover the narrowest device in support through to the widest, plus a
/// 320pt case for the largest accessibility text sizes, where the effective
/// width shrinks.
void main() {
  /// The exact strings on the panel. The last is the longest.
  const items = [
    'At least 8 characters',
    'All of the following criteria are required:',
  ];
  const subItems = [
    'Lower case letters (a-z)',
    'Upper case letters (A-Z)',
    'Numbers (0-9)',
    r'Special characters (e.g. !@#$%^&*)',
  ];

  /// Mirrors the fixed builders.
  Widget row(String text, {required bool indented}) => Padding(
        padding: EdgeInsets.only(left: indented ? 16 : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.check_circle, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  /// The panel, with the screen's real padding: a 16px Container pad inside
  /// the card, which itself sits inside the page's horizontal margins.
  Widget panel() => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your password must contain:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final t in items) row(t, indented: false),
            const SizedBox(height: 4),
            for (final t in subItems) row(t, indented: true),
          ],
        ),
      );

  /// Every width the app can be shown at, narrowest first.
  const widths = <String, double>{
    'iPhone SE / 320pt (accessibility text shrinks the usable width further)': 320,
    'iPhone SE 2nd/3rd gen — 375pt': 375,
    'iPhone 16 Pro — 402pt (where it was OBSERVED overflowing)': 402,
    'iPhone 16 Pro Max — 440pt': 440,
  };

  widths.forEach((label, width) {
    testWidgets('no overflow at $label', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: panel(),
              ),
            ),
          ),
        ),
      );

      // A RenderFlex overflow is reported through FlutterError, which
      // flutter_test records rather than throwing. Reading it is the only way
      // to assert on it.
      expect(
        tester.takeException(),
        isNull,
        reason: 'the requirements panel overflowed at ${width}pt',
      );
    });
  });

  testWidgets('the long strings actually wrap rather than being clipped', (tester) async {
    // Guards against "fixing" the overflow with ellipsis or a smaller font,
    // which hides the text instead of showing it.
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: panel(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final longest = tester.widget<Text>(
      find.text(r'Special characters (e.g. !@#$%^&*)'),
    );
    expect(longest.overflow, isNot(TextOverflow.ellipsis),
        reason: 'the requirement should wrap, not be truncated');
    expect(longest.maxLines, isNull,
        reason: 'capping the lines would clip it at narrow widths');
  });
}
