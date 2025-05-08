import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theory_module.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/state_provider.dart';
import '../widgets/module_card.dart';
import 'theory_module_screen.dart';

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
      
      // Get state from provider - ensure we have a valid value
      final userState = stateProvider.selectedStateId;
      
      print('TheoryScreen: Initializing with state=$userState, language=${languageProvider.language}');
      
      // Set current language and fetch content
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: userState,
      );
      
      // Clear any previous caches to ensure we get fresh data
      contentProvider.clearAllCaches();
      
      // Wait a bit to ensure the UI is ready and preferences are set
      await Future.delayed(Duration(milliseconds: 200));
      
      // Fetch content with force refresh
      print('TheoryScreen: Explicitly fetching content with state=$userState, language=${languageProvider.language}');
      await contentProvider.fetchContentAfterSelection(forceRefresh: true);
      
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
        title: Text(
          'Теорія',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Show loading indicator
              final contentProvider = Provider.of<ContentProvider>(context, listen: false);
              contentProvider.clearAllCaches();
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
          
          if (modules.isEmpty) {
            return Consumer<StateProvider>(
              builder: (context, stateProvider, _) {
                final stateText = stateProvider.selectedStateId != null
                    ? "for state '${stateProvider.selectedStateName}'"
                    : "- no state selected";
                    
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
                          'We couldn\'t find any theory modules $stateText with your current language settings.',
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
                  onSelect: () {
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
