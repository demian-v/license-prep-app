import 'package:flutter/material.dart';
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
import '../services/session_notification_service.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../data/state_data.dart';
import '../widgets/enhanced_profile_card.dart';
import '../main.dart';
import 'personal_info_screen.dart';
import 'support_screen.dart';
import '../widgets/trial_status_widget.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
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

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _translate('my_profile', languageProvider),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Colors.black,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Add TrialStatusWidget here - under "My Profile" title, above profile card
                TrialStatusWidget(),
                
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Container(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.4)],
                        stops: [0.0, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 0,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/profile/1_user_avatar.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('❌ ProfileScreen: Failed to load avatar asset: $error');
                              // Show CircleAvatar with text only as fallback
                              return CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.indigo.shade400,
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              // Email display (simplified)
                              Row(
                                children: [
                                  Icon(
                                    Icons.email,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.email,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  // Navigate to edit profile screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PersonalInfoScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  _translate('edit_profile', languageProvider),
                                  style: TextStyle(
                                    color: Colors.indigo.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildEnhancedMenuCard(
                    _translate('support', languageProvider),
                    _translate('support_desc', languageProvider),
                    Icons.help_outline,
                    0, // Support - Green
                    false,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SupportScreen(),
                        ),
                      );
                    },
                    iconAsset: _getProfileIconAsset(0),
                  ),
                  SizedBox(height: 16),
                  _buildEnhancedMenuCard(
                    _translate('select_language', languageProvider),
                    languageProvider.languageName,
                    Icons.language,
                    1, // Language - Blue
                    true, // Highlight language name
                    () {
                      _showLanguageSelector(context, languageProvider);
                    },
                    iconAsset: _getProfileIconAsset(1),
                  ),
                  SizedBox(height: 16),
                  _buildEnhancedMenuCard(
                    _translate('state', languageProvider),
                    _isLoadingState 
                      ? "Loading..." // Show loading indicator while fetching state
                      : ((authProvider.user?.state?.isNotEmpty == true) 
                          ? _getFullStateName(authProvider.user!.state!).split(' ').map((word) => 
                              word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                            ).join(' ') // Convert to title case
                          : _translate('Not selected', languageProvider)),
                    Icons.location_on,
                    2, // State - Purple
                    false,
                    () {
                      // Force Firestore refresh and wait for it to complete before showing selector
                      setState(() { _isLoadingState = true; });
                      _ensureStateDataLoaded().then((_) {
                        _showStateSelector(context, languageProvider);
                      });
                    },
                    iconAsset: _getProfileIconAsset(2),
                  ),
                  SizedBox(height: 16),
                  _buildEnhancedMenuCard(
                    _translate('subscription', languageProvider),
                    subscriptionProvider.isSubscriptionActive 
                        ? _translate('active', languageProvider) 
                        : _translate('try_premium', languageProvider),
                    Icons.workspace_premium,
                    3, // Subscription - Amber
                    subscriptionProvider.isSubscriptionActive, // Highlight if active
                    () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                    iconAsset: _getProfileIconAsset(3),
                  ),
                  SizedBox(height: 24),
                  // Custom logout button with centered text
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black.withOpacity(0.3),
                    margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.red.shade50.withOpacity(0.4)],
                          stops: [0.0, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 0,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            await authProvider.logout();
                            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                          },
                          borderRadius: BorderRadius.circular(12),
                          splashColor: Colors.white.withOpacity(0.3),
                          highlightColor: Colors.white.withOpacity(0.2),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                            child: Center(
                              child: Text(
                                _translate('logout', languageProvider),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Hidden developer menu trigger
                  SizedBox(height: 40),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _versionTapCount++;
                        if (_versionTapCount >= 5) {
                          _versionTapCount = 0;
                          _showDeveloperOptions(context, languageProvider);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '${_translate('version', languageProvider)} 1.0.0',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildEnhancedMenuCard(
    String title,
    String subtitle,
    IconData icon,
    int cardType,
    bool isHighlighted,
    VoidCallback onTap,
    {String? iconAsset}
  ) {
    return EnhancedProfileCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      cardType: cardType,
      isHighlighted: isHighlighted,
      onTap: onTap,
      iconAsset: iconAsset,
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
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  Widget _buildLanguageOption(BuildContext context, String language, String code, 
      LanguageProvider provider, AuthProvider authProvider) {
    return ListTile(
      title: Text(language),
      trailing: provider.language == code ? Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        try {
          // Get current language before change
          final previousLanguage = provider.language;
          
          // Update both providers (same as signup flow)
          await provider.setLanguage(code);
          await authProvider.updateUserLanguage(code);
          
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
          Navigator.pop(context, {
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
          
          // Close dialog with error result
          Navigator.pop(context, {
            'success': false,
            'error': 'Error changing language. Please try again.',
            'targetLanguage': code,
          });
        }
      },
    );
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
    
    showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true, // Allow dismissal by tapping outside
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool _isDialogLoading = false;
          
          return AlertDialog(
            title: Text(_translate('select_state_dialog', languageProvider)),
            content: Container(
              width: double.maxFinite,
              height: 400, // Fixed height for scrollable content
              child: _isDialogLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                          ),
                          SizedBox(height: 16),
                          Text(
                            _translate('updating_state', languageProvider),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
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
                              
                              return ListTile(
                                title: Text(titleCaseState),
                                trailing: isSelected ? Icon(Icons.check, color: Colors.green) : null,
                                enabled: !_isDialogLoading, // Disable during loading
                                onTap: () async {
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
                                    
                                    // Close dialog with success result
                                    Navigator.pop(dialogContext, {
                                      'success': true,
                                      'state': stateId,
                                      'stateName': titleCaseState,
                                      'previousState': _stateBeforeChange,
                                    });
                                    
                                  } catch (e) {
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
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            _translate('more_states_coming', languageProvider),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
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
              backgroundColor: Colors.red,
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
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeveloperOptions(BuildContext context, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _translate('developer_options', languageProvider),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Divider(),
            Expanded(
              child: ListView(
                children: [
                  // Removed developer example navigation options for production build
                  ListTile(
                    leading: Icon(Icons.settings_applications),
                    title: Text(_translate('app_settings_reset', languageProvider)),
                    subtitle: Text(_translate('app_settings_reset_desc', languageProvider)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings/reset');
                    },
                  ),
                  // Debug option for testing session conflict notifications
                  if (kDebugMode)
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.orange),
                      title: Text('Test Session Conflict Notification'),
                      subtitle: Text('Show session conflict notification for testing'),
                      onTap: () {
                        Navigator.pop(context);
                        SessionNotificationService.showTestNotification(context);
                      },
                    ),
                  // Debug option for testing full session conflict flow
                  if (kDebugMode)
                    ListTile(
                      leading: Icon(Icons.security, color: Colors.red),
                      title: Text('Test Full Session Conflict Flow'),
                      subtitle: Text('Simulate session conflict with immediate logout'),
                      onTap: () {
                        Navigator.pop(context);
                        _testFullSessionConflictFlow(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
