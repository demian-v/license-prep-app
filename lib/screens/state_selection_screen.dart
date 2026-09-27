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
import '../providers/subscription_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/enhanced_state_card.dart';
import '../widgets/bento_auth_parts.dart';
import '../widgets/bento_result_parts.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

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

  // Analytics tracking variables
  DateTime? _stateSelectionStartTime;
  String? _stateBeforeChange;
  String? _stateNameBeforeChange;

  // Get only visible states from hardcoded data in StateData class
  final List<String> _allStates = StateData.getVisibleStateNames();

  @override
  void initState() {
    super.initState();
    // Initialize filtered states with all states
    _filteredStates = List.from(_allStates);
    print('🔧 [STATE SCREEN] initState - filteredStates initialized with ${_filteredStates.length} states');
    
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
            'more_states_coming': 'Próximamente nuevos estados',
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
            'more_states_coming': 'Незабаром з\'являться нові штати',
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
            'more_states_coming': 'Скоро появятся новые штаты',
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
            'more_states_coming': 'Wkrótce nowe stany',
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
            'more_states_coming': 'More states coming soon',
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
          backgroundColor: AppColors.field,
          appBar: bentoHeadingAppBar(
            title: title,
            onBack: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LanguageSelectionScreen(),
                ),
              );
            },
            // No skip button - state selection is mandatory
          ),
          // The bottom bar runs under the home indicator; its own padding
          // keeps the button clear of it.
          body: SafeArea(
            bottom: false,
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
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(BentoTokens.card),
          borderSide: BorderSide(color: color, width: width),
        );
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          _buildSectionHeader(_translate('select_state', languageProvider)),
          
          // Search as a white panel on the field page; a blue ring while typing.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4, 0, AppSpacing.x4, AppSpacing.x3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BentoTokens.card),
                boxShadow: AppColors.shadowCard,
              ),
              child: TextField(
                controller: _searchController,
                cursorColor: AppColors.signal,
                decoration: InputDecoration(
                  hintText: _translate('search_state', languageProvider),
                  hintStyle: AppTypography.body.copyWith(color: AppColors.inkTertiary),
                  contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
                  border: ring(Colors.transparent, 0),
                  enabledBorder: ring(Colors.transparent, 0),
                  focusedBorder: ring(AppColors.signal, 1.5),
                  filled: true,
                  fillColor: AppColors.paper,
                  prefixIcon: const Icon(
                    SolarIcons.magniferLinear,
                    color: AppColors.inkSecondary,
                    size: 22,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            SolarIcons.closeLinear,
                            color: AppColors.inkSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            _filterStates('');
                          },
                        )
                      : null,
                ),
                style: AppTypography.body.copyWith(
                  fontSize: 16,
                  color: AppColors.ink,
                ),
                onChanged: _filterStates,
              ),
            ),
          ),
          // The states as Bento rows (EnhancedStateCard)
          Expanded(
            child: _filteredStates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: AppColors.paper,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            SolarIcons.magniferBugLinear,
                            size: 34,
                            color: AppColors.inkTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x4),
                        Text(
                          _translate('no_states_found', languageProvider),
                          style: AppTypography.body.copyWith(
                            fontSize: 16,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    // The last row carries the "more states" note, so it
                    // scrolls with the list instead of pinning a line.
                    itemCount: _filteredStates.length + 1,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x4, AppSpacing.x1, AppSpacing.x4,
                      AppSpacing.x4 + (_selectedState == null ? MediaQuery.paddingOf(context).bottom : 0)),
                    itemBuilder: (context, index) {
                      if (index == _filteredStates.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                          child: Text(
                            _translate('more_states_coming', languageProvider),
                            style: AppTypography.label.copyWith(
                              color: AppColors.inkTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final state = _filteredStates[index];
                      final isSelected = state == _selectedState;
                      final subtitleText = isSelected 
                          ? _translate('selected', languageProvider) 
                          : _translate('tap_to_select', languageProvider);
                      
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4 + AppSpacing.x1, AppSpacing.x1, AppSpacing.x4, AppSpacing.x3),
      child: Text(
        title,
        style: AppTypography.body.copyWith(
          fontSize: 15,
          color: AppColors.inkSecondary,
        ),
      ),
    );
  }

  /// The pick and the way on, as a white bar along the bottom: which state is
  /// chosen on the left, the dark Continue pill on the right.
  Widget _buildContinueButton() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final stateName = _selectedState!.split(' ').map((word) =>
      word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
    ).join(' ');
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4, AppSpacing.x4,
        AppSpacing.x4 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
        boxShadow: AppColors.shadowRaised,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _translate('selected_state', languageProvider),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(color: AppColors.inkSecondary),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stateName,
                    maxLines: 1,
                    style: AppTypography.title.copyWith(
                      fontSize: 20,
                      height: 26 / 20,
                      color: AppColors.ink,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          SizedBox(
            width: 168,
            child: BentoAuthPrimaryButton(
              label: _translate('continue', languageProvider),
              onPressed: () => _continueToApp(context),
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
    
    // Warm the content cache for the state and language just chosen, in the
    // background. This is the last point in signup where both are known and
    // nothing is waiting on content, so the fetch costs the user no waiting.
    //
    // Not awaited: navigation must not wait on it. It is also what switches on
    // the ContentLoadingManager's language and state listeners, so a later
    // change in settings reloads by itself.
    // Skip only when we positively KNOW there is no entitlement — every content
    // callable requires it, so a prefetch without one is two guaranteed
    // refusals. A null subscription here means "not read back yet", which at
    // the end of signup is the common case for a brand-new trial, so it
    // prefetches rather than suppressing exactly what this exists for.
    final subs = Provider.of<SubscriptionProvider>(context, listen: false);
    final knownUnentitled =
        subs.subscription != null && !subs.hasValidSubscription;

    ServiceLocatorExtensions.contentLoadingManager.prefetchInBackground(
      entitled: !knownUnentitled,
      reason: 'state selected',
    );

    // Navigate to home screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }
}
