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
    
    // Listen for state changes
    stateProvider.addListener(_onStateChanged);
  }
  
  /// Handle language changes
  void _onLanguageChanged() {
    // Only react to language changes if content has been initialized
    // This prevents interference during sign-up flow
    if (_hasInitializedContent) {
      print('ContentLoadingManager: Language changed to: ${languageProvider.language}, updating content');
      reloadContentIfNeeded(force: true);
    } else {
      print('ContentLoadingManager: Language changed during initialization, skipping content update');
    }
  }
  
  /// Handle state changes
  void _onStateChanged() {
    if (_hasInitializedContent) {
      print('ContentLoadingManager: State changed to: ${stateProvider.selectedStateId}, updating content');
      reloadContentIfNeeded(force: true);
    } else {
      print('ContentLoadingManager: State changed during initialization, skipping content update');
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
    
    if (languageProvider.language.isNotEmpty) {
      // CRITICAL FIX: Use async-safe state access
      final selectedStateId = await stateProvider.getSelectedStateIdSafe();
      
      print('ContentLoadingManager: Initializing content with language=${languageProvider.language}, state=${selectedStateId ?? "null"}');
      print('ContentLoadingManager: StateProvider isInitialized: ${stateProvider.isInitialized}');
      
      // Set content provider preferences with properly retrieved state
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: selectedStateId, // Now properly retrieved!
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
      
      final selectedStateId = await stateProvider.getSelectedStateIdSafe();
      
      print('ContentLoadingManager: Reloading content - language=${languageProvider.language}, state=${selectedStateId ?? "null"}');
      
      // Update preferences and reload
      contentProvider.setPreferences(
        language: languageProvider.language,
        state: selectedStateId, // Now properly retrieved!
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
    stateProvider.removeListener(_onStateChanged); // Add this line
  }
  
  /// Reset state for logout
  void reset() {
    _hasInitializedContent = false;
    print('ContentLoadingManager: Reset complete');
  }
}
