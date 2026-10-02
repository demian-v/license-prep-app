import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/widgets/lazy_indexed_stack.dart';

/// Instructor tabs (home_screen.dart) stay alive once opened, so unsaved
/// Календарь hours survive a tab switch (2026-10-02) — and tabs never opened
/// are not built at all.
class _Counter extends StatefulWidget {
  const _Counter(this.name, this.built);

  final String name;
  final List<String> built;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  void initState() {
    super.initState();
    widget.built.add(widget.name);
  }

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => setState(() => taps++), child: Text('${widget.name} $taps'));
}

void main() {
  testWidgets('keeps a tab state across switches and builds tabs lazily', (tester) async {
    final built = <String>[];
    var index = 0;
    late StateSetter setIndex;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, set) {
        setIndex = set;
        return LazyIndexedStack(index: index, children: [
          _Counter('calendar', built),
          _Counter('chat', built),
          _Counter('profile', built),
        ]);
      }),
    ));
    expect(built, ['calendar']);

    await tester.tap(find.text('calendar 0'));
    await tester.pump();
    expect(find.text('calendar 1'), findsOneWidget);

    setIndex(() => index = 2);
    await tester.pump();
    expect(built, ['calendar', 'profile']);

    setIndex(() => index = 0);
    await tester.pump();
    // The edit is still there and nothing was rebuilt from scratch.
    expect(find.text('calendar 1'), findsOneWidget);
    expect(built, ['calendar', 'profile']);
  });
}
