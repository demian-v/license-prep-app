import 'package:flutter/material.dart';
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
    final reason = overrideReason ?? contentProvider.contentNotFoundReason ?? 'unknown';
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            // Get the current language from the LanguageProvider
            final language = Provider.of<LanguageProvider>(context, listen: false).language;
            
            // Translation map for "Theory" title in different languages
            final Map<String, String> theoryTitleTranslations = {
              'en': 'Theory',
              'uk': 'Теорія',
              'es': 'Teoría',
              'ru': 'Теория',
              'pl': 'Teoria',
            };
            
            // Get the correct translation based on the current language
            final titleText = theoryTitleTranslations[language] ?? 'Theory';
            
            return Text(
              titleText,
              style: TextStyle(fontWeight: FontWeight.bold),
            );
          }
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Consumer<ContentProvider>(
        builder: (context, contentProvider, child) {
          if (contentProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(),
            );
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
            return Consumer<StateProvider>(
              builder: (context, stateProvider, _) {
                // Generate dynamic empty state message based on what was missing
                String emptyStateMessage;
                final reason = contentProvider.contentNotFoundReason;
                final requestedLanguage = contentProvider.requestedLanguage;
                final requestedState = contentProvider.requestedState;
                
                // Create user-friendly language names
                final languageNames = {
                  'en': 'English',
                  'es': 'Spanish', 
                  'uk': 'Ukrainian',
                  'ru': 'Russian',
                  'pl': 'Polish',
                };
                
                final friendlyLanguage = languageNames[requestedLanguage] ?? requestedLanguage;
                final friendlyState = requestedState ?? 'selected state';
                
                // Generate context-aware message
                switch (reason) {
                  case 'language':
                    emptyStateMessage = 'We couldn\'t find any theory modules for language \'$friendlyLanguage\' with your current settings.';
                    break;
                  case 'state':
                    emptyStateMessage = 'We couldn\'t find any theory modules for state \'$friendlyState\' with your current language settings.';
                    break;
                  case 'language_and_state':
                    emptyStateMessage = 'We couldn\'t find any theory modules for language \'$friendlyLanguage\' in state \'$friendlyState\'.';
                    break;
                  default:
                    // Fallback to original message format
                    final stateText = stateProvider.selectedStateId != null
                        ? "for state '${stateProvider.selectedStateName}'"
                        : "- no state selected";
                    emptyStateMessage = 'We couldn\'t find any theory modules $stateText with your current language settings.';
                }
                    
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'No theory modules found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          emptyStateMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: Icon(Icons.refresh),
                        label: Text('Refresh'),
                        onPressed: () {
                          contentProvider.fetchContentAfterSelection(forceRefresh: true);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              
              // Default to false if module progress can't be determined
              bool isCompleted = false;
              
              // Try to get completion status from ProgressProvider
              try {
                final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
                if (progressProvider != null && module != null && module.id != null) {
                  isCompleted = progressProvider.isModuleCompleted(module.id);
                }
              } catch (e) {
                print('Error checking module completion: $e');
                // Default to false if there's an error
                isCompleted = false;
              }
              
              return Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: ModuleCard(
                  module: module,
                  isCompleted: isCompleted,
                  onSelect: () async {
                    // Session validation - validate before module selection
                    if (!SessionValidationService.validateBeforeActionSafely(context)) {
                      print('🚨 TheoryScreen: Session invalid, blocking module selection');
                      return; // User will be logged out by the validation service
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrafficRuleContentScreen(topic: topic!),
                          ),
                        );
                        return; // IMPORTANT: Exit early to prevent TheoryModuleScreen navigation
                      }
                    }
                    
                    // FALLBACK: Navigate to TheoryModuleScreen for multi-topic modules or if direct navigation failed
                    print('📋 Navigating to TheoryModuleScreen (multi-topic or fallback)');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TheoryModuleScreen(module: module),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
