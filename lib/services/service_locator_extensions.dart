import 'service_locator.dart';
import '../providers/state_provider.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import 'content_loading_manager.dart';

/// Extension class for ServiceLocator to provide additional components
/// 
/// This extends the original ServiceLocator with new components
/// for state management and content loading optimization.
class ServiceLocatorExtensions {
  // Private static instances
  static StateProvider? _stateProvider;
  static LanguageProvider? _languageProvider;
  static ContentProvider? _contentProvider;
  static ContentLoadingManager? _contentLoadingManager;
  
  /// Initialize provider and manager components
  static void initialize() {
    // Create providers if they don't exist
    _stateProvider ??= StateProvider();
    
    // Get existing providers from the app
    _languageProvider = serviceLocator.$languageProvider;
    _contentProvider = serviceLocator.$contentProvider;
    
    // Create content loading manager
    _contentLoadingManager ??= ContentLoadingManager(
      contentProvider: _contentProvider!,
      languageProvider: _languageProvider!,
      stateProvider: _stateProvider!,
    );
  }
  
  /// Get the StateProvider instance
  static StateProvider get stateProvider {
    if (_stateProvider == null) {
      initialize();
    }
    return _stateProvider!;
  }
  
  /// Get the ContentLoadingManager instance
  static ContentLoadingManager get contentLoadingManager {
    if (_contentLoadingManager == null) {
      initialize();
    }
    return _contentLoadingManager!;
  }
  
  /// Reset all extensions (useful for testing)
  static void reset() {
    _stateProvider = null;
    _languageProvider = null;
    _contentProvider = null;
    _contentLoadingManager = null;
  }
}

/// Global map to store provider references
final Map<String, dynamic> _providerRegistry = {};

/// Extension to add provider access methods to ServiceLocator
extension ServiceLocatorProviderExtension on ServiceLocator {
  /// Register a LanguageProvider
  void registerLanguageProvider(LanguageProvider provider) {
    _providerRegistry['languageProvider'] = provider;
  }
  
  /// Register a ContentProvider
  void registerContentProvider(ContentProvider provider) {
    _providerRegistry['contentProvider'] = provider;
  }
  
  /// Get the registered LanguageProvider
  LanguageProvider get $languageProvider {
    final provider = _providerRegistry['languageProvider'] as LanguageProvider?;
    if (provider == null) {
      throw Exception('LanguageProvider not registered in ServiceLocator');
    }
    return provider;
  }
  
  /// Get the registered ContentProvider
  ContentProvider get $contentProvider {
    final provider = _providerRegistry['contentProvider'] as ContentProvider?;
    if (provider == null) {
      throw Exception('ContentProvider not registered in ServiceLocator');
    }
    return provider;
  }
}
