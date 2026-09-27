import 'package:flutter/material.dart';
import '../services/service_locator_extensions.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/state_provider.dart';
// Removed developer example imports for production build
import '../services/email_sync_service.dart';
import '../services/analytics_service.dart';
import '../services/crash_reporter.dart';
import '../services/session_notification_service.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../data/state_data.dart';
import '../widgets/enhanced_profile_card.dart';
import '../main.dart';
import 'personal_info_screen.dart';
import 'support_screen.dart';
import '../widgets/trial_status_widget.dart';
import '../theme/solar_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  /// Risk-aware gate for the content prefetch: every content callable requires
  /// entitlement, so prefetching without one is two guaranteed refusals. Skips
  /// only when a subscription exists AND is not valid — a null subscription
  /// means "unknown", which prefetches rather than guessing.
  bool get _prefetchEntitled {
    final subs = Provider.of<SubscriptionProvider>(context, listen: false);
    return !(subs.subscription != null && !subs.hasValidSubscription);
  }

  // Risk #59 — was the literal '1.0.0' on screen, so the About section lied
  // about which build the user was running.
  String _appVersion = '';

  Future<void> _loadAppVersion() async {
    try {
      final pkg = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${pkg.version}+${pkg.buildNumber}');
    } catch (e) {
      debugPrint('⚠️ ProfileScreen: could not read package version: $e');
    }
  }

  // Counter for the hidden developer menu
  int _versionTapCount = 0;
  
  // State tracking variables
  bool _isLoadingState = true;
  bool _isLoadingName = true;
  String? _cachedFirestoreState;
  String? _cachedFirestoreName;
  
  // Analytics tracking variables
  DateTime? _languageDialogStartTime;
  String? _languageBeforeChange;
  
  // State selection analytics tracking variables  
  DateTime? _stateDialogStartTime;
  String? _stateBeforeChange;
  String? _stateNameBeforeChange;
  
  // Email verification status tracking
  bool _isCheckingVerification = false;
  bool _isVerificationPending = false;
  String? _pendingEmail;
  String? _currentEmailDuringVerification;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    // Force sync the email in Firestore when the profile screen loads
    _syncEmailOnScreenLoad();
    
    // Check email verification status
    _checkEmailVerificationStatus();
    
    // Ensure state data is properly loaded
    _ensureStateDataLoaded();
    
    // Ensure user name is properly loaded from Firestore
    _ensureUserNameLoaded();
    
    // Listen for app lifecycle changes to refresh data when app resumes
    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh state data when app is resumed
      _ensureStateDataLoaded();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh state data when dependencies change (like when coming back to this screen)
    _ensureStateDataLoaded();
  }
  
  @override
  void setState(VoidCallback fn) {
    // Make sure widget is still mounted before calling setState
    if (mounted) {
      super.setState(fn);
    }
  }
  
  // Helper method to get name from Firestore (cached for performance)
  Future<String?> _getNameFromFirestore(String userId) async {
    if (_cachedFirestoreName != null) {
      return _cachedFirestoreName;
    }
    
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        _cachedFirestoreName = userDoc.data()?['name'] as String?;
        return _cachedFirestoreName;
      }
    } catch (e) {
      debugPrint('❌ ProfileScreen: Error retrieving name from Firestore: $e');
    }
    return null;
  }
  
  // Method to ensure user name is loaded correctly from Firestore
  Future<void> _ensureUserNameLoaded() async {
    // Set loading state to inform UI
    if (mounted) {
      setState(() {
        _isLoadingName = true;
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      if (user != null) {
        try {
          final userId = user.id;
          
          // First check if current name appears to be derived from email
          bool nameIsFromEmail = false;
          if (user.name.isNotEmpty) {
            final emailPrefix = user.email.split('@').first.toLowerCase();
            if (emailPrefix.isNotEmpty && user.name.toLowerCase().contains(emailPrefix)) {
              debugPrint('⚠️ ProfileScreen: Current user name appears to be derived from email: ${user.name}');
              nameIsFromEmail = true;
              
              // Check SharedPreferences for a previously saved name
              final prefs = await SharedPreferences.getInstance();
              final savedName = prefs.getString('last_user_name');
              
              if (savedName != null && savedName.isNotEmpty) {
                debugPrint('✅ ProfileScreen: Found saved name in preferences: $savedName');
                
                // Update user with the saved name from preferences
                final updatedUser = user.copyWith(
                  name: savedName,
                );
                
                // Update AuthProvider
                authProvider.user = updatedUser;
                authProvider.notifyListeners();
                
                // Also update Firestore with this name for consistency
                try {
                  await FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'name': savedName,
                    'lastUpdated': FieldValue.serverTimestamp(),
                  });
                  debugPrint('✅ ProfileScreen: Updated Firestore with name from preferences: $savedName');
                } catch (e) {
                  debugPrint('⚠️ ProfileScreen: Error updating Firestore with saved name: $e');
                }
                
                // We've found and used a saved name, so we can exit early
                if (mounted) {
                  setState(() {
                    _isLoadingName = false;
                  });
                }
                return;
              }
            }
          }
          
          // Add retry mechanism for more reliable name fetching
          int retryCount = 0;
          const maxRetries = 3;
          String? firestoreName;
          
          while (retryCount < maxRetries && (firestoreName == null || firestoreName.isEmpty)) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            
            if (userDoc.exists) {
              firestoreName = userDoc.data()?['name'] as String?;
              
              // Cache the name for later use
              _cachedFirestoreName = firestoreName;
              
              // If the name in Firestore differs from local user name, update it
              if (firestoreName != null && firestoreName.toString().isNotEmpty && 
                  (firestoreName != user.name || nameIsFromEmail)) {
                  
                debugPrint('🔄 ProfileScreen: User name mismatch - Firebase: $firestoreName, Local: ${user.name}');
                
                // Update local user object with name from Firestore
                final updatedUser = user.copyWith(
                  name: firestoreName.toString(),
                );
                
                // Update AuthProvider
                authProvider.user = updatedUser;
                authProvider.notifyListeners();
                
                debugPrint('✅ ProfileScreen: Updated user name from Firestore: $firestoreName');
                
                // Force a rebuild to show updated name
                if (mounted) {
                  setState(() {});
                }
                
                // Name found and updated, break the retry loop
                break;
              } else if (firestoreName != null && firestoreName.toString().isNotEmpty) {
                // Name in Firestore matches local name, no need to update
                debugPrint('✓ ProfileScreen: User name already matches Firestore: ${user.name}');
                break;
              }
            }
            
            // If we need to retry, wait with increasing delay
            if (firestoreName == null || firestoreName.isEmpty) {
              retryCount++;
              if (retryCount < maxRetries) {
                debugPrint('⏱️ ProfileScreen: Retry $retryCount getting user name from Firestore');
                await Future.delayed(Duration(milliseconds: 500 * retryCount));
              }
            }
          }
        } catch (e) {
          debugPrint('❌ ProfileScreen: Error fetching name from Firestore: $e');
        } finally {
          // Always update UI when done, whether successful or not
          if (mounted) {
            setState(() {
              _isLoadingName = false;
            });
          }
        }
      } else {
        // No user, just update loading state
        if (mounted) {
          setState(() {
            _isLoadingName = false;
          });
        }
      }
    });
  }
  
  // Method to ensure state data is loaded correctly from both local and remote sources
  Future<void> _ensureStateDataLoaded() async {
    // Set loading state to inform UI
    if (mounted) {
      setState(() {
        _isLoadingState = true;
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;
      
      if (user != null) {
        try {
          final userId = user.id;
          
          // Add retry mechanism for more reliable state fetching
          int retryCount = 0;
          const maxRetries = 3;
          String? firestoreState;
          
          while (retryCount < maxRetries) {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            
            if (userDoc.exists) {
              firestoreState = userDoc.data()?['state'] as String?;
              _cachedFirestoreState = firestoreState; // Cache the state for later use
              
              debugPrint('🗺️ ProfileScreen: Retrieved state from Firestore: $firestoreState');
              
              if (firestoreState != null && firestoreState.toString().isNotEmpty) {
                // Only update if Firestore has a state and it differs from local state
                if (user.state != firestoreState.toString()) {
                  debugPrint('🔄 ProfileScreen: State mismatch - Firebase: $firestoreState, Local: ${user.state}');
                  
                  // Update local user object with state from Firestore
                  final updatedUser = user.copyWith(
                    state: firestoreState.toString(),
                  );
                  
                  // Update AuthProvider
                  authProvider.user = updatedUser;
                  authProvider.notifyListeners();
                  
                  debugPrint('✅ ProfileScreen: Updated user state from Firestore: $firestoreState');
                } else {
                  debugPrint('✓ ProfileScreen: Local state already matches Firestore: ${user.state}');
                }
                
                // State found, no need to retry
                break;
              }
            }
            
            // If we need to retry, wait with increasing delay
            retryCount++;
            if (retryCount < maxRetries) {
              debugPrint('⏱️ ProfileScreen: Retry $retryCount getting user state from Firestore');
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            }
          }
        } catch (e) {
          debugPrint('❌ ProfileScreen: Error fetching state from Firestore: $e');
        } finally {
          // Always update UI when done, whether successful or not
          if (mounted) {
            setState(() {
              _isLoadingState = false;
            });
          }
        }
      } else {
        // No user, just update loading state
        if (mounted) {
          setState(() {
            _isLoadingState = false;
          });
        }
      }
    });
  }
  
  // Helper method to get state display name without translation
  String _getStateDisplayName(String? state) {
    if (state == null || state.isEmpty) {
      return 'Not selected';
    }
    return state;
  }
  
  // Helper method to convert state abbreviation to full name
  String _getFullStateName(String? stateCode) {
    if (stateCode == null || stateCode.isEmpty) {
      return 'Not selected';
    }
    
    // Try to find the state by its ID (abbreviation)
    final stateInfo = StateData.getStateById(stateCode);
    return stateInfo?.name ?? stateCode; // Return full name or code if not found
  }

  // Helper method to get profile icon asset path based on card type
  String? _getProfileIconAsset(int cardType) {
    switch (cardType) {
      case 0: return 'assets/images/profile/2_support.png';      // Support
      case 1: return 'assets/images/profile/3_language.png';     // Language  
      case 2: return 'assets/images/profile/4_state.png';        // State
      case 3: return 'assets/images/profile/5_subscription.png'; // Subscription
      default: return null;
    }
  }

  // Simplified method to check email verification status
  Future<void> _checkEmailVerificationStatus() async {
    if (mounted) {
      setState(() {
        _isCheckingVerification = true;
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // With simplified system, we don't track pending verifications
        // Just ensure the current email is up to date
        if (mounted) {
          setState(() {
            _isVerificationPending = false;
            _pendingEmail = null;
            _currentEmailDuringVerification = null;
            _isCheckingVerification = false;
          });
        }
        
        debugPrint('📧 ProfileScreen: Email verification status checked - simplified system');
        
      } catch (e) {
        debugPrint('⚠️ ProfileScreen: Error checking email verification status: $e');
        if (mounted) {
          setState(() {
            _isCheckingVerification = false;
          });
        }
      }
    });
  }

  // This method forces a sync of the email in Firestore when the profile screen loads
  void _syncEmailOnScreenLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // An async post-frame callback has no error path: anything thrown here
      // escapes to the zone rather than surfacing in the UI, and in release
      // that means a FATAL Crashlytics report. There are five awaits below,
      // every one of them a network call that can fail. Opening this screen
      // must never be able to crash the app.
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        // CRITICAL: First apply any verified email from Firebase Auth
        // This handles the case where user just completed email verification
        await authProvider.applyVerifiedEmail();

        // Force sync the email in Firebase with Firestore (simplified)
        await emailSyncService.smartSync();

        // With simplified system, no complex verification handling needed
        if (mounted) {
          // Update Firestore with the current auth email
          await emailSyncService.updateFirestoreEmail();

          // Also update the AuthProvider's user object with correct email
          await emailSyncService.updateAuthProviderEmail(context);
        }

        // After syncing, refresh the verification status
        await _checkEmailVerificationStatus();

        debugPrint('📧 ProfileScreen: Completed email sync on screen load');
      } catch (e) {
        // Email sync is background reconciliation. The screen is still usable
        // without it, so report and carry on.
        debugPrint('⚠️ ProfileScreen: Email sync on screen load failed: $e');
      }
    });
  }

  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language based on the language provider
      switch (languageProvider.language) {
        case 'es':
          return {
            'my_profile': 'Mi perfil',
            'edit_profile': 'Editar perfil',
            'support': 'Soporte',
            'support_desc': 'Respuestas a tus preguntas',
            'language_desc': 'Idioma de preguntas y app',
            'state_desc': 'Reglas y preguntas de tu estado',
            'subscription_desc': 'Todos los tests y la teoría',
            'select_language': 'Seleccionar idioma:',
            'state': 'Estado:',
            'subscription': 'Suscripción:',
            'active': 'Activa',
            'try_premium': 'Prueba premium',
            'logout': 'Cerrar sesión',
            'cancel': 'Cancelar',
            'language_changed': 'Idioma cambiado a',
            'state_changed': 'Estado cambiado a',
            'select_lang_dialog': 'Seleccionar idioma',
            'select_state_dialog': 'Seleccionar estado',
            'user_not_logged_in': 'Usuario no conectado',
            'version': 'Versión',
            'developer_options': 'Opciones de desarrollador',
            'api_switcher': 'Selector de implementación API',
            'api_switcher_desc': 'Cambiar entre REST y Firebase APIs',
            'function_mapping': 'Mapeo de nombres de funciones',
            'function_mapping_desc': 'Ver mapeos de nombres de funciones',
            'app_settings_reset': 'Restablecer configuración de la app',
            'app_settings_reset_desc': 'Restablecer todas las configuraciones y preferencias',
            'Not selected': 'No seleccionado',
            'updating_state': 'Actualizando estado...',
            'more_states_coming': 'Próximamente nuevos estados',
          }[key] ?? key;
        case 'uk':
          return {
            'my_profile': 'Мій профіль',
            'edit_profile': 'Редагувати профіль',
            'support': 'Підтримка',
            'support_desc': 'Відповіді на ваші питання',
            'language_desc': 'Мова питань і застосунку',
            'state_desc': 'Правила й питання вашого штату',
            'subscription_desc': 'Усі тести й уся теорія',
            'select_language': 'Обрати мову:',
            'state': 'Штат:',
            'subscription': 'Підписка:',
            'active': 'Активна',
            'try_premium': 'Спробуйте преміум',
            'logout': 'Вийти з акаунта',
            'cancel': 'Скасувати',
            'language_changed': 'Мову змінено на',
            'state_changed': 'Штат змінено на',
            'select_lang_dialog': 'Виберіть мову',
            'select_state_dialog': 'Виберіть штат',
            'user_not_logged_in': 'Користувач не ввійшов',
            'version': 'Версія',
            'developer_options': 'Опції розробника',
            'api_switcher': 'Перемикач реалізації API',
            'api_switcher_desc': 'Перемикати між REST та Firebase API',
            'function_mapping': 'Відображення імен функцій',
            'function_mapping_desc': 'Перегляд відображень імен функцій',
            'app_settings_reset': 'Скидання налаштувань додатку',
            'app_settings_reset_desc': 'Скинути всі налаштування та налаштування',
            'Not selected': 'Не вибрано',
            'updating_state': 'Оновлення штату...',
            'more_states_coming': 'Незабаром з\'являться нові штати',
          }[key] ?? key;
        case 'ru':
          return {
            'my_profile': 'Мой профиль',
            'edit_profile': 'Редактировать профиль',
            'support': 'Поддержка',
            'support_desc': 'Ответы на ваши вопросы',
            'language_desc': 'Язык вопросов и приложения',
            'state_desc': 'Правила и вопросы вашего штата',
            'subscription_desc': 'Все тесты и вся теория',
            'select_language': 'Выбрать язык:',
            'state': 'Штат:',
            'subscription': 'Подписка:',
            'active': 'Активна',
            'try_premium': 'Попробуйте премиум',
            'logout': 'Выйти из аккаунта',
            'cancel': 'Отмена',
            'language_changed': 'Язык изменён на',
            'state_changed': 'Штат изменён на',
            'select_lang_dialog': 'Выберите язык',
            'select_state_dialog': 'Выберите штат',
            'user_not_logged_in': 'Пользователь не вошел',
            'version': 'Версия',
            'developer_options': 'Опции разработчика',
            'api_switcher': 'Переключатель реализации API',
            'api_switcher_desc': 'Переключение между REST и Firebase API',
            'function_mapping': 'Отображение имен функций',
            'function_mapping_desc': 'Просмотр отображений имен функций',
            'app_settings_reset': 'Сброс настроек приложения',
            'app_settings_reset_desc': 'Сбросить все настройки и предпочтения',
            'Not selected': 'Не выбрано',
            'updating_state': 'Обновление штата...',
            'more_states_coming': 'Скоро появятся новые штаты',
          }[key] ?? key;
        case 'pl':
          return {
            'my_profile': 'Mój profil',
            'edit_profile': 'Edytuj profil',
            'support': 'Wsparcie',
            'support_desc': 'Odpowiedzi na twoje pytania',
            'language_desc': 'Język pytań i aplikacji',
            'state_desc': 'Przepisy i pytania twojego stanu',
            'subscription_desc': 'Wszystkie testy i teoria',
            'select_language': 'Wybierz język:',
            'state': 'Stan:',
            'subscription': 'Subskrypcja:',
            'active': 'Aktywna',
            'try_premium': 'Wypróbuj premium',
            'logout': 'Wyloguj się',
            'cancel': 'Anuluj',
            'language_changed': 'Język zmieniony na',
            'state_changed': 'Stan zmieniony na',
            'select_lang_dialog': 'Wybierz język',
            'select_state_dialog': 'Wybierz stan',
            'user_not_logged_in': 'Użytkownik nie jest zalogowany',
            'version': 'Wersja',
            'developer_options': 'Opcje deweloperskie',
            'api_switcher': 'Przełącznik implementacji API',
            'api_switcher_desc': 'Przełączanie między API REST i Firebase',
            'function_mapping': 'Mapowanie nazw funkcji',
            'function_mapping_desc': 'Zobacz mapowania nazw funkcji',
            'app_settings_reset': 'Reset ustawień aplikacji',
            'app_settings_reset_desc': 'Zresetuj wszystkie ustawienia i preferencje',
            'Not selected': 'Nie wybrano',
            'updating_state': 'Aktualizacja stanu...',
            'more_states_coming': 'Wkrótce nowe stany',
          }[key] ?? key;
        case 'en':
        default:
          return {
            'my_profile': 'My Profile',
            'edit_profile': 'Edit profile',
            'support': 'Support',
            'support_desc': 'Answers to your questions',
            'language_desc': 'Questions and app language',
            'state_desc': 'Rules and questions for your state',
            'subscription_desc': 'All tests and theory',
            'select_language': 'Select language:',
            'state': 'State:',
            'subscription': 'Subscription:',
            'active': 'Active',
            'try_premium': 'Try premium',
            'logout': 'Log out',
            'cancel': 'Cancel',
            'language_changed': 'Language changed to',
            'state_changed': 'State changed to',
            'select_lang_dialog': 'Select Language',
            'select_state_dialog': 'Select State',
            'user_not_logged_in': 'User not logged in',
            'version': 'Version',
            'developer_options': 'Developer Options',
            'api_switcher': 'API Implementation Switcher',
            'api_switcher_desc': 'Switch between REST and Firebase APIs',
            'function_mapping': 'Function Name Mapping',
            'function_mapping_desc': 'View function name mappings',
            'app_settings_reset': 'App Settings Reset',
            'app_settings_reset_desc': 'Reset all app settings and preferences',
            'updating_state': 'Updating state...',
            'more_states_coming': 'More states coming soon',
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [PROFILE SCREEN] Error getting translation: $e');
      // Default fallback
      return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        print('👤 [PROFILE SCREEN] Building with language: ${languageProvider.language}');

        if (user == null) {
          return Scaffold(
            body: Center(
              child: Text(_translate('user_not_logged_in', languageProvider)),
            ),
          );
        }

        final blocks = <Widget>[
          // The trial card sits inside the tab's gutter and scrolls with the
          // page, as on Тесты and Теория.
          TrialStatusWidget(),
          const SizedBox(height: AppSpacing.x4),
          // The page's one hero, in the Тесты exam card's blue (owner,
          // 2026-09-26: "use such colours for Profile").
          _buildProfileHeader(user, languageProvider),
          const SizedBox(height: AppSpacing.x8),
          _buildSectionHeader(AppLocalizations.of(context).translate('settings')),
          _buildEnhancedMenuCard(
            _translate('select_language', languageProvider),
            languageProvider.languageName,
            SolarIcons.globalLinear,
            1,
            true, // Highlight language name
            () => _onLanguage(languageProvider),
            iconAsset: _getProfileIconAsset(1),
            description: _translate('language_desc', languageProvider),
          ),
          const SizedBox(height: AppSpacing.x3),
          _buildEnhancedMenuCard(
            _translate('state', languageProvider),
            _isLoadingState 
              ? "Loading..." // Show loading indicator while fetching state
              : ((authProvider.user?.state?.isNotEmpty == true) 
                  ? _getFullStateName(authProvider.user!.state!).split(' ').map((word) => 
                      word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                    ).join(' ') // Convert to title case
                  : _translate('Not selected', languageProvider)),
            SolarIcons.mapPointBold,
            2,
            true, // The chosen state, shown as a value pill
            () => _onState(languageProvider),
            iconAsset: _getProfileIconAsset(2),
            description: _translate('state_desc', languageProvider),
          ),
          const SizedBox(height: AppSpacing.x3),
          // The secondary destination as the dark card, as «Сохраненные».
          _buildEnhancedMenuCard(
            _translate('subscription', languageProvider),
            subscriptionProvider.isSubscriptionActive 
                ? _translate('active', languageProvider) 
                : _translate('try_premium', languageProvider),
            SolarIcons.medalRibbonsStarBold,
            3,
            subscriptionProvider.isSubscriptionActive, // Highlight if active
            _onSubscription,
            iconAsset: _getProfileIconAsset(3),
            dark: true,
            description: _translate('subscription_desc', languageProvider),
          ),
          const SizedBox(height: AppSpacing.x3),
          _buildEnhancedMenuCard(
            _translate('support', languageProvider),
            _translate('support_desc', languageProvider),
            SolarIcons.questionCircleLinear,
            0,
            false,
            _onSupport,
            iconAsset: _getProfileIconAsset(0),
          ),
          const SizedBox(height: AppSpacing.x6),
          _buildLogoutButton(authProvider, languageProvider),
          const SizedBox(height: AppSpacing.x4),
          _buildVersion(languageProvider),
          const SizedBox(height: AppSpacing.x6),
        ];

        return Scaffold(
          // No title bar: the tab bar already says where you are, and the bar
          // took a full row above the content.
          body: SafeArea(
            bottom: false,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                _gutter,
                AppSpacing.x2,
                _gutter,
                0,
              ),
              itemCount: blocks.length,
              // One-shot entrance, capped so the page lands inside
              // AppMotion.base.
              itemBuilder: (context, index) => StaggerIn(
                index: index,
                count: blocks.length,
                curve: BentoTokens.curve,
                child: blocks[index],
              ),
            ),
          ),
        );
      }
    );
  }

  /// The tab's side gutter — the same as Тесты and Теория.
  static const double _gutter = AppSpacing.x4 + AppSpacing.x1;

  // Handlers — moved unchanged from the inline closures, so the cards can
  // change without touching navigation, dialogs or logout.

  void _onEditProfile() {
    // Navigate to edit profile screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInfoScreen(),
      ),
    );
  }

  void _onSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupportScreen(),
      ),
    );
  }

  void _onLanguage(LanguageProvider languageProvider) {
    _showLanguageSelector(context, languageProvider);
  }

  void _onState(LanguageProvider languageProvider) {
    // Force Firestore refresh and wait for it to complete before showing selector
    setState(() { _isLoadingState = true; });
    _ensureStateDataLoaded().then((_) {
      _showStateSelector(context, languageProvider);
    });
  }

  void _onSubscription() {
    Navigator.pushNamed(context, '/subscription');
  }

  Future<void> _onLogout(AuthProvider authProvider) async {
    await authProvider.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _onVersionTap(LanguageProvider languageProvider) {
    setState(() {
      _versionTapCount++;
      if (_versionTapCount >= 5) {
        _versionTapCount = 0;
        _showDeveloperOptions(context, languageProvider);
      }
    });
  }

  /// A section label, as on Тесты: 15/600 ink, 12 below.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          fontSize: 15,
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  /// The page's hero, in the Тесты exam card's blue gradient: the avatar on a
  /// white disc, the name (22/700, the page's largest title), the email, and
  /// «Редактировать профиль» as the solid white pill. The whole card opens the
  /// profile editor, like the exam card; the pill says what it does.
  Widget _buildProfileHeader(User user, LanguageProvider languageProvider) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onEditProfile,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BentoTokens.card),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.signal600, AppColors.signal, AppColors.signal400],
              stops: [0, 0.55, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x290048C3),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // The exam card's bar strip, larger and fainter, rising from
              // the card's bottom edge behind the text (owner, 2026-09-26:
              // "bigger, more in the background"). Decoration only.
              Positioned(
                right: AppSpacing.x4 + AppSpacing.x1,
                bottom: 0,
                child: ExcludeSemantics(child: _heroBars()),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.paper,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/profile/1_user_avatar.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ ProfileScreen: Failed to load avatar asset: $error');
                          // Show CircleAvatar with text only as fallback
                          return CircleAvatar(
                            radius: 29,
                            backgroundColor: AppColors.signal50,
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                              style: AppTypography.title.copyWith(
                                color: AppColors.signal,
                                fontVariations: const [FontVariation('wght', 600)],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.title.copyWith(
                            fontSize: 22,
                            height: 28 / 22,
                            color: AppColors.onSignal,
                            fontVariations: const [FontVariation('wght', 700)],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: AppColors.signal100,
                            fontVariations: const [FontVariation('wght', 400)],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              // The solid white pill, as «60 минут» on the exam card.
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(BentoTokens.chip),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    _translate('edit_profile', languageProvider),
                    maxLines: 1,
                    style: AppTypography.label.copyWith(
                      color: AppColors.signal,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                ),
              ),
            ],
          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The same rising bar strip as the Тесты exam card
  /// (`EnhancedTestCard._questionBars`, frozen — copied, not shared).
  Widget _heroBars() {
    const heights = [
      10, 16, 12, 22, 14, 26, 18, 30, 20, 34, 24, 28, 38, 26, 42, 30, 36, 46,
      32, 40, 50, 36, 44, 54, 40, 48, 58, 44, 52, 60, 48, 56, 62, 52, 58, 64,
      56, 60, 66, 62,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in heights)
          Container(
            width: 3,
            height: h * 1.5,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: AppColors.onSignal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }

  /// «Выйти из аккаунта»: a white pill with a red label — red because it is
  /// destructive, not decoration.
  Widget _buildLogoutButton(AuthProvider authProvider, LanguageProvider languageProvider) {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: radius,
          boxShadow: AppColors.shadowCard,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onLogout(authProvider),
            borderRadius: radius,
            child: Center(
              child: Text(
                _translate('logout', languageProvider),
                style: AppTypography.label.copyWith(
                  fontSize: 16,
                  color: AppColors.stop,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The version line; five taps open the developer options.
  Widget _buildVersion(LanguageProvider languageProvider) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onVersionTap(languageProvider),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          child: Text(
            '${_translate('version', languageProvider)} $_appVersion',
            style: AppTypography.caption.copyWith(
              color: AppColors.inkSecondary,
              fontVariations: const [FontVariation('wght', 400)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedMenuCard(
    String title,
    String subtitle,
    IconData icon,
    int cardType,
    bool isHighlighted,
    VoidCallback onTap,
    {String? iconAsset, bool dark = false, String? description}
  ) {
    return EnhancedProfileCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      cardType: cardType,
      isHighlighted: isHighlighted,
      onTap: onTap,
      iconAsset: iconAsset,
      dark: dark,
      description: description,
    );
  }

  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('provider')) {
      return 'provider_error';
    } else if (errorMessage.contains('auth')) {
      return 'auth_error';
    } else if (errorMessage.contains('network')) {
      return 'network_error';
    } else {
      return 'unknown_error';
    }
  }

  void _showLanguageSelector(BuildContext context, LanguageProvider languageProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Track dialog opening
    _languageDialogStartTime = DateTime.now();
    _languageBeforeChange = languageProvider.language;
    
    analyticsService.logLanguageSelectionStarted(
      selectionContext: 'profile',
      currentLanguage: _languageBeforeChange,
    );
    debugPrint('📊 Analytics: language_selection_started logged (context: profile)');

    // Map language codes to display names
    final Map<String, String> languageNames = {
      'en': 'English',
      'es': 'Spanish',
      'uk': 'Українська',
      'pl': 'Polish',
      'ru': 'Russian',
    };

    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate('select_lang_dialog', languageProvider)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', 'en', languageProvider, authProvider),
            _buildLanguageOption(context, 'Spanish', 'es', languageProvider, authProvider),
            _buildLanguageOption(context, 'Ukrainian', 'uk', languageProvider, authProvider),
            _buildLanguageOption(context, 'Polish', 'pl', languageProvider, authProvider),
            _buildLanguageOption(context, 'Russian', 'ru', languageProvider, authProvider),
          ],
        ),
      ),
    ).then((result) {
      // Handle dialog result using parent context
      if (result != null && mounted) {
        if (result['success'] == true) {
          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_translate('language_changed', result['provider'])} ${result['languageName']}'),
              duration: Duration(seconds: 1),
            ),
          );
        } else if (result['success'] == false) {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']),
              backgroundColor: AppColors.stop,
            ),
          );
        }
      }
    });
  }

  // Picker dialogs (language, state) in the Тесты look (2026-09-26): each
  // option a rounded field row, the current one the dark `ink` row — no
  // tick, the fill says it (owner: "select black, not blue… no check"). The
  // ListTiles and their onTap are unchanged.
  static final ShapeBorder _pickerShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.lg),
  );

  /// Each language in its own name, as on the Профиль card
  /// (`LanguageProvider.languageName`) — display only; the English name still
  /// goes to analytics and the result (owner, 2026-09-26).
  static const Map<String, String> _nativeLanguageNames = {
    'en': 'English',
    'es': 'Español',
    'uk': 'Українська',
    'pl': 'Polski',
    'ru': 'Русский',
  };

  Widget _pickerOption(Widget tile) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x2),
        child: tile,
      );

  TextStyle _pickerOptionStyle(bool selected) => AppTypography.body.copyWith(
        fontSize: 17,
        color: selected ? AppColors.onSignal : AppColors.ink,
        fontVariations: [FontVariation('wght', selected ? 600 : 400)],
      );

  Widget _buildLanguageOption(BuildContext context, String language, String code, 
      LanguageProvider provider, AuthProvider authProvider) {
    final isSelected = provider.language == code;
    return _pickerOption(ListTile(
      title: Text(_nativeLanguageNames[code] ?? language, style: _pickerOptionStyle(isSelected)),
      selected: isSelected,
      shape: _pickerShape,
      tileColor: AppColors.field,
      selectedTileColor: AppColors.ink,
      minTileHeight: 52,
      onTap: () async {
        // Captured here, outside the try, for two reasons: the context is
        // certainly mounted at this point, and the catch block needs it too.
        //
        // This is the other half of the same defect. `Navigator.pop(context,
        // ...)` below looks up an ancestor through an element that the locale
        // rebuild has deactivated, and throws "Looking up a deactivated
        // widget's ancestor is unsafe" — once inside the try, and then AGAIN
        // inside the catch, where nothing catches it, so an unhandled
        // exception escaped on every language change from settings. A
        // NavigatorState survives the rebuild; the element used to find it
        // does not.
        final navigator = Navigator.of(context);

        // ...and popping it must also wait for the frame the rebuild is in.
        // `setLanguage` changes `MaterialApp.locale` synchronously, so when
        // the continuation after the await resumes, the Navigator is still
        // locked mid-build and `pop` trips its own `!_debugLocked` assertion.
        // Deferring to after the frame is the difference between "the work
        // succeeded" and "the work succeeded and then threw about it".
        void popAfterFrame(Map<String, dynamic> result) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (navigator.mounted) navigator.pop(result);
          });
        }

        try {
          // Get current language before change
          final previousLanguage = provider.language;

          // Read entitlement BEFORE the awaits below, and this is not a
          // tidy-up — it is the fix for a defect found by hand on the
          // simulator on 2026-09-17.
          //
          // `_prefetchEntitled` touches `State.context`. `setLanguage`
          // notifies its listeners, which changes `MaterialApp.locale`, which
          // rebuilds the whole tree — and `HomeScreen` rebuilds its `_screens`
          // list, so THIS State is unmounted before the await returns. Reading
          // `context` afterwards threw `This widget has been unmounted`, and
          // because the throw happened while evaluating an argument, three
          // things never ran: the prefetch itself, the `language_changed`
          // analytics event, and the success `Navigator.pop`. Every language
          // change from settings was recorded as `language_change_failed`
          // while actually succeeding.
          //
          // The state handler below has the same shape and does NOT break,
          // because changing the state does not change the locale, so its
          // State survives its awaits. That asymmetry is why the state half of
          // the prefetch was observed working and the language half was not.
          final wasEntitled = _prefetchEntitled;

          // Update both providers (same as signup flow)
          await provider.setLanguage(code);
          await authProvider.updateUserLanguage(code);

          // Re-warm the cache for the new language, in the background.
          ServiceLocatorExtensions.contentLoadingManager.prefetchInBackground(
            entitled: wasEntitled,
            reason: 'language changed in settings',
          );
          
          // Calculate time spent
          final timeSpent = _languageDialogStartTime != null 
              ? DateTime.now().difference(_languageDialogStartTime!).inSeconds 
              : null;
          
          // Track successful language change
          analyticsService.logLanguageChanged(
            selectionContext: 'profile',
            previousLanguage: previousLanguage,
            newLanguage: code,
            languageName: language,
            timeSpentSeconds: timeSpent,
          );
          debugPrint('📊 Analytics: language_changed logged (profile: $previousLanguage → $code)');
          
          // Close dialog with success result
          popAfterFrame({
            'success': true,
            'language': code,
            'languageName': language,
            'previousLanguage': previousLanguage,
            'provider': provider,
          });
          
        } catch (e) {
          // Enhanced error logging with truncation
          final errorMessage = e.toString();
          final truncatedError = errorMessage.length > 100 
              ? errorMessage.substring(0, 97) + '...'
              : errorMessage;
          
          analyticsService.logLanguageChangeFailed(
            selectionContext: 'profile',
            targetLanguage: code,
            errorType: _getErrorType(errorMessage),
            errorMessage: truncatedError,
          );
          debugPrint('📊 Analytics: language_change_failed logged (profile: $code)');
          debugPrint('🚨 Profile Screen: Language change error: $errorMessage');
          
          // Close dialog with error result. Deferred for the same reason as
          // the success path — this pop is inside the catch, so a throw here
          // is unhandled.
          popAfterFrame({
            'success': false,
            'error': 'Error changing language. Please try again.',
            'targetLanguage': code,
          });
        }
      },
    ));
  }

  void _showStateSelector(BuildContext context, LanguageProvider languageProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentState = authProvider.user?.state;
    
    // Track dialog opening
    _stateDialogStartTime = DateTime.now();
    _stateBeforeChange = currentState;
    _stateNameBeforeChange = currentState != null 
        ? _getFullStateName(currentState)
        : 'Not selected';
    
    analyticsService.logStateSelectionStarted(
      selectionContext: 'profile',
      currentState: _stateBeforeChange,
      currentStateName: _stateNameBeforeChange,
    );
    debugPrint('📊 Analytics: state_selection_started logged (context: profile)');
    
    // Get only visible states from StateData
    final visibleStates = StateData.getVisibleStates();
    
    // Declared outside the builder so it survives setDialogState. Inside the
    // builder it was reset to false on every rebuild, so the «Обновление
    // штата…» spinner never showed and the rows were never disabled
    // (fixed 2026-09-26, owner).
    bool _isDialogLoading = false;
    
    showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true, // Allow dismissal by tapping outside
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(_translate('select_state_dialog', languageProvider)),
            content: Container(
              width: double.maxFinite,
              // Up to 400 tall, scrolling beyond — no empty band under a
              // short list (was a fixed 400).
              constraints: const BoxConstraints(maxHeight: 400),
              child: _isDialogLoading
                  // About as tall as the two-state list, so the dialog does
                  // not jump to its 400 maximum while the state saves.
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
                      child: Center(
                      heightFactor: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.signal),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _translate('updating_state', languageProvider),
                            style: AppTypography.label.copyWith(
                              color: AppColors.inkSecondary,
                              fontVariations: const [FontVariation('wght', 400)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: visibleStates.length,
                            itemBuilder: (context, index) {
                              final stateInfo = visibleStates[index];
                              final state = stateInfo.name;
                              final stateId = stateInfo.id;
                              final isSelected = state == currentState || stateId == currentState;
                              
                              // Convert state name to title case for display
                              final titleCaseState = state.split(' ').map((word) => 
                                word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                              ).join(' ');
                              
                              return _pickerOption(ListTile(
                                title: Text(titleCaseState, style: _pickerOptionStyle(isSelected)),
                                selected: isSelected,
                                shape: _pickerShape,
                                tileColor: AppColors.field,
                                selectedTileColor: AppColors.ink,
                                minTileHeight: 52,
                                enabled: !_isDialogLoading, // Disable during loading
                                onTap: () async {
                                  // Set loading state. Safe today — this runs
                                  // synchronously from the tap, before any
                                  // await — but guarded anyway so the rule is
                                  // "every setDialogState is guarded" with no
                                  // exceptions to reason about. See #70.
                                  if (!dialogContext.mounted) return;
                                  // Set loading state
                                  setDialogState(() {
                                    _isDialogLoading = true;
                                  });
                                  
                                  try {
                                    // Calculate time spent
                                    final timeSpent = _stateDialogStartTime != null 
                                        ? DateTime.now().difference(_stateDialogStartTime!).inSeconds 
                                        : null;
                                    
                                    // Update state in auth provider (use state name)
                                    await authProvider.updateUserState(state);
                                    
                                    // CRITICAL FIX: Also update StateProvider to sync with AuthProvider
                                    // This ensures TheoryScreen gets the updated state immediately
                                    final stateProvider = Provider.of<StateProvider>(context, listen: false);
                                    await stateProvider.setSelectedState(stateId);
                                    
                                    debugPrint('🔄 ProfileScreen: Updated both AuthProvider and StateProvider with state: $stateId');

                                    // Re-warm the cache for the new state, in
                                    // the background. Called explicitly rather
                                    // than relying on the manager's state
                                    // listener, because that listener is only
                                    // live once initializeContent has run —
                                    // which never happened for accounts created
                                    // before the prefetch existed.
                                    ServiceLocatorExtensions.contentLoadingManager
                                        .prefetchInBackground(
                                          entitled: _prefetchEntitled,
                                          reason: 'state changed in settings',
                                        );
                                    
                                    // Track successful state change
                                    analyticsService.logStateChanged(
                                      selectionContext: 'profile',
                                      previousState: _stateBeforeChange,
                                      previousStateName: _stateNameBeforeChange,
                                      newState: stateId,
                                      newStateName: titleCaseState,
                                      timeSpentSeconds: timeSpent,
                                    );
                                    debugPrint('📊 Analytics: state_changed logged (profile: ${_stateBeforeChange ?? "none"} → $stateId)');
                                    
                                    // Force immediate UI update
                                    if (mounted) {
                                      setState(() {
                                        // This will trigger an immediate UI rebuild
                                        _isLoadingState = false;
                                      });
                                    }
                                    
                                    // Risk #70 — every line below this point runs
                                    // AFTER an await, so the dialog may already
                                    // be gone. Guard the pop the way line 1046
                                    // already does.
                                    if (!dialogContext.mounted) return;
                                    // Close dialog with success result
                                    Navigator.pop(dialogContext, {
                                      'success': true,
                                      'state': stateId,
                                      'stateName': titleCaseState,
                                      'previousState': _stateBeforeChange,
                                    });
                                    
                                  } catch (e, stackTrace) {
                                    // The stack was being thrown away here.
                                    //
                                    // Only `e.toString()` reached analytics,
                                    // truncated to 100 chars, which is how a
                                    // real failure on this path stayed
                                    // undiagnosable: the device reported
                                    // `state_change_failed` with
                                    // "Null check operator used on a null
                                    // value" and no way to tell WHICH `!` —
                                    // and #34 means the Dart log says nothing
                                    // in release. Record it as a non-fatal so
                                    // the next occurrence arrives with frames.
                                    crashReporter.recordNonFatal(
                                      e,
                                      stackTrace,
                                      reason: 'state change failed',
                                      keys: {
                                        'target_state': state,
                                        'previous_state': _stateBeforeChange,
                                        'selection_context': 'profile',
                                      },
                                    );

                                    // Enhanced error logging
                                    final errorMessage = e.toString();
                                    final truncatedError = errorMessage.length > 100 
                                        ? errorMessage.substring(0, 97) + '...'
                                        : errorMessage;
                                    
                                    analyticsService.logStateChangeFailed(
                                      selectionContext: 'profile',
                                      targetState: state,
                                      targetStateName: titleCaseState,
                                      errorType: _getErrorType(errorMessage),
                                      errorMessage: truncatedError,
                                    );
                                    debugPrint('📊 Analytics: state_change_failed logged (profile: $state)');
                                    debugPrint('🚨 Profile Screen: State change error: $errorMessage');
                                    
                                    // Risk #70 — THIS was the crash, and it is
                                    // the error path specifically. `setState`
                                    // does `_element!.markNeedsBuild()`, so on
                                    // an unmounted State the `!` throws
                                    // "Null check operator used on a null
                                    // value" from framework.dart:1219 — a Dart
                                    // error inside Flutter, not a `!` of ours.
                                    //
                                    // Reproduced on a Galaxy S10 Lite
                                    // 2026-09-19: change state with no network,
                                    // then dismiss the dialog by tapping
                                    // outside while `updateUserState` is still
                                    // in flight. It then fails, this catch
                                    // runs, and the StatefulBuilder is gone.
                                    //
                                    // The success path above already had
                                    // `if (mounted)` on its setState; the error
                                    // path had nothing. Failure paths run in
                                    // exactly the conditions that unmount
                                    // things, so they need the guard MORE.
                                    if (!dialogContext.mounted) return;
                                    // Reset loading state on error
                                    setDialogState(() {
                                      _isDialogLoading = false;
                                    });
                                    
                                    // Close dialog with error result
                                    Navigator.pop(dialogContext, {
                                      'success': false,
                                      'error': 'Error changing state. Please try again.',
                                      'targetState': state,
                                    });
                                  }
                                },
                              ));
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            _translate('more_states_coming', languageProvider),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.inkSecondary,
                              fontVariations: const [FontVariation('wght', 400)],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    ).then((result) {
      // Handle dialog result
      if (result != null && mounted) {
        if (result['success'] == true) {
          // Show success snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_translate('state_changed', languageProvider)} ${result['stateName']}'),
              duration: Duration(seconds: 1),
            ),
          );
        } else if (result['success'] == false) {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']),
              backgroundColor: AppColors.stop,
            ),
          );
        }
      }
    });
  }

  /// Test method to simulate session conflict flow
  void _testFullSessionConflictFlow(BuildContext context) {
    debugPrint('🧪 ProfileScreen: Testing full session conflict flow');
    
    try {
      // Import the session validation service and session manager
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Simulate session becoming invalid by directly calling the global handler
      debugPrint('🧪 ProfileScreen: Simulating session conflict by calling global handler');
      
      // Import the main.dart function
      handleGlobalSessionConflict(authProvider);
      
      debugPrint('✅ ProfileScreen: Session conflict flow test initiated');
      
    } catch (e) {
      debugPrint('❌ ProfileScreen: Error testing session conflict flow: $e');
      
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          backgroundColor: AppColors.stop,
        ),
      );
    }
  }

  /// A developer-sheet row: a white tile with its icon on a soft disc.
  Widget _devOption({
    required IconData icon,
    required Color tone,
    required Color surface,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x2),
      child: ListTile(
        tileColor: AppColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x1,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, color: tone, size: 20),
        ),
        title: Text(
          title,
          style: AppTypography.body.copyWith(
            fontSize: 16,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.label.copyWith(color: AppColors.inkSecondary),
        ),
        onTap: onTap,
      ),
    );
  }

  /// Hidden developer tools (five taps on the version line), as a Bento
  /// sheet: field background, the card corner, a drag handle, white rows.
  /// Sized to its rows rather than 80% of the screen.
  void _showDeveloperOptions(BuildContext context, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.field,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4 + AppSpacing.x1,
            0,
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x4),
                child: Text(
                  _translate('developer_options', languageProvider),
                  style: AppTypography.title.copyWith(
                    fontSize: 22,
                    height: 28 / 22,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
              ),
              // Removed developer example navigation options for production build
              _devOption(
                icon: SolarIcons.settingsBold,
                tone: AppColors.signal,
                surface: AppColors.signal50,
                title: _translate('app_settings_reset', languageProvider),
                subtitle: _translate('app_settings_reset_desc', languageProvider),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings/reset');
                },
              ),
              // Debug option for testing session conflict notifications
              if (kDebugMode)
                _devOption(
                  icon: SolarIcons.logout2Linear,
                  tone: AppColors.warn,
                  surface: AppColors.warnSurface,
                  title: 'Test Session Conflict Notification',
                  subtitle: 'Show session conflict notification for testing',
                  onTap: () {
                    Navigator.pop(context);
                    SessionNotificationService.showTestNotification(context);
                  },
                ),
              // Debug option for testing full session conflict flow
              if (kDebugMode)
                _devOption(
                  icon: SolarIcons.shieldCheckBold,
                  tone: AppColors.stop,
                  surface: AppColors.stopSurface,
                  title: 'Test Full Session Conflict Flow',
                  subtitle: 'Simulate session conflict with immediate logout',
                  onTap: () {
                    Navigator.pop(context);
                    _testFullSessionConflictFlow(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

}
