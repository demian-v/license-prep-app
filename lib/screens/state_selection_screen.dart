import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/state_provider.dart';
import '../models/state_info.dart';
import '../localization/app_localizations.dart';
import '../screens/home_screen.dart';
import '../providers/language_provider.dart';
import '../screens/language_selection_screen.dart';
import '../localization/app_localizations.dart';
import '../data/state_data.dart';
import '../services/service_locator_extensions.dart';

class StateSelectionScreen extends StatefulWidget {
  // Add constructor with key parameter
  const StateSelectionScreen({Key? key}) : super(key: key);

  @override
  _StateSelectionScreenState createState() => _StateSelectionScreenState();
}

class _StateSelectionScreenState extends State<StateSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedState;
  bool _showStateList = true; // Show state list by default
  List<String> _filteredStates = [];
  AppLocalizations? _localizations;

  // Get states from hardcoded data in StateData class
  final List<String> _allStates = StateData.getAllStateNames();

  @override
  void initState() {
    super.initState();
    print('🔧 [STATE SCREEN] initState - filteredStates initialized with ${_filteredStates.length} states');
    
    // Ensure app default language is English
    Future.microtask(() {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      if (languageProvider.language != 'en') {
        print('⚠️ [STATE SCREEN] Detected non-English language: ${languageProvider.language}, forcing to English');
        languageProvider.resetToEnglish();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get localizations after context is available
    _localizations = AppLocalizations.of(context);
    print('🔄 [STATE SCREEN] didChangeDependencies - localizations loaded: ${_localizations?.locale}');
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('🔄 [STATE SCREEN] Rebuilding with language: ${languageProvider.language}');
        
        // Debugging: Check if we have a proper BuildContext with Localizations
        bool hasLocalizations = Localizations.of<AppLocalizations>(context, AppLocalizations) != null;
        print('🔍 [STATE SCREEN] Has Localizations? $hasLocalizations');

        // Create a new instance of AppLocalizations to force it to load the correct language
        final localizations = AppLocalizations.of(context);
        print('🌐 [STATE SCREEN] Got AppLocalizations with locale: ${localizations.locale.languageCode}');
        
        // Debug print the translations for key fields to verify loading is correct
        print('📝 [STATE SCREEN] Translation check for state_selection: "${localizations.translate('state_selection')}"');
        print('📝 [STATE SCREEN] Translation check for select_state: "${localizations.translate('select_state')}"');
        print('📝 [STATE SCREEN] Translation check for search_state: "${localizations.translate('search_state')}"');
        
        final title = localizations.translate('state_selection');
        print('🏷️ [STATE SCREEN] Title translated to: "$title" (language: ${languageProvider.language})');
        
        return Scaffold(
          key: ValueKey('state_selection_screen_${languageProvider.language}_${DateTime.now().millisecondsSinceEpoch}'),
          appBar: AppBar(
            title: Text(
              title,
              key: ValueKey('state_selection_title_${languageProvider.language}_${DateTime.now().millisecondsSinceEpoch}'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Colors.black,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => LanguageSelectionScreen(),
                  ),
                );
              },
            ),
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
      },
    );
  }

  Widget _buildStateListView() {
    return Expanded(
      child: Column(
        children: [
          // Section header
          _buildSectionHeader(AppLocalizations.of(context).translate('select_state')),
          
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
                hintText: AppLocalizations.of(context).translate('search_state'),
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
                          AppLocalizations.of(context).translate('no_states_found'),
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
                                          state, // Keep English name for consistency
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          isSelected 
                                              ? AppLocalizations.of(context).translate('selected') 
                                              : AppLocalizations.of(context).translate('tap_to_select'),
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
          _buildSectionHeader(AppLocalizations.of(context).translate('selected_state')),
          
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
                          AppLocalizations.of(context).translate('selected_state'),
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
              AppLocalizations.of(context).translate('continue'),
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
    // Get the providers
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    // Update both providers - StateProvider for new system, AuthProvider for backward compatibility
    stateProvider.setSelectedStateByName(_selectedState!);
    authProvider.updateUserState(_selectedState!);
    
    // Navigate to home screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }
}
