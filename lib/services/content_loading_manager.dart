import 'package:flutter/foundation.dart';
import '../providers/content_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';

/// Service for managing content loading operations.
///
/// This service coordinates when content should be loaded from the database
/// based on user language and state selections, helping to reduce unnecessary
/// database calls.
class ContentLoadingManager {
  final ContentProvider contentProvider;
  final LanguageProvider languageProvider;
  final StateProvider stateProvider;
  
  /// Track if initial content has been loaded
  bool _hasInitializedContent = false;
  
  /// Create a new ContentLoadingManager
  ContentLoadingManager({
    required this.contentProvider,
    required this.languageProvider,
    required this.stateProvider,
  }) {
    // Listen for language changes and update content when needed
    languageProvider.addListener(_onLanguageChanged);
  }
  
  /// Handle language changes
  void _onLanguageChanged() {
    if (_hasInitializedContent) {
      print('ContentLoadingManager: Language changed to: ${languageProvider.language}, updating content');
      reloadContentIfNeeded(force: true);
    } else {
      print('ContentLoadingManager: Language changed but content not initialized yet, skipping update');
    }
  }
  
  /// Check if content has been initialized
  bool get hasInitializedContent => _hasInitializedContent;
  
  /// Initialize content after both language and state are selected
  ///
  /// This method should be called only after both language and state
  /// selections are confirmed, typically when navigating to the home screen.
  /// IMPORTANT: This is the ONLY place database calls should be triggered.
  Future<void> initializeContent() async {
    // Skip if already initialized
    if (_hasInitializedContent) {
      print('ContentLoadingManager: Content already initialized, skipping');
      return;
    }
    
    // Now we allow null states
    if (languageProvider.language.isNotEmpty) {
      print('ContentLoadingManager: Initializing content with language=${languageProvider.language}, state=${stateProvider.selectedStateId ?? "null"}');
      
      // Set content provider preferences - use the selected language
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: stateProvider.selectedStateId, // Can be null
      );
      
      // Now explicitly load content after both selections are made
      // THIS IS WHERE DATABASE CALLS HAPPEN FOR CONTENT
      await _loadContent();
      
      _hasInitializedContent = true;
      print('ContentLoadingManager: Content initialization complete');
    } else {
      print('ContentLoadingManager: Cannot initialize content: language is not selected');
    }
  }
  
  /// Reload content if needed (e.g., after changing language or state)
  Future<void> reloadContentIfNeeded({bool force = false}) async {
    if (force || 
        (languageProvider.language.isNotEmpty && _hasInitializedContent)) {
      
      print('ContentLoadingManager: Reloading content - language=${languageProvider.language}, state=${stateProvider.selectedStateId ?? "null"}');
      
      // Update preferences and reload - use selected language
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: stateProvider.selectedStateId, // Can be null
      );
      
      await _loadContent();
    } else {
      print('ContentLoadingManager: Skipping content reload - conditions not met');
    }
  }
  
  /// Private method to load content
  Future<void> _loadContent() async {
    try {
      print('ContentLoadingManager: Loading content with language: ${languageProvider.language}, state: ${stateProvider.selectedStateId ?? "null"}');
      // Explicitly request content loading with user's selected language
      await contentProvider.fetchContentAfterSelection();
    } catch (e) {
      print('ContentLoadingManager: Error loading content: $e');
    }
  }
  
  /// Remove listeners and cleanup
  void dispose() {
    languageProvider.removeListener(_onLanguageChanged);
  }
  
  /// Reset state for logout
  void reset() {
    _hasInitializedContent = false;
    print('ContentLoadingManager: Reset complete');
  }
}
