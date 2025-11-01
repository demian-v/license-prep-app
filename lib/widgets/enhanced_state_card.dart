import 'package:flutter/material.dart';
import '../data/state_data.dart';

class EnhancedStateCard extends StatefulWidget {
  final String stateName;
  final bool isSelected;
  final VoidCallback onTap;
  final String subtitleText;
  
  const EnhancedStateCard({
    Key? key,
    required this.stateName,
    required this.isSelected,
    required this.onTap,
    required this.subtitleText,
  }) : super(key: key);

  @override
  _EnhancedStateCardState createState() => _EnhancedStateCardState();
}

class _EnhancedStateCardState extends State<EnhancedStateCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  /// State icon assignment method following the topic icons pattern
  /// Maps state names to their corresponding asset files
  String? _getStateIconAsset(String stateName) {
    final name = stateName.toUpperCase();
    
    // Primary method: Direct state name mapping to numbered assets
    final stateIconMap = <String, String>{
      'ALABAMA': 'assets/images/states/1_alabama.png',
      'ALASKA': 'assets/images/states/2_alaska.png',
      'ARIZONA': 'assets/images/states/3_arizona.png',
      'ARKANSAS': 'assets/images/states/4_arkansas.png',
      'CALIFORNIA': 'assets/images/states/5_california.png',
      'COLORADO': 'assets/images/states/6_colorado.png',
      'CONNECTICUT': 'assets/images/states/7_connecticut.png',
      'DELAWARE': 'assets/images/states/8_delaware.png',
      'DISTRICT OF COLUMBIA': 'assets/images/states/9_florida.png', // Assuming DC uses Florida icon for now
      'FLORIDA': 'assets/images/states/9_florida.png',
      'GEORGIA': 'assets/images/states/10_georgia.png',
      'HAWAII': 'assets/images/states/11_hawaii.png',
      'IDAHO': 'assets/images/states/12_idaho.png',
      'ILLINOIS': 'assets/images/states/13_illinois.png',
      'INDIANA': 'assets/images/states/14_indiana.png',
      'IOWA': 'assets/images/states/15_iowa.png',
      'KANSAS': 'assets/images/states/16_kansas.png',
      'KENTUCKY': 'assets/images/states/17_kentucky.png',
      'LOUISIANA': 'assets/images/states/18_louisiana.png',
      'MAINE': 'assets/images/states/19_maine.png',
      'MARYLAND': 'assets/images/states/20_maryland.png',
      'MASSACHUSETTS': 'assets/images/states/21_massachusetts.png',
      'MICHIGAN': 'assets/images/states/22_michigan.png',
      'MINNESOTA': 'assets/images/states/23_minnesota.png',
      'MISSISSIPPI': 'assets/images/states/24_mississippi.png',
      'MISSOURI': 'assets/images/states/25_missouri.png',
      'MONTANA': 'assets/images/states/26_montana.png',
      'NEBRASKA': 'assets/images/states/27_nebraska.png',
      'NEVADA': 'assets/images/states/28_nevada.png',
      'NEW HAMPSHIRE': 'assets/images/states/29_new_hampshire.png',
      'NEW JERSEY': 'assets/images/states/30_new_jersey.png',
      'NEW MEXICO': 'assets/images/states/31_new_mexico.png', // Note: Screenshot shows file name inconsistency, adjusting
      'NEW YORK': 'assets/images/states/32_new_york.png',
      'NORTH CAROLINA': 'assets/images/states/33_north_carolina.png',
      'NORTH DAKOTA': 'assets/images/states/34_north_dakota.png',
      'OHIO': 'assets/images/states/35_ohio.png',
      'OKLAHOMA': 'assets/images/states/36_oklahoma.png',
      'OREGON': 'assets/images/states/37_oregon.png',
      'PENNSYLVANIA': 'assets/images/states/38_pennsylvania.png',
      'RHODE ISLAND': 'assets/images/states/39_rhode_island.png',
      'SOUTH CAROLINA': 'assets/images/states/40_south_carolina.png',
      'SOUTH DAKOTA': 'assets/images/states/41_south_dakota.png',
      'TENNESSEE': 'assets/images/states/42_tennessee.png',
      'TEXAS': 'assets/images/states/43_texas.png',
      'UTAH': 'assets/images/states/44_utah.png',
      'VERMONT': 'assets/images/states/45_vermont.png',
      'VIRGINIA': 'assets/images/states/46_virginia.png',
      'WASHINGTON': 'assets/images/states/47_washington.png',
      'WEST VIRGINIA': 'assets/images/states/48_west_virginia.png',
      'WISCONSIN': 'assets/images/states/49_wisconsin.png',
      'WYOMING': 'assets/images/states/50_wyoming.png',
    };
    
    return stateIconMap[name];
  }
  
  /// Fallback method: Get state icon using state ID if available
  String? _getStateIconAssetById(String stateName) {
    final stateInfo = StateData.getStateByName(stateName);
    if (stateInfo == null) return null;
    
    final stateId = stateInfo.id;
    
    // Fallback mapping using state IDs
    final stateIdIconMap = <String, String>{
      'AL': 'assets/images/states/1_alabama.png',
      'AK': 'assets/images/states/2_alaska.png',
      'AZ': 'assets/images/states/3_arizona.png',
      'AR': 'assets/images/states/4_arkansas.png',
      'CA': 'assets/images/states/5_california.png',
      'CO': 'assets/images/states/6_colorado.png',
      'CT': 'assets/images/states/7_connecticut.png',
      'DE': 'assets/images/states/8_delaware.png',
      'DC': 'assets/images/states/9_florida.png',
      'FL': 'assets/images/states/9_florida.png',
      'GA': 'assets/images/states/10_georgia.png',
      'HI': 'assets/images/states/11_hawaii.png',
      'ID': 'assets/images/states/12_idaho.png',
      'IL': 'assets/images/states/13_illinois.png',
      'IN': 'assets/images/states/14_indiana.png',
      'IA': 'assets/images/states/15_iowa.png',
      'KS': 'assets/images/states/16_kansas.png',
      'KY': 'assets/images/states/17_kentucky.png',
      'LA': 'assets/images/states/18_louisiana.png',
      'ME': 'assets/images/states/19_maine.png',
      'MD': 'assets/images/states/20_maryland.png',
      'MA': 'assets/images/states/21_massachusetts.png',
      'MI': 'assets/images/states/22_michigan.png',
      'MN': 'assets/images/states/23_minnesota.png',
      'MS': 'assets/images/states/24_mississippi.png',
      'MO': 'assets/images/states/25_missouri.png',
      'MT': 'assets/images/states/26_montana.png',
      'NE': 'assets/images/states/27_nebraska.png',
      'NV': 'assets/images/states/28_nevada.png',
      'NH': 'assets/images/states/29_new_hampshire.png',
      'NJ': 'assets/images/states/30_new_jersey.png',
      'NM': 'assets/images/states/31_new_mexico.png',
      'NY': 'assets/images/states/32_new_york.png',
      'NC': 'assets/images/states/33_north_carolina.png',
      'ND': 'assets/images/states/34_north_dakota.png',
      'OH': 'assets/images/states/35_ohio.png',
      'OK': 'assets/images/states/36_oklahoma.png',
      'OR': 'assets/images/states/37_oregon.png',
      'PA': 'assets/images/states/38_pennsylvania.png',
      'RI': 'assets/images/states/39_rhode_island.png',
      'SC': 'assets/images/states/40_south_carolina.png',
      'SD': 'assets/images/states/41_south_dakota.png',
      'TN': 'assets/images/states/42_tennessee.png',
      'TX': 'assets/images/states/43_texas.png',
      'UT': 'assets/images/states/44_utah.png',
      'VT': 'assets/images/states/45_vermont.png',
      'VA': 'assets/images/states/46_virginia.png',
      'WA': 'assets/images/states/47_washington.png',
      'WV': 'assets/images/states/48_west_virginia.png',
      'WI': 'assets/images/states/49_wisconsin.png',
      'WY': 'assets/images/states/50_wyoming.png',
    };
    
    return stateIdIconMap[stateId];
  }
  
  // Helper method to get softer pastel icon colors that are still visible
  Color _getBrighterIconColor(String stateName) {
    final int stateNameHash = stateName.length + (stateName.isNotEmpty ? stateName.codeUnitAt(0) : 0);
    final int colorIndex = stateNameHash % 7;
    
    // Softer pastel colors that are still visible
    switch (colorIndex) {
      case 0:
        // Soft purple
        return Color(0xFFB39DDB); // Purple 200
      case 1:
        // Soft green
        return Color(0xFFA5D6A7); // Green 200
      case 2:
        // Soft orange
        return Color(0xFFFFCC80); // Orange 200
      case 3:
        // Soft blue
        return Color(0xFF90CAF9); // Blue 200
      case 4:
        // Soft pink
        return Color(0xFFF48FB1); // Pink 200
      case 5:
        // Soft yellow-green
        return Color(0xFFE6EE9C); // Lime 200
      case 6:
        // Soft cyan
        return Color(0xFF80DEEA); // Cyan 200
      default:
        // Default color
        return Color(0xFF80CBC4); // Teal 200
    }
  }
  
  // Helper method to get gradient for state cards with consistent pastel colors
  LinearGradient _getGradientForState(bool isSelected, String stateName) {
    // Start with white as base color
    Color startColor = Colors.white;
    Color endColor;
    
    // Create a more uniform color distribution based on state names
    // Using modulo with a prime number to distribute colors more evenly
    final int stateNameHash = stateName.length + (stateName.isNotEmpty ? stateName.codeUnitAt(0) : 0);
    final int colorIndex = stateNameHash % 7;
    
    // Softer pastel colors with consistent opacity
    const double baseOpacity = 0.3; // Lower base opacity for all states
    
    switch (colorIndex) {
      case 0:
        // Lavender - very soft purple
        endColor = Color(0xFFE6E6FA).withOpacity(baseOpacity);
        break;
      case 1:
        // Mint - soft green
        endColor = Color(0xFFF5FFFA).withOpacity(baseOpacity);
        break;
      case 2:
        // Peach - softer orange (similar to Passenger Safety card)
        endColor = Color(0xFFFFF0E6).withOpacity(baseOpacity);
        break;
      case 3:
        // Sky - soft blue
        endColor = Color(0xFFF0F8FF).withOpacity(baseOpacity);
        break;
      case 4:
        // Rose - soft pink
        endColor = Color(0xFFFFF0F5).withOpacity(baseOpacity);
        break;
      case 5:
        // Honeydew - soft yellow-green
        endColor = Color(0xFFF0FFF0).withOpacity(baseOpacity);
        break;
      case 6:
        // Misty - soft cyan
        endColor = Color(0xFFE0FFFF).withOpacity(baseOpacity);
        break;
      default:
        // Almond - soft beige
        endColor = Color(0xFFFFEBCD).withOpacity(baseOpacity);
    }
    
    // If selected, make the color slightly more vivid but still soft
    if (isSelected) {
      // Increase opacity for selected state but maintain pastel tone
      endColor = endColor.withOpacity(baseOpacity + 0.1);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  /// Build state icon widget with comprehensive fallback system
  /// Following the topic icons pattern for error handling
  /// Updated to remove grey background and optimize for transparent PNGs
  Widget _buildStateIcon() {
    final String stateName = widget.stateName;
    
    // Try to get state icon asset path
    String? iconAsset = _getStateIconAsset(stateName);
    
    // If primary method fails, try fallback method
    if (iconAsset == null) {
      iconAsset = _getStateIconAssetById(stateName);
    }
    
    return Container(
      width: 42,
      height: 42,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: iconAsset != null
            ? Image.asset(
                iconAsset,
                width: 42,
                height: 42,
                fit: BoxFit.contain, // Changed from cover to contain for better transparent PNG handling
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to letter abbreviation if asset fails to load
                  print('🖼️ [STATE ICON] Error loading asset: $iconAsset for state: $stateName');
                  return _buildFallbackLetterIcon();
                },
              )
            : _buildFallbackLetterIcon(),
      ),
    );
  }

  /// Build fallback letter icon (original implementation)
  /// Used when state icon assets are not available or fail to load
  Widget _buildFallbackLetterIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _getBrighterIconColor(widget.stateName),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          widget.stateName.isNotEmpty ? widget.stateName.substring(0, 2).toUpperCase() : "",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Card(
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.3),
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: _getGradientForState(widget.isSelected, widget.stateName),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                splashColor: Colors.white.withOpacity(0.3),
                highlightColor: Colors.white.withOpacity(0.2),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // State icon with fallback to letter abbreviation
                      _buildStateIcon(),
                      SizedBox(width: 16),
                      // State name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Convert state name to title case for display
                              widget.stateName.split(' ').map((word) => 
                                word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                              ).join(' '),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.subtitleText,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Checkmark for selected state
                      if (widget.isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      // Arrow icon if not selected
                      if (!widget.isSelected)
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
