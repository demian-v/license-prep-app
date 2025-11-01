import '../models/state_info.dart';

/// Static repository for all US state data.
///
/// This class provides access to hardcoded state data, eliminating the
/// need for database calls to retrieve basic state information.
class StateData {
  /// Configuration flag to show only Illinois and New York
  /// Set to false to show all states
  static const bool showOnlyIllinoisAndNewYork = true;
  
  /// List of all US states with their IDs and names
  static final List<StateInfo> allStates = [
    StateInfo(id: 'AL', name: 'ALABAMA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'AK', name: 'ALASKA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'AZ', name: 'ARIZONA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'AR', name: 'ARKANSAS', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'CA', name: 'CALIFORNIA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'CO', name: 'COLORADO', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'CT', name: 'CONNECTICUT', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'DE', name: 'DELAWARE', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'DC', name: 'DISTRICT OF COLUMBIA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'FL', name: 'FLORIDA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'GA', name: 'GEORGIA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'HI', name: 'HAWAII', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'ID', name: 'IDAHO', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'IL', name: 'ILLINOIS', isVisible: true), // Always visible
    StateInfo(id: 'IN', name: 'INDIANA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'IA', name: 'IOWA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'KS', name: 'KANSAS', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'KY', name: 'KENTUCKY', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'LA', name: 'LOUISIANA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'ME', name: 'MAINE', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MD', name: 'MARYLAND', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MA', name: 'MASSACHUSETTS', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MI', name: 'MICHIGAN', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MN', name: 'MINNESOTA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MS', name: 'MISSISSIPPI', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MO', name: 'MISSOURI', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'MT', name: 'MONTANA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'NE', name: 'NEBRASKA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'NV', name: 'NEVADA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'NH', name: 'NEW HAMPSHIRE', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'NJ', name: 'NEW JERSEY', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'NM', name: 'NEW MEXICO', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'NY', name: 'NEW YORK', isVisible: true), // Always visible
    StateInfo(id: 'NC', name: 'NORTH CAROLINA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'ND', name: 'NORTH DAKOTA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'OH', name: 'OHIO', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'OK', name: 'OKLAHOMA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'OR', name: 'OREGON', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'PA', name: 'PENNSYLVANIA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'RI', name: 'RHODE ISLAND', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'SC', name: 'SOUTH CAROLINA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'SD', name: 'SOUTH DAKOTA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'TN', name: 'TENNESSEE', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'TX', name: 'TEXAS', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'UT', name: 'UTAH', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'VT', name: 'VERMONT', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'VA', name: 'VIRGINIA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'WA', name: 'WASHINGTON', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'WV', name: 'WEST VIRGINIA', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'WI', name: 'WISCONSIN', isVisible: !showOnlyIllinoisAndNewYork),
    StateInfo(id: 'WY', name: 'WYOMING', isVisible: !showOnlyIllinoisAndNewYork),
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
