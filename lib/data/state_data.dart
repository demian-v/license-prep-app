import '../models/state_info.dart';

/// Static repository for all US state data.
///
/// This class provides access to hardcoded state data, eliminating the
/// need for database calls to retrieve basic state information.
class StateData {
  /// List of all US states with their IDs and names
  static final List<StateInfo> allStates = [
    StateInfo(id: 'AL', name: 'ALABAMA'),
    StateInfo(id: 'AK', name: 'ALASKA'),
    StateInfo(id: 'AZ', name: 'ARIZONA'),
    StateInfo(id: 'AR', name: 'ARKANSAS'),
    StateInfo(id: 'CA', name: 'CALIFORNIA'),
    StateInfo(id: 'CO', name: 'COLORADO'),
    StateInfo(id: 'CT', name: 'CONNECTICUT'),
    StateInfo(id: 'DE', name: 'DELAWARE'),
    StateInfo(id: 'DC', name: 'DISTRICT OF COLUMBIA'),
    StateInfo(id: 'FL', name: 'FLORIDA'),
    StateInfo(id: 'GA', name: 'GEORGIA'),
    StateInfo(id: 'HI', name: 'HAWAII'),
    StateInfo(id: 'ID', name: 'IDAHO'),
    StateInfo(id: 'IL', name: 'ILLINOIS'),
    StateInfo(id: 'IN', name: 'INDIANA'),
    StateInfo(id: 'IA', name: 'IOWA'),
    StateInfo(id: 'KS', name: 'KANSAS'),
    StateInfo(id: 'KY', name: 'KENTUCKY'),
    StateInfo(id: 'LA', name: 'LOUISIANA'),
    StateInfo(id: 'ME', name: 'MAINE'),
    StateInfo(id: 'MD', name: 'MARYLAND'),
    StateInfo(id: 'MA', name: 'MASSACHUSETTS'),
    StateInfo(id: 'MI', name: 'MICHIGAN'),
    StateInfo(id: 'MN', name: 'MINNESOTA'),
    StateInfo(id: 'MS', name: 'MISSISSIPPI'),
    StateInfo(id: 'MO', name: 'MISSOURI'),
    StateInfo(id: 'MT', name: 'MONTANA'),
    StateInfo(id: 'NE', name: 'NEBRASKA'),
    StateInfo(id: 'NV', name: 'NEVADA'),
    StateInfo(id: 'NH', name: 'NEW HAMPSHIRE'),
    StateInfo(id: 'NJ', name: 'NEW JERSEY'),
    StateInfo(id: 'NM', name: 'NEW MEXICO'),
    StateInfo(id: 'NY', name: 'NEW YORK'),
    StateInfo(id: 'NC', name: 'NORTH CAROLINA'),
    StateInfo(id: 'ND', name: 'NORTH DAKOTA'),
    StateInfo(id: 'OH', name: 'OHIO'),
    StateInfo(id: 'OK', name: 'OKLAHOMA'),
    StateInfo(id: 'OR', name: 'OREGON'),
    StateInfo(id: 'PA', name: 'PENNSYLVANIA'),
    StateInfo(id: 'RI', name: 'RHODE ISLAND'),
    StateInfo(id: 'SC', name: 'SOUTH CAROLINA'),
    StateInfo(id: 'SD', name: 'SOUTH DAKOTA'),
    StateInfo(id: 'TN', name: 'TENNESSEE'),
    StateInfo(id: 'TX', name: 'TEXAS'),
    StateInfo(id: 'UT', name: 'UTAH'),
    StateInfo(id: 'VT', name: 'VERMONT'),
    StateInfo(id: 'VA', name: 'VIRGINIA'),
    StateInfo(id: 'WA', name: 'WASHINGTON'),
    StateInfo(id: 'WV', name: 'WEST VIRGINIA'),
    StateInfo(id: 'WI', name: 'WISCONSIN'),
    StateInfo(id: 'WY', name: 'WYOMING'),
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
}
