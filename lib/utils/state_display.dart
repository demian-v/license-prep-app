import '../data/state_data.dart';

/// «ILLINOIS» → «Illinois»: StateData stores names upper-case.
String stateDisplayName(String id) {
  final name = StateData.getStateById(id)?.name ?? id;
  return name
      .toLowerCase()
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
