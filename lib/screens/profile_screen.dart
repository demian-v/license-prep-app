import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../providers/progress_provider.dart';
import '../examples/api_switcher_example.dart';
import '../examples/function_name_mapping_example.dart';
import '../services/email_sync_service.dart';
import '../models/user.dart';
import 'personal_info_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Force sync the email in Firestore when the profile screen loads
    _syncEmailOnScreenLoad();
    
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
                final updatedUser = User(
                  id: user.id,
                  name: savedName,
                  email: user.email,
                  language: user.language,
                  state: user.state,
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
                final updatedUser = User(
                  id: user.id,
                  name: firestoreName.toString(),
                  email: user.email,
                  language: user.language,
                  state: user.state,
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
                  final updatedUser = User(
                    id: user.id,
                    name: user.name,
                    email: user.email,
                    language: user.language,
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

  // This method forces a sync of the email in Firestore when the profile screen loads
  void _syncEmailOnScreenLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Force sync the email in Firebase with Firestore
      await emailSyncService.syncEmailWithFirestore();
      
      // Check for and handle email verification with context for dialog display
      bool emailChanged = await emailSyncService.handlePostEmailVerification(context);
      
      // If email wasn't changed (no verification happened), just update the UI
      if (!emailChanged && mounted) {
        // Update Firestore with the current auth email
        await emailSyncService.updateFirestoreEmail();

        // Also update the AuthProvider's user object with correct email
        await emailSyncService.updateAuthProviderEmail(context);
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
            'select_language': 'Seleccionar idioma:',
            'state': 'Estado:',
            'subscription': 'Suscripción:',
            'active': 'Activa',
            'try_premium': 'Prueba premium',
            'reset_statistics': 'Restablecer estadísticas',
            'reset_desc': 'Devolver todo como estaba antes',
            'logout': 'Cerrar sesión',
            'reset_stats_title': 'Restablecer estadísticas',
            'reset_stats_confirm': '¿Estás seguro de que quieres restablecer todas tus estadísticas? Esto borrará todo tu progreso en pruebas y temas. Esta acción no se puede deshacer.',
            'cancel': 'Cancelar',
            'reset': 'Restablecer',
            'stats_reset_success': 'Estadísticas restablecidas con éxito',
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
            'reset_statistics': 'Скинути статистику',
            'reset_desc': 'Повернути все як було раніше',
            'logout': 'Вийти з акаунта',
            'reset_stats_title': 'Скинути статистику',
            'reset_stats_confirm': 'Ви впевнені, що хочете скинути всю вашу статистику? Це видалить весь ваш прогрес у тестах та темах. Цю дію неможливо скасувати.',
            'cancel': 'Скасувати',
            'reset': 'Скинути',
            'stats_reset_success': 'Статистику скинуто успішно',
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
            'reset_statistics': 'Сбросить статистику',
            'reset_desc': 'Вернуть всё как было раньше',
            'logout': 'Выйти из аккаунта',
            'reset_stats_title': 'Сбросить статистику',
            'reset_stats_confirm': 'Вы уверены, что хотите сбросить всю вашу статистику? Это удалит весь ваш прогресс в тестах и темах. Это действие нельзя отменить.',
            'cancel': 'Отмена',
            'reset': 'Сбросить',
            'stats_reset_success': 'Статистика сброшена успешно',
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
            'reset_statistics': 'Zresetuj statystyki',
            'reset_desc': 'Przywróć wszystko do pierwotnego stanu',
            'logout': 'Wyloguj się',
            'reset_stats_title': 'Zresetuj statystyki',
            'reset_stats_confirm': 'Czy na pewno chcesz zresetować wszystkie swoje statystyki? Spowoduje to usunięcie całego postępu w testach i tematach. Tej akcji nie można cofnąć.',
            'cancel': 'Anuluj',
            'reset': 'Zresetuj',
            'stats_reset_success': 'Statystyki zresetowane pomyślnie',
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
            'reset_statistics': 'Reset statistics',
            'reset_desc': 'Return everything as it was before',
            'logout': 'Log out',
            'reset_stats_title': 'Reset Statistics',
            'reset_stats_confirm': 'Are you sure you want to reset all your statistics? This will delete all your progress in tests and topics. This action cannot be undone.',
            'cancel': 'Cancel',
            'reset': 'Reset',
            'stats_reset_success': 'Statistics reset successfully',
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
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.orange,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                                color: Colors.green,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildMenuCard(
                    _translate('support', languageProvider),
                    _translate('support_desc', languageProvider),
                    Icons.help_outline,
                    Colors.green[50]!,
                    Colors.green,
                    () {},
                    languageProvider,
                  ),
                  SizedBox(height: 16),
                  _buildMenuCard(
                    _translate('select_language', languageProvider),
                    languageProvider.languageName,
                    Icons.language,
                    Colors.teal[50]!,
                    Colors.teal,
                    () {
                      _showLanguageSelector(context, languageProvider);
                    },
                    languageProvider,
                  ),
                  SizedBox(height: 16),
                  _buildMenuCard(
                    _translate('state', languageProvider),
                    _isLoadingState 
                      ? "Loading..." // Show loading indicator while fetching state
                      : ((authProvider.user?.state?.isNotEmpty == true) 
                          ? authProvider.user!.state! 
                          : _translate('Not selected', languageProvider)),
                    Icons.location_on,
                    Colors.blue[50]!,
                    Colors.blue,
                    () {
                      // Force Firestore refresh and wait for it to complete before showing selector
                      setState(() { _isLoadingState = true; });
                      _ensureStateDataLoaded().then((_) {
                        _showStateSelector(context, languageProvider);
                      });
                    },
                    languageProvider,
                  ),
                  SizedBox(height: 16),
                  _buildMenuCard(
                    _translate('subscription', languageProvider),
                    subscriptionProvider.isSubscriptionActive 
                        ? _translate('active', languageProvider) 
                        : _translate('try_premium', languageProvider),
                    Icons.workspace_premium,
                    Colors.amber[50]!,
                    Colors.amber,
                    () {
                      Navigator.pushNamed(context, '/subscription');
                    },
                    languageProvider,
                  ),
                  SizedBox(height: 16),
                  _buildMenuCard(
                    _translate('reset_statistics', languageProvider),
                    _translate('reset_desc', languageProvider),
                    Icons.restart_alt,
                    Colors.red[50]!,
                    Colors.red,
                    () {
                      _showResetProgressConfirmation(context, languageProvider);
                    },
                    languageProvider,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      await authProvider.logout();
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    },
                    child: Text(_translate('logout', languageProvider)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
          ),
        );
      }
    );
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    VoidCallback onTap,
    LanguageProvider languageProvider,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: title == _translate('select_language', languageProvider) ? Colors.green : Colors.grey[600],
                        fontSize: 14,
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

  void _showLanguageSelector(BuildContext context, LanguageProvider languageProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Map language codes to display names
    final Map<String, String> languageNames = {
      'en': 'English',
      'es': 'Spanish',
      'uk': 'Українська',
      'pl': 'Polish',
      'ru': 'Russian',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate('select_lang_dialog', languageProvider)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', 'en', languageProvider, authProvider),
            _buildLanguageOption(context, 'Spanish', 'es', languageProvider, authProvider),
            _buildLanguageOption(context, 'Українська', 'uk', languageProvider, authProvider),
            _buildLanguageOption(context, 'Polish', 'pl', languageProvider, authProvider),
            _buildLanguageOption(context, 'Russian', 'ru', languageProvider, authProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String language, String code, 
      LanguageProvider provider, AuthProvider authProvider) {
    return ListTile(
      title: Text(language),
      trailing: provider.language == code ? Icon(Icons.check, color: Colors.green) : null,
      onTap: () async {
        // Update both providers, just like in the language_selection_screen
        await provider.setLanguage(code);
        await authProvider.updateUserLanguage(code);
        Navigator.pop(context);
        
        // Visual feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_translate('language_changed', provider)} $language'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  void _showStateSelector(BuildContext context, LanguageProvider languageProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentState = authProvider.user?.state;
    
    // List of all US states
    final List<String> allStates = [
      'ALABAMA',
      'ALASKA',
      'ARIZONA',
      'ARKANSAS',
      'CALIFORNIA',
      'COLORADO',
      'CONNECTICUT',
      'DELAWARE',
      'DISTRICT OF COLUMBIA',
      'FLORIDA',
      'GEORGIA',
      'HAWAII',
      'IDAHO',
      'ILLINOIS',
      'INDIANA',
      'IOWA',
      'KANSAS',
      'KENTUCKY',
      'LOUISIANA',
      'MAINE',
      'MARYLAND',
      'MASSACHUSETTS',
      'MICHIGAN',
      'MINNESOTA',
      'MISSISSIPPI',
      'MISSOURI',
      'MONTANA',
      'NEBRASKA',
      'NEVADA',
      'NEW HAMPSHIRE',
      'NEW JERSEY',
      'NEW MEXICO',
      'NEW YORK',
      'NORTH CAROLINA',
      'NORTH DAKOTA',
      'OHIO',
      'OKLAHOMA',
      'OREGON',
      'PENNSYLVANIA',
      'RHODE ISLAND',
      'SOUTH CAROLINA',
      'SOUTH DAKOTA',
      'TENNESSEE',
      'TEXAS',
      'UTAH',
      'VERMONT',
      'VIRGINIA',
      'WASHINGTON',
      'WEST VIRGINIA',
      'WISCONSIN',
      'WYOMING',
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate('select_state_dialog', languageProvider)),
        content: Container(
          width: double.maxFinite,
          height: 400, // Fixed height for scrollable content
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allStates.length,
            itemBuilder: (context, index) {
              final state = allStates[index];
              final isSelected = state == currentState;
              
              return ListTile(
                title: Text(state),
                trailing: isSelected ? Icon(Icons.check, color: Colors.green) : null,
                onTap: () async {
                  // Update state in auth provider
                  await authProvider.updateUserState(state);
                  
                  // Force immediate UI update
                  if (mounted) {
                    setState(() {
                      // This will trigger an immediate UI rebuild
                      _isLoadingState = false;
                    });
                  }
                  
                  Navigator.pop(context);
                  
                  // Visual feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_translate('state_changed', languageProvider)} $state'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
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
                  ListTile(
                    leading: Icon(Icons.api),
                    title: Text(_translate('api_switcher', languageProvider)),
                    subtitle: Text(_translate('api_switcher_desc', languageProvider)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ApiSwitcherExample(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.functions),
                    title: Text(_translate('function_mapping', languageProvider)),
                    subtitle: Text(_translate('function_mapping_desc', languageProvider)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FunctionNameMappingExample(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.settings_applications),
                    title: Text(_translate('app_settings_reset', languageProvider)),
                    subtitle: Text(_translate('app_settings_reset_desc', languageProvider)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings/reset');
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

  void _showResetProgressConfirmation(BuildContext context, LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_translate('reset_stats_title', languageProvider)),
        content: Text(_translate('reset_stats_confirm', languageProvider)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(_translate('cancel', languageProvider)),
          ),
          TextButton(
            onPressed: () async {
              final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
              await progressProvider.resetProgress();
              Navigator.pop(context);
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_translate('stats_reset_success', languageProvider)),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(_translate('reset', languageProvider)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
