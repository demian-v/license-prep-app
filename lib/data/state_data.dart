import '../models/state_info.dart';

/// Static repository for all US state data.
///
/// This class provides access to hardcoded state data, eliminating the
/// need for database calls to retrieve basic state information.
class StateData {
  /// The states offered at signup and in settings: the release list
  /// (owner, 2026-09-29). Every other state stays hidden until it is added
  /// here, which still takes an app release (risk #33).
  static const Set<String> releasedStateIds = {
    'CA', 'TX', 'FL', 'NJ', 'PA', 'WA', 'MI', 'AZ', 'OH', 'NC',
    'MA', 'MD', 'IL', 'NY', 'GA', 'VA', 'CO', 'NV', 'OR', 'MN',
  };
  
  /// List of all US states with their IDs and names
  static final List<StateInfo> allStates = [
    StateInfo(id: 'AL', name: 'ALABAMA', isVisible: releasedStateIds.contains('AL')),
    StateInfo(id: 'AK', name: 'ALASKA', isVisible: releasedStateIds.contains('AK')),
    StateInfo(id: 'AZ', name: 'ARIZONA', isVisible: releasedStateIds.contains('AZ')),
    StateInfo(id: 'AR', name: 'ARKANSAS', isVisible: releasedStateIds.contains('AR')),
    StateInfo(id: 'CA', name: 'CALIFORNIA', isVisible: releasedStateIds.contains('CA')),
    StateInfo(id: 'CO', name: 'COLORADO', isVisible: releasedStateIds.contains('CO')),
    StateInfo(id: 'CT', name: 'CONNECTICUT', isVisible: releasedStateIds.contains('CT')),
    StateInfo(id: 'DE', name: 'DELAWARE', isVisible: releasedStateIds.contains('DE')),
    StateInfo(id: 'DC', name: 'DISTRICT OF COLUMBIA', isVisible: releasedStateIds.contains('DC')),
    StateInfo(id: 'FL', name: 'FLORIDA', isVisible: releasedStateIds.contains('FL')),
    StateInfo(id: 'GA', name: 'GEORGIA', isVisible: releasedStateIds.contains('GA')),
    StateInfo(id: 'HI', name: 'HAWAII', isVisible: releasedStateIds.contains('HI')),
    StateInfo(id: 'ID', name: 'IDAHO', isVisible: releasedStateIds.contains('ID')),
    StateInfo(id: 'IL', name: 'ILLINOIS', isVisible: releasedStateIds.contains('IL')),
    StateInfo(id: 'IN', name: 'INDIANA', isVisible: releasedStateIds.contains('IN')),
    StateInfo(id: 'IA', name: 'IOWA', isVisible: releasedStateIds.contains('IA')),
    StateInfo(id: 'KS', name: 'KANSAS', isVisible: releasedStateIds.contains('KS')),
    StateInfo(id: 'KY', name: 'KENTUCKY', isVisible: releasedStateIds.contains('KY')),
    StateInfo(id: 'LA', name: 'LOUISIANA', isVisible: releasedStateIds.contains('LA')),
    StateInfo(id: 'ME', name: 'MAINE', isVisible: releasedStateIds.contains('ME')),
    StateInfo(id: 'MD', name: 'MARYLAND', isVisible: releasedStateIds.contains('MD')),
    StateInfo(id: 'MA', name: 'MASSACHUSETTS', isVisible: releasedStateIds.contains('MA')),
    StateInfo(id: 'MI', name: 'MICHIGAN', isVisible: releasedStateIds.contains('MI')),
    StateInfo(id: 'MN', name: 'MINNESOTA', isVisible: releasedStateIds.contains('MN')),
    StateInfo(id: 'MS', name: 'MISSISSIPPI', isVisible: releasedStateIds.contains('MS')),
    StateInfo(id: 'MO', name: 'MISSOURI', isVisible: releasedStateIds.contains('MO')),
    StateInfo(id: 'MT', name: 'MONTANA', isVisible: releasedStateIds.contains('MT')),
    StateInfo(id: 'NE', name: 'NEBRASKA', isVisible: releasedStateIds.contains('NE')),
    StateInfo(id: 'NV', name: 'NEVADA', isVisible: releasedStateIds.contains('NV')),
    StateInfo(id: 'NH', name: 'NEW HAMPSHIRE', isVisible: releasedStateIds.contains('NH')),
    StateInfo(id: 'NJ', name: 'NEW JERSEY', isVisible: releasedStateIds.contains('NJ')),
    StateInfo(id: 'NM', name: 'NEW MEXICO', isVisible: releasedStateIds.contains('NM')),
    StateInfo(id: 'NY', name: 'NEW YORK', isVisible: releasedStateIds.contains('NY')),
    StateInfo(id: 'NC', name: 'NORTH CAROLINA', isVisible: releasedStateIds.contains('NC')),
    StateInfo(id: 'ND', name: 'NORTH DAKOTA', isVisible: releasedStateIds.contains('ND')),
    StateInfo(id: 'OH', name: 'OHIO', isVisible: releasedStateIds.contains('OH')),
    StateInfo(id: 'OK', name: 'OKLAHOMA', isVisible: releasedStateIds.contains('OK')),
    StateInfo(id: 'OR', name: 'OREGON', isVisible: releasedStateIds.contains('OR')),
    StateInfo(id: 'PA', name: 'PENNSYLVANIA', isVisible: releasedStateIds.contains('PA')),
    StateInfo(id: 'RI', name: 'RHODE ISLAND', isVisible: releasedStateIds.contains('RI')),
    StateInfo(id: 'SC', name: 'SOUTH CAROLINA', isVisible: releasedStateIds.contains('SC')),
    StateInfo(id: 'SD', name: 'SOUTH DAKOTA', isVisible: releasedStateIds.contains('SD')),
    StateInfo(id: 'TN', name: 'TENNESSEE', isVisible: releasedStateIds.contains('TN')),
    StateInfo(id: 'TX', name: 'TEXAS', isVisible: releasedStateIds.contains('TX')),
    StateInfo(id: 'UT', name: 'UTAH', isVisible: releasedStateIds.contains('UT')),
    StateInfo(id: 'VT', name: 'VERMONT', isVisible: releasedStateIds.contains('VT')),
    StateInfo(id: 'VA', name: 'VIRGINIA', isVisible: releasedStateIds.contains('VA')),
    StateInfo(id: 'WA', name: 'WASHINGTON', isVisible: releasedStateIds.contains('WA')),
    StateInfo(id: 'WV', name: 'WEST VIRGINIA', isVisible: releasedStateIds.contains('WV')),
    StateInfo(id: 'WI', name: 'WISCONSIN', isVisible: releasedStateIds.contains('WI')),
    StateInfo(id: 'WY', name: 'WYOMING', isVisible: releasedStateIds.contains('WY')),
  ];
  
  /// Helper method to find a state by its ID
  static StateInfo? getStateById(String id) {
    try {
      return allStates.firstWhere((state) => state.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Helper method to find a state by its name
  static StateInfo? getStateByName(String name) {
    try {
      return allStates.firstWhere(
        (state) => state.name.toUpperCase() == name.toUpperCase()
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Get all state names as a list for display purposes
  static List<String> getAllStateNames() {
    return allStates.map((state) => state.name).toList();
  }
  
  /// Get all state IDs as a list
  static List<String> getAllStateIds() {
    return allStates.map((state) => state.id).toList();
  }
  
  /// Get only visible states
  static List<StateInfo> getVisibleStates() {
    return allStates.where((state) => state.isVisible).toList();
  }
  
  /// Get visible state names as a list for display purposes
  static List<String> getVisibleStateNames() {
    return getVisibleStates().map((state) => state.name).toList();
  }
  
  /// Get visible state IDs as a list
  static List<String> getVisibleStateIds() {
    return getVisibleStates().map((state) => state.id).toList();
  }
}
