import 'package:flutter/widgets.dart';

/// Shows one of [children], building each only when it is first shown and
/// keeping it alive afterwards, so its state (unsaved edits, scroll) survives
/// switching away. Hidden children don't tick.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _opened = {};

  @override
  Widget build(BuildContext context) {
    _opened.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: _opened.contains(i) ? widget.children[i] : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
