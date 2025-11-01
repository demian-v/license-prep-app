import 'lib/data/state_data.dart';

void main() {
  print('=== Testing State Visibility Implementation ===');
  
  // Test that configuration flag is set correctly
  print('showOnlyIllinoisAndNewYork flag: ${StateData.showOnlyIllinoisAndNewYork}');
  
  // Test visible states
  final visibleStates = StateData.getVisibleStates();
  print('\nVisible states (${visibleStates.length}):');
  for (final state in visibleStates) {
    print('  - ${state.name} (${state.id}) - isVisible: ${state.isVisible}');
  }
  
  // Test visible state names
  final visibleStateNames = StateData.getVisibleStateNames();
  print('\nVisible state names: $visibleStateNames');
  
  // Test that all states are still accessible
  final allStates = StateData.allStates;
  print('\nTotal states available: ${allStates.length}');
  print('States with isVisible=false: ${allStates.where((s) => !s.isVisible).length}');
  print('States with isVisible=true: ${allStates.where((s) => s.isVisible).length}');
  
  // Verify Illinois and New York are visible
  final illinois = StateData.getStateByName('ILLINOIS');
  final newYork = StateData.getStateByName('NEW YORK');
  print('\nIllinois visible: ${illinois?.isVisible}');
  print('New York visible: ${newYork?.isVisible}');
  
  // Test a hidden state
  final california = StateData.getStateByName('CALIFORNIA');
  print('California visible: ${california?.isVisible}');
  
  print('\n=== Test Complete ===');
}
