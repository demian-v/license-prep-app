import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/module_card.dart';
import 'theory_module_screen.dart';
import 'traffic_rule_content_screen.dart';

class TheoryScreen extends StatefulWidget {
  @override
  _TheoryScreenState createState() => _TheoryScreenState();
}

class _TheoryScreenState extends State<TheoryScreen> {
  @override
  void initState() {
    super.initState();
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              // Clear cache for current state/language and force refresh
              final contentProvider = Provider.of<ContentProvider>(context, listen: false);
              await contentProvider.clearSpecificCache();
              contentProvider.fetchContentAfterSelection(forceRefresh: true);
              
              // Show a snackbar to indicate refresh is happening
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Refreshing content...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              // Search functionality (to be implemented)
            },
          ),
        ],
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
          
          if (shouldShowEmptyState) {
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
                    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
                    
                    // Get the topics list from the module
                    final topicsList = module.getTopicsList();
                    
                    // If there's only one topic, navigate directly to content
                    if (topicsList.length == 1) {
                      final topicId = topicsList[0];
                      final topic = await contentProvider.getTopicById(topicId);
                      
                      if (topic != null) {
                        // Navigate directly to content screen for single topic
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrafficRuleContentScreen(topic: topic),
                          ),
                        );
                        return;
                      }
                    }
                    
                    // For modules with multiple topics, navigate directly to the module screen
                    // This will show the numbered topics list
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
