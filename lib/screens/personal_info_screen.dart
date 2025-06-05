import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../services/email_sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class PersonalInfoScreen extends StatefulWidget {
  @override
  _PersonalInfoScreenState createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _showPasswordField = false;
  String? _initialName;
  String? _initialEmail;
  String? _passwordError; // Added variable to track password error
  late AnimationController _titleAnimationController;
  late Animation<double> _titlePulseAnimation;

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
          }[key] ?? key;
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
          }[key] ?? key;
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
          }[key] ?? key;
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
          }[key] ?? key;
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
          }[key] ?? key;
      }
    } catch (e) {
      print('🚨 [PERSONAL INFO SCREEN] Error getting translation: $e');
      // Default fallback
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
    
    // Initialize animation controller
    _titleAnimationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    );
    
    _titlePulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Start the animation
    _titleAnimationController.repeat(reverse: true);
    
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
                    backgroundColor: Colors.green,
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

  @override
  void dispose() {
    _titleAnimationController.dispose();
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
                  backgroundColor: Colors.red,
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
              backgroundColor: Colors.green,
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
              backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
        title: Text(_translate('delete_confirmation_title', languageProvider)),
        content: Text(_translate('delete_confirmation_message', languageProvider)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
            },
            child: Text(_translate('cancel', languageProvider)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.deleteAccount();
                
                // Navigate to login screen
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: Text(
              _translate('confirm', languageProvider),
              style: TextStyle(color: Colors.red),
            ),
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

  // Helper methods for gradients and shadows
  LinearGradient _getSectionCardGradient(int sectionIndex) {
    Color startColor = Colors.white;
    Color endColor;
    
    switch (sectionIndex % 4) {
      case 0:
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 1:
        endColor = Colors.green.shade50.withOpacity(0.4);
        break;
      case 2:
        endColor = Colors.orange.shade50.withOpacity(0.4);
        break;
      case 3:
        endColor = Colors.purple.shade50.withOpacity(0.4);
        break;
      default:
        endColor = Colors.blue.shade50.withOpacity(0.4);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  LinearGradient _getFormFieldGradient(int fieldIndex) {
    Color startColor = Colors.white;
    Color endColor;
    
    switch (fieldIndex % 3) {
      case 0:
        endColor = Colors.green.shade50.withOpacity(0.3);
        break;
      case 1:
        endColor = Colors.blue.shade50.withOpacity(0.3);
        break;
      case 2:
        endColor = Colors.purple.shade50.withOpacity(0.3);
        break;
      default:
        endColor = Colors.blue.shade50.withOpacity(0.3);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  LinearGradient _getButtonGradient(String buttonType) {
    Color startColor = Colors.white;
    Color endColor;
    
    switch (buttonType) {
      case 'save':
        endColor = Colors.blue.shade50.withOpacity(0.4);
        break;
      case 'delete':
        endColor = Colors.red.shade50.withOpacity(0.4);
        break;
      default:
        endColor = Colors.grey.shade50.withOpacity(0.4);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }

  List<BoxShadow> _getStandardShadow() {
    return [
      BoxShadow(
        color: Colors.grey.withOpacity(0.2),
        spreadRadius: 0,
        blurRadius: 6,
        offset: Offset(0, 3),
      ),
    ];
  }

  Widget _buildEnhancedTitle(String title, LanguageProvider languageProvider) {
    return AnimatedBuilder(
      animation: _titlePulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _titlePulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue.shade50.withOpacity(0.6)],
                stops: [0.0, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: _getStandardShadow(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Colors.black,
                ),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedSectionCard({
    required String title,
    required List<Widget> children,
    required int sectionIndex,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getSectionCardGradient(sectionIndex),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _getStandardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEnhancedButton({
    required String text,
    required VoidCallback? onPressed,
    required String buttonType,
    bool isFullWidth = true,
    double height = 48,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null 
          ? _getButtonGradient(buttonType)
          : LinearGradient(
              colors: [Colors.grey.shade300, Colors.grey.shade200],
            ),
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: onPressed != null ? _getStandardShadow() : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(height / 2),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: onPressed != null ? Colors.black : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        // Define common title style
        final titleStyle = TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        );

        return Scaffold(
          appBar: AppBar(
            title: _buildEnhancedTitle(
              _translate('personal_info', languageProvider),
              languageProvider,
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              SizedBox(height: 8),
                              // Personal Data Section
                              _buildEnhancedSectionCard(
                                title: _translate('change_personal_data', languageProvider),
                                sectionIndex: 0,
                                children: [
                                  // Name field
                                  _buildFormField(
                                    context,
                                    _translate('name', languageProvider),
                                    Icons.person_outline,
                                    Colors.green,
                                    _nameController,
                                    (value) {
                                      if (value == null || value.isEmpty) {
                                        return _translate('name_required', languageProvider);
                                      }
                                      return null;
                                    },
                                    fieldIndex: 0,
                                  ),
                                  SizedBox(height: 16),
                                  
                                  // Email field
                                  _buildFormField(
                                    context,
                                    _translate('email', languageProvider),
                                    Icons.email_outlined,
                                    Colors.blue,
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
                                  ),
                                  
                                  // Password field (conditional)
                                  if (_showPasswordField) ...[
                                    SizedBox(height: 16),
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Colors.white, Colors.purple.shade50.withOpacity(0.2)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.purple.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: Colors.purple.shade700,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _translate('password_needed_for_email', languageProvider),
                                              style: TextStyle(
                                                color: Colors.purple.shade700,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    _buildFormField(
                                      context,
                                      _translate('password', languageProvider),
                                      Icons.lock_outline,
                                      Colors.purple,
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
                              
                              SizedBox(height: 16),
                              
                              // Delete Account Section
                              _buildEnhancedSectionCard(
                                title: _translate('delete_account_section', languageProvider),
                                sectionIndex: 1,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Colors.white, Colors.red.shade50.withOpacity(0.2)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.red.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_outlined,
                                          size: 16,
                                          color: Colors.red.shade700,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _translate('delete_account_desc', languageProvider),
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  _buildEnhancedButton(
                                    text: _translate('delete_account', languageProvider),
                                    onPressed: () => _showDeleteConfirmation(context, languageProvider),
                                    buttonType: 'delete',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom Save Button
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildEnhancedButton(
                        text: _translate('save', languageProvider),
                        onPressed: _isFormModified() 
                          ? () => _saveChanges(context, languageProvider)
                          : null,
                        buttonType: 'save',
                        height: 56,
                      ),
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }

  Widget _buildFormField(
    BuildContext context,
    String label,
    IconData icon,
    Color iconColor,
    TextEditingController controller,
    String? Function(String?) validator,
    {bool isPassword = false, String? errorText, int fieldIndex = 0}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: _getFormFieldGradient(fieldIndex),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _getStandardShadow(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [iconColor.withOpacity(0.1), iconColor.withOpacity(0.2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: label,
                      border: InputBorder.none,
                      labelStyle: TextStyle(
                        color: Colors.black.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    obscureText: isPassword,
                    validator: validator,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Enhanced error text display
        if (errorText != null)
          Container(
            margin: EdgeInsets.only(left: 16.0, top: 8.0, right: 16.0),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.red.shade50.withOpacity(0.3)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Colors.red.shade700,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorText,
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
