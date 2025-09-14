import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/test_screen.dart';
import '../screens/theory_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/super_enhanced_footer.dart';
import '../services/service_locator_extensions.dart';
import '../services/session_validation_service.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import '../providers/state_provider.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  // Static variable to persist tab selection across widget rebuilds
  static int _persistentCurrentIndex = 0;
  
  late int _currentIndex;
  bool _isInitializing = true;
  
  // Keep the widget alive to preserve state during parent rebuilds
  @override
  bool get wantKeepAlive => true;
  
  final List<Widget> _screens = [
    TestScreen(),
    TheoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Restore the persistent tab index to maintain tab selection across rebuilds
    _currentIndex = _persistentCurrentIndex;
    
    print('🏠 HomeScreen: Initializing with saved tab index: $_currentIndex');
    
    // Initialize content after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContent();
    });
  }
  
  // Sync content language AND state with providers
  Future<void> _syncContentLanguageAndState() async {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    // Wait for StateProvider to be fully initialized
    await stateProvider.waitForInitialization();
    
    final selectedStateId = stateProvider.selectedStateId;
    
    // Sync BOTH language AND state preferences
    contentProvider.setPreferences(
      language: languageProvider.language,
      state: selectedStateId,
    );
    
    print('HomeScreen: Synced content - language: ${languageProvider.language}, state: ${selectedStateId ?? "null"}');
    print('HomeScreen: StateProvider isInitialized: ${stateProvider.isInitialized}');
  }
  
  // Initialize HomeScreen preferences (language/state sync only)
  Future<void> _initializeContent() async {
    setState(() {
      _isInitializing = true;
    });
    
    try {
      // Sync both content language AND state preferences to providers
      // This ensures providers have the correct values for when individual screens need them
      await _syncContentLanguageAndState();
      
      print('🏠 HomeScreen: Preferences synced successfully - ready to show navigation');
      
      // NOTE: We don't load theory/practice content here anymore!
      // Each screen (TheoryScreen, TestScreen) will load its own content when accessed
      // This makes HomeScreen load instantly while keeping lazy loading for content
      
    } catch (e) {
      print('Error syncing HomeScreen preferences: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _onTabTapped(int index) {
    // Validate session before allowing navigation
    if (!SessionValidationService.validateBeforeActionSafely(context)) {
      print('🚨 HomeScreen: Session invalid, blocking tab navigation');
      return; // User will be logged out by the validation service
    }
    
    setState(() {
      _currentIndex = index;
      // Persist the tab selection to survive widget rebuilds (like during language changes)
      _persistentCurrentIndex = index;
    });
    
    print('🏠 HomeScreen: Tab changed to index $index, persisted for future rebuilds');
  }

  @override
  Widget build(BuildContext context) {
    // Call super.build to maintain AutomaticKeepAliveClientMixin functionality
    super.build(context);
    
    // Show loading indicator while initializing content
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading content...'),
            ],
          ),
        ),
      );
    }
    
    // Show the regular home screen once content is loaded
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: SuperEnhancedFooter(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
