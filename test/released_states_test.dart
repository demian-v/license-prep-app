import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/data/state_data.dart';

/// The states a user can pick at signup and in settings are the release list
/// (owner, 2026-09-29), and nothing else.
void main() {
  const release = {
    'CA', 'TX', 'FL', 'NJ', 'PA', 'WA', 'MI', 'AZ', 'OH', 'NC',
    'MA', 'MD', 'IL', 'NY', 'GA', 'VA', 'CO', 'NV', 'OR', 'MN',
  };

  test('exactly the 20 release states are selectable', () {
    expect(StateData.getVisibleStateIds().toSet(), release);
  });

  test('every released id is a real state entry', () {
    for (final id in StateData.releasedStateIds) {
      expect(StateData.getStateById(id), isNotNull, reason: '$id is not in allStates');
    }
  });

  test('the pickers show names, still alphabetical', () {
    final names = StateData.getVisibleStateNames();
    expect(names, hasLength(20));
    expect(names, [...names]..sort());
    expect(names, containsAll(['ILLINOIS', 'NEW YORK', 'NEW JERSEY', 'NORTH CAROLINA']));
  });
}
