import 'package:flutter/foundation.dart';

/// Model class for US state information.
///
/// This model stores essential information about US states that can be
/// used throughout the app without requiring database access.
class StateInfo {
  /// The state's unique identifier (typically a two-letter abbreviation)
  final String id;
  
  /// The state's full name
  final String name;
  
  /// Optional shorter abbreviation for the state (often same as id)
  final String? abbreviation;
  
  /// Optional localized/display version of the state name
  final String? displayName;
  
  /// Creates a new StateInfo instance
  const StateInfo({
    required this.id,
    required this.name,
    this.abbreviation,
    this.displayName,
  });
  
  /// Helper to get display name or fallback to name if not available
  String getDisplayName() => displayName ?? name;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StateInfo &&
           other.id == id &&
           other.name == name;
  }
  
  @override
  int get hashCode => id.hashCode ^ name.hashCode;
  
  @override
  String toString() => 'StateInfo(id: $id, name: $name)';
}
