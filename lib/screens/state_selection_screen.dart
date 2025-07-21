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
import '../services/analytics_service.dart';
import '../widgets/enhanced_state_card.dart';

class StateSelectionScreen extends StatefulWidget {
  // Add constructor with key parameter
  const StateSelectionScreen({Key? key}) : super(key: key);

  @override
  _StateSelectionScreenState createState() => _StateSelectionScreenState();
}

class _StateSelectionScreenState extends State<StateSelectionScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedState;
  bool _showStateList = true; // Show state list by default
  List<String> _filteredStates = [];
  AppLocalizations? _localizations;
  
  // Animation controller for continue button press effect
  late AnimationController _continueButtonController;
  late Animation<double> _continueButtonScaleAnimation;

  // Analytics tracking variables
  DateTime? _stateSelectionStartTime;
  String? _stateBeforeChange;
  String? _stateNameBeforeChange;

  // Get states from hardcoded data in StateData class
  final List<String> _allStates = StateData.getAllStateNames();

  @override
  void initState() {
    super.initState();
    // Initialize filtered states with all states
    _filteredStates = List.from(_allStates);
    print('🔧 [STATE SCREEN] initState - filteredStates initialized with ${_filteredStates.length} states');
    
    // Initialize animation controller for continue button
    _continueButtonController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _continueButtonScaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _continueButtonController, curve: Curves.easeInOut),
    );
    
    // No longer forcing language to English
    // This allows the selected language from the Language Selection screen to be used
    
    // Track analytics start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackStateSelectionStarted();
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
    _continueButtonController.dispose();
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

  void _trackStateSelectionStarted() {
    _stateSelectionStartTime = DateTime.now();
    
    // In signup context, user typically has no previous state
    _stateBeforeChange = null;
    _stateNameBeforeChange = 'Not selected';
    
    analyticsService.logStateSelectionStarted(
      selectionContext: 'signup',
      currentState: _stateBeforeChange,
      currentStateName: _stateNameBeforeChange,
    );
    debugPrint('📊 Analytics: state_selection_started logged (context: signup)');
  }

  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language JSON file
      switch (languageProvider.language) {
        case 'es':
          return {
            'state_selection': 'Selección de Estado',
            'select_state': 'Seleccione su estado',
            'search_state': 'Buscar estado...',
            'no_states_found': 'No se encontraron estados',
            'selected': 'Seleccionado',
            'tap_to_select': 'Toque para seleccionar',
            'selected_state': 'Estado seleccionado',
            'continue': 'Continuar',
          }[key] ?? key;
        case 'uk':
          return {
            'state_selection': 'Вибір Штату',
            'select_state': 'Виберіть свій штат',
            'search_state': 'Пошук штату...',
            'no_states_found': 'Штатів не знайдено',
            'selected': 'Вибрано',
            'tap_to_select': 'Натисніть, щоб вибрати',
            'selected_state': 'Вибраний штат',
            'continue': 'Продовжити',
          }[key] ?? key;
        case 'ru':
          return {
            'state_selection': 'Выбор Штата',
            'select_state': 'Выберите свой штат',
            'search_state': 'Найти штат...',
            'no_states_found': 'Штаты не найдены',
            'selected': 'Выбрано',
            'tap_to_select': 'Нажмите для выбора',
            'selected_state': 'Выбранный штат',
            'continue': 'Продолжить',
          }[key] ?? key;
        case 'pl':
          return {
            'state_selection': 'Wybór Stanu',
            'select_state': 'Wybierz swój stan',
            'search_state': 'Szukaj stanu...',
            'no_states_found': 'Nie znaleziono stanów',
            'selected': 'Wybrany',
            'tap_to_select': 'Dotknij, aby wybrać',
            'selected_state': 'Wybrany stan',
            'continue': 'Kontynuuj',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'state_selection': 'State Selection',
            'select_state': 'Select your state',
            'search_state': 'Search state...',
            'no_states_found': 'No states found',
            'selected': 'Selected',
            'tap_to_select': 'Tap to select',
            'selected_state': 'Selected state',
            'continue': 'Continue',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [STATE SCREEN] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('🔄 [STATE SCREEN] Rebuilding with language: ${languageProvider.language}');
        
        // Get translated text for our screen using our direct translation helper
        final title = _translate('state_selection', languageProvider);
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
            // No skip button - state selection is mandatory
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
          _buildSectionHeader(_translate('select_state', Provider.of<LanguageProvider>(context, listen: false))),
          
          // Enhanced search bar styled like Language Selection
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _translate('search_state', Provider.of<LanguageProvider>(context, listen: false)),
                hintStyle: TextStyle(color: Colors.grey[400]),
                contentPadding: EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Container(
                  width: 42,
                  height: 42,
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2196F3),
                    size: 26,
                  ),
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
          // Enhanced state list with EnhancedStateCard widget
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
                          _translate('no_states_found', Provider.of<LanguageProvider>(context, listen: false)),
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
                      final subtitleText = isSelected 
                          ? _translate('selected', Provider.of<LanguageProvider>(context, listen: false)) 
                          : _translate('tap_to_select', Provider.of<LanguageProvider>(context, listen: false));
                      
                      // Use the new enhanced state card
                      return EnhancedStateCard(
                        stateName: state,
                        isSelected: isSelected,
                        subtitleText: subtitleText,
                        onTap: () {
                          setState(() {
                            _selectedState = state;
                          });
                        },
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
          _buildSectionHeader(_translate('selected_state', Provider.of<LanguageProvider>(context, listen: false))),
          
          // Selected state card using EnhancedStateCard
          EnhancedStateCard(
            stateName: _selectedState!,
            isSelected: true,
            subtitleText: _translate('selected_state', Provider.of<LanguageProvider>(context, listen: false)),
            onTap: () {}, // No action needed here as it's already selected
          ),
          
          // Styled continue button that matches Log In button
          GestureDetector(
            onTapDown: (_) => _continueButtonController.forward(),
            onTapUp: (_) => _continueButtonController.reverse(),
            onTapCancel: () => _continueButtonController.reverse(),
            child: ScaleTransition(
              scale: _continueButtonScaleAnimation,
              child: Container(
                margin: EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.7)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _continueToApp(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      child: Text(
                        _translate('continue', Provider.of<LanguageProvider>(context, listen: false)),
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _continueToApp(BuildContext context) {
    // Get the state object from the selected state name
    final selectedStateInfo = StateData.getStateByName(_selectedState!);
    
    // Get the providers
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    // Get the state ID (two-letter code)
    final stateId = selectedStateInfo?.id;
    
    // Calculate time spent
    final timeSpent = _stateSelectionStartTime != null 
        ? DateTime.now().difference(_stateSelectionStartTime!).inSeconds 
        : null;
    
    if (stateId == null) {
      print('⚠️ [STATE SCREEN] Error: Could not find state ID for $_selectedState');
      
      // Track error case with analytics
      analyticsService.logStateChangeFailed(
        selectionContext: 'signup',
        targetState: _selectedState!,
        targetStateName: _selectedState!,
        errorType: 'state_lookup_error',
        errorMessage: 'Could not find state ID for $_selectedState',
      );
      debugPrint('📊 Analytics: state_change_failed logged (signup: $_selectedState)');
      
      // Fallback to using the name if we can't find the ID for some reason
      stateProvider.setSelectedStateByName(_selectedState!);
      authProvider.updateUserState(_selectedState!);
    } else {
      print('🌎 [STATE SCREEN] User selected state: $_selectedState (ID: $stateId)');
      
      // Track successful state change
      analyticsService.logStateChanged(
        selectionContext: 'signup',
        previousState: _stateBeforeChange,
        previousStateName: _stateNameBeforeChange,
        newState: stateId,
        newStateName: _selectedState!,
        timeSpentSeconds: timeSpent,
      );
      debugPrint('📊 Analytics: state_changed logged (signup: ${_stateBeforeChange ?? "none"} → $stateId)');
      
      // Update both providers with the correct state ID
      stateProvider.setSelectedStateByName(_selectedState!); // This already converts to ID internally
      authProvider.updateUserState(stateId); // Pass the two-letter code to the auth provider
    }
    
    // Navigate to home screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }
}
