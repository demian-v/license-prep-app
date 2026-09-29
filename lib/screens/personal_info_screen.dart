import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/email_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:async';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart';

class PersonalInfoScreen extends StatefulWidget {
  @override
  _PersonalInfoScreenState createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _showPasswordField = false;
  String? _initialName;
  String? _initialEmail;
  String? _passwordError; // Added variable to track password error
  
  // Auth state listener and timeout timer
  StreamSubscription<firebase_auth.User?>? _authStateSubscription;
  Timer? _loadingTimeoutTimer;

  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    // Create a direct translation based on the selected language
    try {
      // Get the appropriate language based on the language provider
      switch (languageProvider.language) {
        case 'es':
          return {
            'personal_info': 'Información personal',
            'change_personal_data': 'Cambiar datos personales',
            'delete_account_section': 'Eliminación de cuenta',
            'name': 'Nombre',
            'email': 'Correo electrónico',
            'password': 'Contraseña',
            'password_required': 'La contraseña es obligatoria',
            'wrong_password': 'Contraseña incorrecta. Verifique su contraseña e inténtelo de nuevo.',
            'password_needed_for_email': 'Se requiere su contraseña para cambiar su dirección de correo electrónico',
            'delete_account': 'Eliminar cuenta',
            'delete_account_desc': 'La eliminación será permanente, sin posibilidad de recuperar la cuenta',
            'save': 'Guardar',
            'name_required': 'El nombre es obligatorio',
            'invalid_email': 'El correo electrónico no es válido',
            'email_required': 'El correo electrónico es obligatorio',
            'changes_saved': 'Cambios guardados correctamente',
            'delete_confirmation_title': 'Confirmar eliminación',
            'delete_confirmation_message': '¿Estás seguro de que quieres eliminar tu cuenta? Esta acción es permanente y no se puede deshacer.',
            'cancel': 'Cancelar',
            'confirm': 'Confirmar',
          }[key] ?? _translateFromL10n(key);
        case 'uk':
          return {
            'personal_info': 'Персональна інформація',
            'change_personal_data': 'Змінити особисті дані',
            'delete_account_section': 'Видалення аккаунту',
            'name': 'Ім\'я',
            'email': 'E-mail',
            'password': 'Пароль',
            'password_required': 'Пароль обов\'язковий',
            'wrong_password': 'Невірний пароль. Перевірте пароль та спробуйте ще раз.',
            'password_needed_for_email': 'Для зміни електронної адреси потрібен ваш пароль',
            'delete_account': 'Видалити аккаунт',
            'delete_account_desc': 'Видалення буде остаточним, без можливості відновити аккаунт',
            'save': 'Зберегти',
            'name_required': 'Ім\'я обов\'язкове',
            'invalid_email': 'Неправильний формат email',
            'email_required': 'Email обов\'язковий',
            'changes_saved': 'Зміни збережено успішно',
            'delete_confirmation_title': 'Підтвердження видалення',
            'delete_confirmation_message': 'Ви впевнені, що хочете видалити свій аккаунт? Ця дія незворотна і не може бути скасована.',
            'cancel': 'Скасувати',
            'confirm': 'Підтвердити',
          }[key] ?? _translateFromL10n(key);
        case 'ru':
          return {
            'personal_info': 'Персональная информация',
            'change_personal_data': 'Изменить личные данные',
            'delete_account_section': 'Удаление аккаунта',
            'name': 'Имя',
            'email': 'Электронная почта',
            'password': 'Пароль',
            'password_required': 'Пароль обязателен',
            'wrong_password': 'Неверный пароль. Проверьте пароль и попробуйте еще раз.',
            'password_needed_for_email': 'Для изменения адреса электронной почты требуется ваш пароль',
            'delete_account': 'Удалить аккаунт',
            'delete_account_desc': 'Удаление будет окончательным, без возможности восстановить аккаунт',
            'save': 'Сохранить',
            'name_required': 'Имя обязательно',
            'invalid_email': 'Неверный формат электронной почты',
            'email_required': 'Электронная почта обязательна',
            'changes_saved': 'Изменения успешно сохранены',
            'delete_confirmation_title': 'Подтверждение удаления',
            'delete_confirmation_message': 'Вы уверены, что хотите удалить свою учетную запись? Это действие нельзя отменить.',
            'cancel': 'Отмена',
            'confirm': 'Подтвердить',
          }[key] ?? _translateFromL10n(key);
        case 'pl':
          return {
            'personal_info': 'Informacje osobiste',
            'change_personal_data': 'Zmień dane osobowe',
            'delete_account_section': 'Usuwanie konta',
            'name': 'Imię i nazwisko',
            'email': 'E-mail',
            'password': 'Hasło',
            'password_required': 'Hasło jest wymagane',
            'wrong_password': 'Nieprawidłowe hasło. Sprawdź hasło i spróbuj ponownie.',
            'password_needed_for_email': 'Twoje hasło jest wymagane do zmiany adresu e-mail',
            'delete_account': 'Usuń konto',
            'delete_account_desc': 'Usunięcie będzie trwałe, bez możliwości odzyskania konta',
            'save': 'Zapisz',
            'name_required': 'Imię jest wymagane',
            'invalid_email': 'Nieprawidłowy format e-mail',
            'email_required': 'E-mail jest wymagany',
            'changes_saved': 'Zmiany zapisane pomyślnie',
            'delete_confirmation_title': 'Potwierdzenie usunięcia',
            'delete_confirmation_message': 'Czy na pewno chcesz usunąć swoje konto? Ta akcja jest trwała i nie może zostać cofnięta.',
            'cancel': 'Anuluj',
            'confirm': 'Potwierdź',
          }[key] ?? _translateFromL10n(key);
        case 'en':
        default:
          return {
            'personal_info': 'Personal Information',
            'change_personal_data': 'Change personal data',
            'delete_account_section': 'Account Deletion',
            'name': 'Name',
            'email': 'Email',
            'password': 'Password',
            'password_required': 'Password is required',
            'wrong_password': 'Incorrect password. Please check your password and try again.',
            'password_needed_for_email': 'Your password is required to change your email address',
            'delete_account': 'Delete account',
            'delete_account_desc': 'Deletion will be permanent, without the possibility to restore the account',
            'save': 'Save',
            'name_required': 'Name is required',
            'invalid_email': 'Invalid email format',
            'email_required': 'Email is required',
            'changes_saved': 'Changes saved successfully',
            'delete_confirmation_title': 'Confirm Deletion',
            'delete_confirmation_message': 'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
            'cancel': 'Cancel',
            'confirm': 'Confirm',
          }[key] ?? _translateFromL10n(key);
      }
    } catch (e) {
      print('🚨 [PERSONAL INFO SCREEN] Error getting translation: $e');
      // Default fallback
      return _translateFromL10n(key);
    }
  }

  // Last resort for keys the inline maps above do not carry.
  //
  // The maps cannot simply be replaced by the l10n files: they hold 16 keys
  // that lib/localization/l10n/*.json does not define. But the reverse gap
  // exists too — `delete_subscription_warning` lives only in the JSON — and
  // the old `?? key` returned the raw key instead of looking there, so the
  // account-deletion dialog showed `delete_subscription_warning` verbatim.
  // Consulting the JSON here closes that gap for every key, not just this one.
  String _translateFromL10n(String key) {
    try {
      // translate() already falls back to returning the key itself.
      return AppLocalizations.of(context).translate(key);
    } catch (e) {
      return key;
    }
  }

  // Clear password error when text changes
  void _setupPasswordListener() {
    _passwordController.addListener(() {
      if (_passwordError != null) {
        setState(() {
          _passwordError = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    
    // The looping title pulse and the delayed entrance controllers were
    // replaced by a one-shot StaggerIn (2026-09-26).
    
    // Initialize with current user data
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _initialName = user?.name ?? '';
    _initialEmail = user?.email ?? '';
    _nameController = TextEditingController(text: _initialName);
    _emailController = TextEditingController(text: _initialEmail);
    _passwordController = TextEditingController();
    
    // Add listeners to controllers
    _nameController.addListener(() {
      setState(() {}); // Trigger rebuild to update save button state
    });
    _emailController.addListener(() {
      setState(() {}); // Trigger rebuild to update save button state
    });
    
    // Setup password error clearing
    _setupPasswordListener();
    
    // Setup auth state listener for account deletion
    _setupAuthStateListener();
    
    // Handle post-email verification when screen initializes
    _handlePossibleEmailVerification();
  }
  
  // Special method to check if email was verified and sync it
  Future<void> _handlePossibleEmailVerification() async {
    // Add a slight delay to let the screen initialize
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Force reload the user to get the latest email
        final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser.reload();
          final authEmail = currentUser.email;
          
          // Get the latest email from Auth
          if (authEmail != null) {
            // Check if email changed
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authEmail != authProvider.user?.email) {
              print('📧 PersonalInfoScreen: Detected email change: ${authProvider.user?.email} -> $authEmail');
              
              // Use our new method to update the app state with verified email
              await authProvider.applyVerifiedEmail();
              
              // Update the text field with the new email
              setState(() {
                _emailController.text = authEmail;
              });
              
              // Show success message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Email successfully changed to $authEmail'),
                    backgroundColor: AppColors.guide,
                  ),
                );
              }
            } else {
              print('ℹ️ PersonalInfoScreen: Email already up to date: $authEmail');
            }
          }
        }
      } catch (e) {
        print('❌ Error handling email verification in PersonalInfoScreen: $e');
      }
    });
  }

  // Setup auth state listener for account deletion
  void _setupAuthStateListener() {
    _authStateSubscription = firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen((firebase_auth.User? user) {
      if (user == null && mounted) {
        // User has been deleted/logged out - navigate to login
        debugPrint('🔄 Auth state changed: user is null, navigating to login');
        _navigateToLoginSafely();
      }
    });
  }

  // Safe navigation method with multiple fallbacks
  void _navigateToLoginSafely() {
    if (!mounted) return;
    
    // Reset loading state first
    if (_isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
    
    // Cancel any pending timeout timer
    _loadingTimeoutTimer?.cancel();
    
    // Try multiple navigation approaches
    try {
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/login', 
        (route) => false,
      );
      debugPrint('✅ Successfully navigated to login via rootNavigator');
    } catch (e) {
      debugPrint('⚠️ Root navigator failed, trying regular navigator: $e');
      try {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/login', 
          (route) => false,
        );
        debugPrint('✅ Successfully navigated to login via regular navigator');
      } catch (e2) {
        debugPrint('❌ All navigation attempts failed: $e2');
        // At this point, the auth state change should handle navigation
      }
    }
  }

  // Loading timeout mechanism
  void _startLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = Timer(Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        debugPrint('⏰ Loading timeout reached, resetting state');
        setState(() {
          _isLoading = false;
        });
        
        // Show user feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account deletion completed. Please log in again.'),
            backgroundColor: AppColors.guide,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Try to navigate
        _navigateToLoginSafely();
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _loadingTimeoutTimer?.cancel();
    _nameController.removeListener(() { setState(() {}); });
    _emailController.removeListener(() { setState(() {}); });
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  // Override didChangeDependencies to catch when screen is shown again
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This will be called when the screen comes back into view
    _handlePossibleEmailVerification();
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegExp.hasMatch(email);
  }

  // Save changes
  Future<void> _saveChanges(BuildContext context, LanguageProvider languageProvider) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _passwordError = null; // Clear any previous password errors
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Update name if it changed
        if (authProvider.user!.name != _nameController.text) {
          await authProvider.updateProfile(_nameController.text);
        }
        
        // Update email if it changed
        if (authProvider.user!.email != _emailController.text) {
          try {
            // Check if we need to show password field
            if (!_showPasswordField) {
              setState(() {
                _showPasswordField = true;
                _isLoading = false;
              });
              return; // Exit method to let user enter password
            }
            
            // Now we have the password, update email securely
            await authProvider.updateUserEmail(
              _emailController.text,
              password: _passwordController.text
            );
            
            // Reset password field
            _passwordController.clear();
            _showPasswordField = false;
          } catch (e) {
            print('❌ Error updating email: $e');
            
            // Check for authentication errors and set password error
            String errorMessage = e.toString();
            print('📋 Personal info error caught: $errorMessage');
            if (errorMessage.contains('INVALID_LOGIN_CREDENTIALS') || 
                errorMessage.contains('wrong-password') ||
                errorMessage.contains('Authentication failed') ||
                errorMessage.contains('auth/invalid-credential') ||
                errorMessage.contains('Reauthentication failed')) {
              
              // Use the correct translation for wrong password
              String errorText = _translate('wrong_password', languageProvider);
              
              setState(() {
                _passwordError = errorText;
                _isLoading = false;
              });
              
              // Ensure the error is visible by forcing a UI refresh
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() {});
              });
            } else {
              // For other errors, show in SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating email: $e'),
                  backgroundColor: AppColors.stop,
                ),
              );
              setState(() {
                _isLoading = false;
              });
            }
            return;
          }
        }
        
        // Check if email was actually changed before showing success message
        if (_emailController.text != _initialEmail) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Verification email sent. Please check your inbox to confirm the new email address.'
              ),
              backgroundColor: AppColors.guide,
              duration: Duration(seconds: 5),  // Show longer for verification message
            ),
          );
          
          // Go back to profile screen
          Navigator.pop(context);
        } else {
          // Only name was changed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_translate('changes_saved', languageProvider)),
              backgroundColor: AppColors.guide,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Go back to profile screen
          Navigator.pop(context);
        }
        
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.stop,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Delete account confirmation
  void _showDeleteConfirmation(BuildContext context, LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Bento (2026-09-26): a red disc says "irreversible" before the text
        // does; the actions are two full-width pills — the destructive one a
        // field pill with a red label, the safe way out the dark ink pill.
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.stopSurface,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(SolarIcons.dangerTriangleLinear, color: AppColors.stop, size: 28),
        ),
        // One line; a long translation shrinks rather than wraps.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
          _translate('delete_confirmation_title', languageProvider),
          maxLines: 1,
          style: AppTypography.title.copyWith(
            fontSize: 22,
            height: 28 / 22,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          0,
          AppSpacing.x6,
          AppSpacing.x6,
        ),
        // Risk #14 — deleting the account does NOT cancel an App Store or
        // Google Play subscription; only the store can do that. Saying nothing
        // meant people kept being charged for an account that no longer
        // existed. Warned BEFORE the irreversible action, not after it.
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_translate('delete_confirmation_message', languageProvider)),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warnSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(SolarIcons.infoCircleLinear, size: 18, color: AppColors.warn),
                  SizedBox(width: 8),
                  Expanded(
                    // Ink, not amber: amber measures 3.9:1 on its surface,
                    // too low for small text.
                    child: Text(
                      _translate('delete_subscription_warning', languageProvider),
                      style: AppTypography.caption.copyWith(
                        fontSize: 13,
                        height: 18 / 13,
                        color: AppColors.ink,
                        fontVariations: const [FontVariation('wght', 400)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.field,
              foregroundColor: AppColors.stop,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: AppTypography.label.copyWith(
                fontSize: 16,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              setState(() {
                _isLoading = true;
              });
              
              // Start timeout timer
              _startLoadingTimeout();
              
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.deleteAccount();
                
                debugPrint('✅ Account deletion completed, auth state listener will handle navigation');
                
                // The auth state listener will handle navigation automatically
                // But add a small delay fallback just in case
                if (mounted) {
                  await Future.delayed(Duration(milliseconds: 500));
                  if (mounted && _isLoading) {
                    _navigateToLoginSafely();
                  }
                }
                
              } catch (e) {
                debugPrint('❌ Account deletion error in UI: $e');
                
                // Cancel timeout timer since we're handling the error
                _loadingTimeoutTimer?.cancel();
                
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.stop,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
            child: Text(
              _translate('confirm', languageProvider),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.onSignal,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: AppTypography.label.copyWith(
                fontSize: 16,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: Text(_translate('cancel', languageProvider)),
          ),
            ],
          ),
        ],
      ),
    );
  }

  // Add method to check if form was modified
  bool _isFormModified() {
    return _nameController.text != _initialName || 
           _emailController.text != _initialEmail;
  }

  // Helper method to get custom icon asset path based on field type
  String? _getEditProfileIconAsset(String fieldType) {
    switch (fieldType) {
      case 'name': return 'assets/images/edit_profile/1_name.png';
      case 'email': return 'assets/images/edit_profile/2_email.png';
      default: return null;
    }
  }

  /// A section as on Тесты: a 15/600 label on the page, then its content —
  /// either stacked tiles ([asCard] false) or one white card.
  Widget _buildEnhancedSectionCard({
    required String title,
    required List<Widget> children,
    required int sectionIndex,
    bool asCard = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x3),
          child: Text(
            title,
            style: AppTypography.label.copyWith(
              fontSize: 15,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
        ),
        if (asCard)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: AppColors.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          )
        else
          ...children,
      ],
    );
  }

  /// A note inside a section: a tinted panel with its icon — blue for
  /// information, red for the irreversible delete. Text stays ink-dark enough
  /// to read at 13.
  Widget _buildNote(IconData icon, String text, {required bool danger}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: danger ? AppColors.stopSurface : AppColors.signal50,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: danger ? AppColors.stop : AppColors.signal),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                height: 18 / 13,
                color: danger ? AppColors.stop : AppColors.ink,
                fontVariations: const [FontVariation('wght', 400)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        final sections = <Widget>[
          // Personal Data Section
          _buildEnhancedSectionCard(
            title: _translate('change_personal_data', languageProvider),
            sectionIndex: 0,
            children: [
              // Name field
              _buildFormField(
                context,
                _translate('name', languageProvider),
                SolarIcons.userRoundedLinear,
                AppColors.signal,
                _nameController,
                (value) {
                  if (value == null || value.isEmpty) {
                    return _translate('name_required', languageProvider);
                  }
                  return null;
                },
                fieldIndex: 0,
                showEditIcon: true,
                iconAsset: _getEditProfileIconAsset('name'),
              ),
              const SizedBox(height: AppSpacing.x3),
              
              // Email field
              _buildFormField(
                context,
                _translate('email', languageProvider),
                SolarIcons.letterLinear,
                AppColors.signal,
                _emailController,
                (value) {
                  if (value == null || value.isEmpty) {
                    return _translate('email_required', languageProvider);
                  }
                  if (!_isValidEmail(value)) {
                    return _translate('invalid_email', languageProvider);
                  }
                  return null;
                },
                fieldIndex: 1,
                showEditIcon: true,
                iconAsset: _getEditProfileIconAsset('email'),
              ),
              
              // Password field (conditional)
              if (_showPasswordField) ...[
                const SizedBox(height: AppSpacing.x3),
                _buildNote(
                  SolarIcons.infoCircleLinear,
                  _translate('password_needed_for_email', languageProvider),
                  danger: false,
                ),
                const SizedBox(height: AppSpacing.x3),
                _buildFormField(
                  context,
                  _translate('password', languageProvider),
                  SolarIcons.lockKeyholeMinimalisticLinear,
                  AppColors.signal,
                  _passwordController,
                  (value) {
                    if (value == null || value.isEmpty) {
                      return _translate('password_required', languageProvider);
                    }
                    return null;
                  },
                  isPassword: true,
                  errorText: _passwordError,
                  fieldIndex: 2,
                ),
              ],
            ],
          ),
          
          // Delete Account Section
          _buildEnhancedSectionCard(
            title: _translate('delete_account_section', languageProvider),
            sectionIndex: 1,
            asCard: true,
            children: [
              _buildNote(
                SolarIcons.dangerTriangleLinear,
                _translate('delete_account_desc', languageProvider),
                danger: true,
              ),
              const SizedBox(height: AppSpacing.x3),
              _buildDeleteButton(
                _translate('delete_account', languageProvider),
                () => _showDeleteConfirmation(context, languageProvider),
              ),
            ],
          ),
        ];

        return Scaffold(
          backgroundColor: AppColors.field,
          appBar: bentoHeadingAppBar(
            title: _translate('personal_info', languageProvider),
            onBack: () => Navigator.pop(context),
            actions: [
              if (_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.signal),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.x4 + AppSpacing.x1,
                          AppSpacing.x3,
                          AppSpacing.x4 + AppSpacing.x1,
                          AppSpacing.x4,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              for (var i = 0; i < sections.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(top: i > 0 ? AppSpacing.x8 : 0),
                                  // One-shot entrance, capped at AppMotion.base.
                                  child: StaggerIn(
                                    index: i,
                                    count: sections.length + 1,
                                    curve: BentoTokens.curve,
                                    child: sections[i],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom Save Button — the dark ink pill when there is
                    // something to save (owner, 2026-09-28), grey until then.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        AppSpacing.x2,
                        AppSpacing.x4,
                        AppSpacing.x4,
                      ),
                      child: StaggerIn(
                        index: sections.length,
                        count: sections.length + 1,
                        curve: BentoTokens.curve,
                        child: BentoActionButton(
                          text: _translate('save', languageProvider),
                          ink: true,
                          onTap: _isFormModified() 
                            ? () => _saveChanges(context, languageProvider)
                            : null,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }

  /// «Удалить аккаунт»: a field-grey pill with a red label — red because it is
  /// destructive; the confirmation dialog comes first.
  Widget _buildDeleteButton(String text, VoidCallback onTap) {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Material(
        color: AppColors.field,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                text,
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

  /// A field as its own white tile, as the Тесты and Профиль tiles: the
  /// labelled input, and the pen that says it can be edited. No 3D picture
  /// (owner, 2026-09-26: removed with Профиль's); [icon], [iconColor] and
  /// [iconAsset] are kept for callers but unused.
  Widget _buildFormField(
    BuildContext context,
    String label,
    IconData icon,
    Color iconColor,
    TextEditingController controller,
    String? Function(String?) validator,
    {bool isPassword = false, String? errorText, int fieldIndex = 0, bool showEditIcon = false, String? iconAsset}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            boxShadow: AppColors.shadowCard,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: label,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    suffixIcon: showEditIcon
                        ? const Icon(
                            SolarIcons.penLinear,
                            size: 18,
                            color: AppColors.inkSecondary,
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    labelStyle: AppTypography.label.copyWith(
                      color: AppColors.inkSecondary,
                      fontVariations: const [FontVariation('wght', 400)],
                    ),
                    floatingLabelStyle: AppTypography.label.copyWith(
                      color: AppColors.inkSecondary,
                      fontVariations: const [FontVariation('wght', 400)],
                    ),
                  ),
                  obscureText: isPassword,
                  validator: validator,
                  style: AppTypography.body.copyWith(
                    fontSize: 17,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 500)],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Error text under the field
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x2),
            child: _buildNote(SolarIcons.dangerCircleLinear, errorText, danger: true),
          ),
      ],
    );
  }
}
