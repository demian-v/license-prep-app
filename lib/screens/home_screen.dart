import 'package:flutter/material.dart';
import '../services/crash_reporter.dart';
import 'package:provider/provider.dart';
import '../screens/test_screen.dart';
import '../screens/theory_screen.dart';
import '../screens/instructors_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/onboarding_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/super_enhanced_footer.dart';
import '../services/service_locator_extensions.dart';
import '../services/session_validation_service.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/in_app_purchase_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  // Static variable to persist tab selection across widget rebuilds
  static int _persistentCurrentIndex = 0;
  
  late int _currentIndex;
  bool _isInitializing = true;

  /// First-run onboarding over this screen: null until the flag is read,
  /// then whether to show it.
  bool? _showOnboarding;
  
  // Keep the widget alive to preserve state during parent rebuilds
  @override
  bool get wantKeepAlive => true;
  
  final List<Widget> _screens = [
    TestScreen(),
    TheoryScreen(),
    const InstructorsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Restore the persistent tab index to maintain tab selection across rebuilds
    _currentIndex = _persistentCurrentIndex;
    
    print('🏠 HomeScreen: Initializing with saved tab index: $_currentIndex');

    _checkOnboarding();
    
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
      
      // BACKUP: Ensure SubscriptionProvider is initialized for logged-in users
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      if (authProvider.user != null && subscriptionProvider.subscription == null && !subscriptionProvider.isLoading) {
        print('🔄 HomeScreen: SubscriptionProvider not initialized, initializing now...');
        try {
          await subscriptionProvider.initialize(authProvider.user!.id);
          print('✅ HomeScreen: SubscriptionProvider backup initialization successful');
        } catch (e) {
          print('⚠️ HomeScreen: SubscriptionProvider backup initialization failed: $e');
          // Non-critical - continue with app initialization
        }
      } else if (subscriptionProvider.subscription != null) {
        print('✅ HomeScreen: SubscriptionProvider already initialized');
      }

      // AUTO-RENEWAL FIX: After subscription is loaded, check if Apple may have
      // renewed it while the app was closed. If nextBillingDate has passed but
      // Firestore status is still 'active', trigger a receipt restore so the new
      // Apple receipt is processed and nextBillingDate updated.
      if (authProvider.user != null) {
        try {
          final iapService = Provider.of<InAppPurchaseService>(context, listen: false);

          // Register success callback so the subscription data refreshes in the
          // UI immediately after the renewed receipt is validated by the backend.
          iapService.onPurchaseSuccess = (productId) async {
            print('🔄 HomeScreen: Renewal/restore processed ($productId) — refreshing subscription');
            if (mounted && authProvider.user != null) {
              await subscriptionProvider.refreshSubscription(authProvider.user!.id);
            }
          };

          // Trigger restore only if needed (expired locally but active in Firestore).
          await subscriptionProvider.checkAndAutoRestoreIfNeeded(iapService);
        } catch (e) {
          print('⚠️ HomeScreen: Auto-restore check failed: $e');
          // Non-critical — subscription UI will still show correctly from Firestore data.
        }
      }

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

  // First-run onboarding (owner, 2026-09-29). It covers this screen while
  // _initializeContent and the Tests tab load underneath, and warms Theory,
  // which otherwise loads only when its tab is first opened.
  Future<void> _checkOnboarding() async {
    final show = await OnboardingGate.shouldShow();
    if (!mounted) return;
    setState(() => _showOnboarding = show);
    if (show) _prefetchTheoryForOnboarding();
  }

  void _prefetchTheoryForOnboarding() {
    final manager = ServiceLocatorExtensions.contentLoadingManager;
    // Signup already prefetched at state selection; don't fetch twice.
    if (manager.hasInitializedContent) return;
    // Same rule as the signup prefetch: skip only when we KNOW there is no
    // entitlement. A subscription not read back yet still prefetches.
    final subs = Provider.of<SubscriptionProvider>(context, listen: false);
    final knownUnentitled = subs.subscription != null && !subs.hasValidSubscription;
    manager.prefetchInBackground(entitled: !knownUnentitled, reason: 'onboarding');
  }

  Future<void> _onOnboardingDone() async {
    await OnboardingGate.markSeen();
    if (mounted) setState(() => _showOnboarding = false);
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
    
    // Breadcrumb: the bottom nav is the app's primary navigation and uses no
    // route at all, so CrashBreadcrumbObserver cannot see it.
    const tabs = ['tests', 'theory', 'instructors', 'profile'];
    crashReporter.log('nav: tab ${index < tabs.length ? tabs[index] : index}');

    print('🏠 HomeScreen: Tab changed to index $index, persisted for future rebuilds');
  }

  @override
  Widget build(BuildContext context) {
    // Call super.build to maintain AutomaticKeepAliveClientMixin functionality
    super.build(context);
    
    // Always a Stack with the home first: dropping the Stack when the
    // onboarding ends would re-parent the home and rebuild every tab from
    // scratch (a blank frame and a second preload).
    return Stack(children: [
      _buildHome(),
      if (_showOnboarding != false)
        Positioned.fill(
          // Until the flag is read, a plain field page, so the onboarding
          // doesn't flash in over a screen that was already showing.
          child: _showOnboarding == null
              ? const ColoredBox(color: AppColors.field)
              : OnboardingScreen(onDone: _onOnboardingDone),
        ),
    ]);
  }

  Widget _buildHome() {
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
