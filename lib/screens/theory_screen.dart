import 'package:flutter/material.dart';
import '../services/crash_reporter.dart';
import '../localization/app_localizations.dart';
import '../widgets/subscription_required_view.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../models/traffic_rule_topic.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../services/session_validation_service.dart';
import '../widgets/module_card.dart';
import 'theory_module_screen.dart';
import 'traffic_rule_content_screen.dart';
import '../widgets/trial_status_widget.dart';
import '../widgets/premium_block_dialog.dart';
import '../utils/subscription_checker.dart';
import '../providers/subscription_provider.dart';
import '../theme/solar_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

class TheoryScreen extends StatefulWidget {
  @override
  _TheoryScreenState createState() => _TheoryScreenState();
}

class _TheoryScreenState extends State<TheoryScreen> {
  // Analytics tracking variables
  DateTime? _screenLoadTime;
  DateTime? _loadingStartTime;
  bool _hasTrackedListViewed = false;
  bool _hasTrackedEmptyState = false;

  /// True until this screen's first content request has finished. Before it,
  /// an empty list only means "not asked yet", and showing "No theory modules
  /// found" for that split second read as a real empty state (2026-09-26).
  bool _initializing = true;
  
  @override
  void initState() {
    super.initState();
    _screenLoadTime = DateTime.now();
    
    // Fetch modules when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContent();
    });
  }
  
  void _initializeContent() async {
    try {
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // ROBUSTNESS FIX: Get state from multiple sources for maximum reliability
      // AuthProvider takes priority as it's the most up-to-date from ProfileScreen changes
      final stateFromAuth = authProvider.user?.state;
      final stateFromProvider = stateProvider.selectedStateId;
      final userState = stateFromAuth ?? stateFromProvider;
      
      print('TheoryScreen: State sources - Auth: $stateFromAuth, StateProvider: $stateFromProvider');
      print('TheoryScreen: Using state=$userState (priority: Auth > StateProvider)');
      print('TheoryScreen: Initializing with state=$userState, language=${languageProvider.language}');
      
      // Set current language and fetch content
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: userState,
      );
      
      // Wait a bit to ensure the UI is ready and preferences are set
      await Future.delayed(Duration(milliseconds: 200));
      
      // Fetch content - let cache logic handle whether to use cache or fetch fresh data
      print('TheoryScreen: Explicitly fetching content with state=$userState, language=${languageProvider.language}');
      await contentProvider.fetchContentAfterSelection(forceRefresh: false);
      
      // Check if content was loaded
      if (contentProvider.modules.isEmpty) {
        print('TheoryScreen: No modules found, trying one more time with explicit parameters');
        await contentProvider.fetchContentForLanguageAndState(
          languageProvider.language, 
          userState ?? 'ALL',
          forceRefresh: true
        );
      }
    } catch (e) {
      print('TheoryScreen: Error initializing content: $e');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  // Analytics tracking methods
  void _trackModuleListViewed(List<TheoryModule> modules) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    
    analyticsService.logTheoryModuleListViewed(
      moduleCount: modules.length,
      state: userState,
      language: languageProvider.language,
      licenseType: 'driver', // Default license type
    );
    
    debugPrint('📊 Analytics: theory_module_list_viewed logged (modules: ${modules.length}, state: $userState, language: ${languageProvider.language})');
  }

  void _trackModuleListEmpty(ContentProvider contentProvider, {String? overrideReason}) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    // Risk #3 follow-up — a paywall is not an empty content shelf. Reporting
    // it as `reason: state` put a content gap in the metrics where there was
    // really a subscription boundary, which is how this went unnoticed on
    // screen too.
    final reason = contentProvider.contentRequiresSubscription
        ? 'subscription_required'
        : (overrideReason ?? contentProvider.contentNotFoundReason ?? 'unknown');
    
    // Calculate loading time if this is a loading event
    int? loadingTimeMs;
    if (reason == 'loading' && _loadingStartTime != null) {
      loadingTimeMs = DateTime.now().difference(_loadingStartTime!).inMilliseconds;
    }
    
    analyticsService.logTheoryModuleListEmpty(
      emptyReason: reason,
      requestedState: contentProvider.requestedState,
      requestedLanguage: contentProvider.requestedLanguage,
      requestedLicenseType: 'driver', // Default license type
      loadingTimeMs: loadingTimeMs,
    );
    
    debugPrint('📊 Analytics: theory_module_list_empty logged (reason: $reason, state: ${contentProvider.requestedState}, language: ${contentProvider.requestedLanguage}${loadingTimeMs != null ? ', loading_time: ${loadingTimeMs}ms' : ''})');
  }

  void _trackModuleSelected(TheoryModule module) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final stateProvider = Provider.of<StateProvider>(context, listen: false);
    
    final userState = authProvider.user?.state ?? stateProvider.selectedStateId;
    final timeOnList = _screenLoadTime != null 
        ? DateTime.now().difference(_screenLoadTime!).inSeconds 
        : null;
    
    analyticsService.logTheoryModuleSelected(
      moduleId: module.id,
      moduleTitle: module.title,
      timeOnListSeconds: timeOnList,
      state: userState,
      language: languageProvider.language,
      licenseType: 'driver', // Default license type
    );
    
    debugPrint('📊 Analytics: theory_module_selected logged (module: ${module.title}, time_on_list: ${timeOnList}s)');
  }

  /// Shows premium block dialog when user tries to access premium features without valid subscription
  void _showPremiumBlockDialog(BuildContext context, String featureName) {
    debugPrint('🚫 TheoryScreen: Showing premium block dialog for feature: $featureName');
    
    PremiumBlockDialog.show(
      context,
      featureName: featureName,
      onUpgradePressed: () {
        debugPrint('🔄 TheoryScreen: User clicked Upgrade Now from premium block dialog');
        Navigator.of(context).pop(); // Close dialog
        Navigator.pushNamed(context, '/subscription'); // Navigate to subscription screen
      },
      onClosePressed: () {
        debugPrint('❌ TheoryScreen: User closed premium block dialog');
        Navigator.of(context).pop();
      },
    );
  }

  /// Opens a module. Moved unchanged from the card's inline `onSelect`, so
  /// the card can change without touching the session check, the
  /// subscription block, analytics or the single-topic shortcut.
  Future<void> _onModuleSelect(TheoryModule module) async {
    // Session validation - validate before module selection
    if (!SessionValidationService.validateBeforeActionSafely(context)) {
      print('🚨 TheoryScreen: Session invalid, blocking module selection');
      return; // User will be logged out by the validation service
    }
    
    // NEW: Subscription validation - check if user has valid subscription
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
    if (SubscriptionChecker.shouldBlockPremiumFeature(subscriptionProvider)) {
      print('🚫 TheoryScreen: Subscription invalid, blocking module selection: ${module.title}');
      print('   - Block reason: ${SubscriptionChecker.getBlockReason(subscriptionProvider)}');
      _showPremiumBlockDialog(context, module.title);
      return;
    }
    
    // Track module selection
    _trackModuleSelected(module);
    
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    
    // ENHANCED: Multiple strategies for single-topic detection
    bool isSingleTopicModule = false;
    String? singleTopicId;
    
    // Strategy 1: Check module topics list
    final topicsList = module.getTopicsList();
    if (topicsList.length == 1) {
      isSingleTopicModule = true;
      singleTopicId = topicsList[0];
      print('🎯 Single topic detected via topics list: $singleTopicId');
    }
    
    // Strategy 2: Extract from module ID pattern (traffic_rules_uk_IL_01 → topic "1")
    if (!isSingleTopicModule) {
      final moduleIdParts = module.id.split('_');
      if (moduleIdParts.length >= 4) {
        final moduleNumber = moduleIdParts.last;
        singleTopicId = moduleNumber.replaceAll(RegExp(r'^0+'), ''); // 01 → 1
        isSingleTopicModule = true;
        print('🎯 Single topic detected via ID pattern: ${module.id} → topic $singleTopicId');
      }
    }
    
    // DIRECT NAVIGATION for single-topic modules
    if (isSingleTopicModule && singleTopicId != null) {
      print('🚀 Attempting direct navigation to topic $singleTopicId');
      
      // Find the topic efficiently
      TrafficRuleTopic? topic;
      
      // First try in-memory lookup from cached topics
      final allTopics = contentProvider.topics;
      try {
        topic = allTopics.firstWhere(
          (t) => t.id == singleTopicId && 
                 (t.state == module.state || t.state == 'ALL') && 
                 t.language == module.language,
        );
        print('✅ Found topic in memory: ${topic.id} - ${topic.title}');
      } catch (e) {
        print('⏳ Topic not in memory, fetching from database...');
        // Fallback: fetch from database
        topic = await contentProvider.getTopicById(singleTopicId);
        if (topic != null) {
          print('✅ Successfully fetched topic: ${topic.id} - ${topic.title}');
        } else {
          print('❌ Failed to fetch topic: $singleTopicId');
        }
      }
      
      if (topic != null) {
        // 🚀 DIRECT NAVIGATION - Skip TheoryModuleScreen entirely!
        print('🎉 Navigating directly to content, skipping intermediate screen');
        crashReporter.log('nav: theory topic content');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrafficRuleContentScreen(topic: topic!, moduleId: module.id),
          ),
        );
        return; // IMPORTANT: Exit early to prevent TheoryModuleScreen navigation
      }
    }
    
    // FALLBACK: Navigate to TheoryModuleScreen for multi-topic modules or if direct navigation failed
    print('📋 Navigating to TheoryModuleScreen (multi-topic or fallback)');
    crashReporter.log('nav: theory module');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TheoryModuleScreen(module: module),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No title bar: the tab bar already says where you are, and the bar
      // took a full row above the content.
      body: SafeArea(
        bottom: false,
        child: Consumer<ContentProvider>(
              builder: (context, contentProvider, child) {
          // Still starting with nothing in memory: the spinner, not a false
          // "no modules" page.
          if (contentProvider.isLoading ||
              (_initializing && contentProvider.modules.isEmpty)) {
            return _withTrialCard(Center(
              child: CircularProgressIndicator(),
            ));
          }
          
          final modules = contentProvider.modules;
          
          // Enhanced empty state detection - check both empty modules AND tracking data
          final shouldShowEmptyState = modules.isEmpty || !contentProvider.hasRequestedContent;
          
          // Analytics tracking for successful module list view
          if (!shouldShowEmptyState && modules.isNotEmpty && !_hasTrackedListViewed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _trackModuleListViewed(modules);
            });
            _hasTrackedListViewed = true;
          }
          
          if (shouldShowEmptyState) {
            // Analytics tracking for empty state (only track once)
            if (!_hasTrackedEmptyState) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Determine if this is loading vs truly empty
                final isCurrentlyLoading = contentProvider.isLoading;
                final wasLoading = _loadingStartTime != null;
                
                // Set loading start time if this is first empty state during loading
                if (isCurrentlyLoading && _loadingStartTime == null) {
                  _loadingStartTime = DateTime.now();
                }
                
                // Determine the empty reason
                String emptyReason;
                if (isCurrentlyLoading || (!isCurrentlyLoading && wasLoading && modules.isEmpty)) {
                  emptyReason = 'loading';
                } else {
                  emptyReason = contentProvider.contentNotFoundReason ?? 'no_content';
                }
                
                _trackModuleListEmpty(contentProvider, overrideReason: emptyReason);
              });
              _hasTrackedEmptyState = true;
            }
            return _withTrialCard(Consumer<StateProvider>(
              builder: (context, stateProvider, _) {
                // Generate dynamic empty state message based on what was missing
                String emptyStateMessage;
                final reason = contentProvider.contentNotFoundReason;
                final requestedLanguage = contentProvider.requestedLanguage;
                final requestedState = contentProvider.requestedState;
                
                final l = AppLocalizations.of(context);

                // Each language in its own name, as in the pickers (the
                // message around it is now translated, 2026-09-26).
                final languageNames = {
                  'en': 'English',
                  'es': 'Español',
                  'uk': 'Українська',
                  'ru': 'Русский',
                  'pl': 'Polski',
                };
                
                final friendlyLanguage = languageNames[requestedLanguage] ?? requestedLanguage;
                final friendlyState = requestedState ?? l.translate('theory_empty_selected_state');
                
                // Risk #3 follow-up — a refusal is not an empty shelf. Before the
                // entitlement gate existed this branch could only mean "no
                // content", so every message here assumes a content or language
                // problem. Saying that to someone without a subscription sends
                // them hunting for a bug that does not exist, and logs a false
                // `reason: state` analytics event on the way.
                if (contentProvider.contentRequiresSubscription) {
                  return const SubscriptionRequiredView();
                }

                // Generate context-aware message
                switch (reason) {
                  case 'language':
                    emptyStateMessage = l.translate('theory_empty_language')
                        .replaceAll('{language}', friendlyLanguage);
                    break;
                  case 'state':
                    emptyStateMessage = l.translate('theory_empty_state')
                        .replaceAll('{state}', friendlyState);
                    break;
                  case 'language_and_state':
                    emptyStateMessage = l.translate('theory_empty_language_state')
                        .replaceAll('{language}', friendlyLanguage)
                        .replaceAll('{state}', friendlyState);
                    break;
                  default:
                    // Fallback to original message format
                    emptyStateMessage = stateProvider.selectedStateId != null
                        ? l.translate('theory_empty_state')
                            .replaceAll('{state}', stateProvider.selectedStateName ?? friendlyState)
                        : l.translate('theory_empty_no_state');
                }
                    
                // As on the topic list: a soft blue disc, a title, one quiet
                // line, then the action as a blue pill. From the top, under
                // the trial card, not centred (owner, 2026-09-26: centred it
                // sat too low).
                return Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x8, AppSpacing.x8, AppSpacing.x8, AppSpacing.x6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            color: AppColors.signal50,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            SolarIcons.book2Linear,
                            size: 40,
                            color: AppColors.signal,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x6),
                        Text(
                          l.translate('theory_empty_title'),
                          textAlign: TextAlign.center,
                          style: AppTypography.heading.copyWith(
                            fontSize: 20,
                            height: 26 / 20,
                            fontVariations: const [FontVariation('wght', 600)],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Text(
                          emptyStateMessage,
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(
                            fontSize: 15,
                            height: 22 / 15,
                            color: AppColors.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.x6),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
                            shape: const StadiumBorder(),
                          ),
                          icon: const Icon(SolarIcons.refreshLinear, size: 20),
                          label: Text(l.translate('refresh')),
                          onPressed: () {
                            contentProvider.fetchContentAfterSelection(forceRefresh: true);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ));
          }
          
          // The trial card scrolls with the modules, inside the same gutter,
          // as on Тесты.
          return CustomScrollView(
            slivers: [
              _trialCardSliver(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  _gutter,
                  0,
                  _gutter,
                  AppSpacing.x6,
                ),
                sliver: SliverList.builder(
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              
              // Rebuilt when progress changes, so a module read to the end
              // shows its tick on return.
              return Consumer<ProgressProvider>(
                builder: (context, progressProvider, _) {
              // Default to false if module progress can't be determined
              bool isCompleted = false;
              
              // Try to get completion status from ProgressProvider
              try {
                if (progressProvider != null && module != null && module.id != null) {
                  isCompleted = progressProvider.isModuleCompleted(module.id);
                }
              } catch (e) {
                print('Error checking module completion: $e');
                // Default to false if there's an error
                isCompleted = false;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                // One-shot entrance, capped so the whole list lands inside
                // AppMotion.base.
                child: StaggerIn(
                  index: index,
                  count: modules.length,
                  curve: BentoTokens.curve,
                  child: ModuleCard(
                    module: module,
                    isCompleted: isCompleted,
                    onSelect: () => _onModuleSelect(module),
                  ),
                ),
              );
                },
              );
            },
                ),
              ),
            ],
          );
              },
            ),
      )
    );
  }

  /// The tab's side gutter — the same as Тесты, so the trial card and the
  /// cards line up in the same place on both tabs.
  static const double _gutter = AppSpacing.x4 + AppSpacing.x1;

  /// The trial card at the top of the scroll, inset like the cards. For a
  /// paid subscriber it renders nothing, leaving only the top gap.
  Widget _trialCardSliver() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        _gutter,
        AppSpacing.x2,
        _gutter,
        AppSpacing.x4,
      ),
      sliver: SliverToBoxAdapter(child: TrialStatusWidget()),
    );
  }

  /// A loading or empty state under the trial card, centred in the space
  /// that is left.
  Widget _withTrialCard(Widget state) {
    return CustomScrollView(
      slivers: [
        _trialCardSliver(),
        SliverFillRemaining(hasScrollBody: false, child: state),
      ],
    );
  }
}
