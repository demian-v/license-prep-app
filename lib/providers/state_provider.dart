import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/state_info.dart';
import '../data/state_data.dart';

/// Provider for managing state selection.
///
/// This provider handles selecting, storing, and retrieving the user's
/// selected state without requiring database access.
class StateProvider extends ChangeNotifier {
  /// Currently selected state
  StateInfo? _selectedState;
  
  /// Flag to track initialization status
  bool _hasInitialized = false;

  /// Get the currently selected state object
  StateInfo? get selectedState => _selectedState;
  
  /// Get the ID of the currently selected state
  String? get selectedStateId => _selectedState?.id;
  
  /// Get the name of the currently selected state
  String? get selectedStateName => _selectedState?.name;
  
  /// Check if a state has been selected
  bool get hasSelectedState => _selectedState != null;
  
  /// Check if provider has been initialized
  bool get isInitialized => _hasInitialized;
  
  /// Initialize provider by loading saved state from preferences
  Future<void> initialize() async {
    if (_hasInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final stateId = prefs.getString('selected_state_id');
      
      if (stateId != null) {
        _selectedState = StateData.getStateById(stateId);
      }
    } catch (e) {
      print('Error initializing StateProvider: $e');
    }
    
    _hasInitialized = true;
    notifyListeners();
    
    return;
  }
  
  /// Set the selected state using state ID
  Future<void> setSelectedState(String stateId) async {
    try {
      final state = StateData.getStateById(stateId);
      if (state != null) {
        _selectedState = state;
        
        // Save to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_state_id', stateId);
        
        notifyListeners();
      }
    } catch (e) {
      print('Error setting selected state: $e');
    }
  }
  
  /// Set the selected state using state name
  Future<void> setSelectedStateByName(String stateName) async {
    try {
      final state = StateData.getStateByName(stateName);
      if (state != null) {
        await setSelectedState(state.id);
      }
    } catch (e) {
      print('Error setting selected state by name: $e');
    }
  }
  
  /// Clear the selected state
  Future<void> clearSelectedState() async {
    _selectedState = null;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_state_id');
    } catch (e) {
      print('Error clearing selected state: $e');
    }
    
    notifyListeners();
  }
}
