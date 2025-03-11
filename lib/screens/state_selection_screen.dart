import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home_screen.dart';

class StateSelectionScreen extends StatefulWidget {
  @override
  _StateSelectionScreenState createState() => _StateSelectionScreenState();
}

class _StateSelectionScreenState extends State<StateSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedState;
  bool _showStateList = true; // Show state list by default
  List<String> _filteredStates = [];

  // List of all US states
  final List<String> _allStates = [
    'ALABAMA',
    'ALASKA',
    'ARIZONA',
    'ARKANSAS',
    'CALIFORNIA',
    'COLORADO',
    'CONNECTICUT',
    'DELAWARE',
    'DISTRICT OF COLUMBIA',
    'FLORIDA',
    'GEORGIA',
    'HAWAII',
    'IDAHO',
    'ILLINOIS',
    'INDIANA',
    'IOWA',
    'KANSAS',
    'KENTUCKY',
    'LOUISIANA',
    'MAINE',
    'MARYLAND',
    'MASSACHUSETTS',
    'MICHIGAN',
    'MINNESOTA',
    'MISSISSIPPI',
    'MISSOURI',
    'MONTANA',
    'NEBRASKA',
    'NEVADA',
    'NEW HAMPSHIRE',
    'NEW JERSEY',
    'NEW MEXICO',
    'NEW YORK',
    'NORTH CAROLINA',
    'NORTH DAKOTA',
    'OHIO',
    'OKLAHOMA',
    'OREGON',
    'PENNSYLVANIA',
    'RHODE ISLAND',
    'SOUTH CAROLINA',
    'SOUTH DAKOTA',
    'TENNESSEE',
    'TEXAS',
    'UTAH',
    'VERMONT',
    'VIRGINIA',
    'WASHINGTON',
    'WEST VIRGINIA',
    'WISCONSIN',
    'WYOMING',
  ];

  @override
  void initState() {
    super.initState();
    _filteredStates = List.from(_allStates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStates(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStates = List.from(_allStates);
      } else {
        _filteredStates = _allStates
            .where((state) => state.contains(query.toUpperCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'State Selection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // No actions in app bar
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStateListView(),
            if (_selectedState != null) _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildStateSelectionView() {
    return Column(
      children: [
        // State selection button
        Expanded(
          flex: 3,
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // State button with shadow
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showStateList = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      elevation: 0, // Using custom shadow instead
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32.0),
                      ),
                    ),
                    child: Text(
                      'Select your state',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                if (_selectedState != null) ...[
                  SizedBox(height: 24),
                  // Selected state display
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Selected: $_selectedState',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 32),
                  // Continue button with shadow
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _continueToApp(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 40),
                        elevation: 0, // Using custom shadow instead
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32.0),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateListView() {
    return Expanded(
      child: Column(
        children: [
          // Section header
          _buildSectionHeader('Select your state'),
          
          // Enhanced search bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search state...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF2196F3),
                  size: 26,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            _searchController.clear();
                            _filterStates('');
                          },
                        ),
                      )
                    : null,
              ),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              onChanged: _filterStates,
            ),
          ),
          // Beautiful state list
          Expanded(
            child: _filteredStates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 70,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No states found',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredStates.length,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemBuilder: (context, index) {
                      final state = _filteredStates[index];
                      final isSelected = state == _selectedState;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _selectedState = state;
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Color(0xFF2196F3).withOpacity(0.1)
                                          : Colors.blue[50],
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: Icon(
                                      Icons.location_on_rounded,
                                      color: isSelected ? Color(0xFF2196F3) : Colors.blue,
                                      size: 28,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          state,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          isSelected ? "Selected" : "Tap to select",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSectionHeader('Selected State'),
          
          // Selected state card
          Card(
            margin: EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedState!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selected state',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          
          // Continue button
          ElevatedButton(
            onPressed: () => _continueToApp(context),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              minimumSize: Size(double.infinity, 56),
            ),
            child: Text(
              'Continue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continueToApp(BuildContext context) {
    // Save the selected state to the user profile
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.updateUserState(_selectedState!);
    
    // Navigate to the home screen but allow back navigation
    Future.delayed(Duration.zero, () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    });
  }
}
