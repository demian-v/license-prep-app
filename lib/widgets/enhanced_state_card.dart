import 'package:flutter/material.dart';
import '../data/state_data.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// A state in the signup picker, as a Bento row: the state's picture, its
/// name and a hint, a chevron. The chosen row is the dark `ink` row with no
/// tick — the fill says it, as the Профиль pickers (owner: "select black, not
/// blue… don't use check box"). The old pastel washes are gone.
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

class _EnhancedStateCardState extends State<EnhancedStateCard> {
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
    
    return SizedBox(
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

  /// The state's first two letters on a grey chip, if its picture is missing.
  Widget _buildFallbackLetterIcon() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.stateName.isNotEmpty ? widget.stateName.substring(0, 2).toUpperCase() : "",
        style: AppTypography.label.copyWith(
          color: AppColors.inkSecondary,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: PressScale(
        child: DecoratedBox(
          // The fill and shadow sit under the Material, so the shadow does
          // not paint over the white.
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.paper,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            boxShadow: selected ? null : AppColors.shadowCard,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x3,
                  ),
                  child: Row(
                    children: [
                      // State icon with fallback to letter abbreviation, on a
                      // tile so the thin outline still reads on the dark row.
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.paper : AppColors.field,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(width: 36, height: 36, child: _buildStateIcon()),
                      ),
                      const SizedBox(width: AppSpacing.x4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              // Convert state name to title case for display
                              widget.stateName.split(' ').map((word) => 
                                word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                              ).join(' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body.copyWith(
                                fontSize: 17,
                                height: 22 / 17,
                                color: selected ? AppColors.onSignal : AppColors.ink,
                                fontVariations: const [FontVariation('wght', 600)],
                              ),
                            ),
                            Text(
                              widget.subtitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: selected
                                    ? AppColors.onSignal.withValues(alpha: 0.7)
                                    : AppColors.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!selected) ...[
                        const SizedBox(width: AppSpacing.x2),
                        const Icon(
                          SolarIcons.altArrowRightLinear,
                          color: AppColors.inkTertiary,
                          size: 20,
                        ),
                      ],
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
