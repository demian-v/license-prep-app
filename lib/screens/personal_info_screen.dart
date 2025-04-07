import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';

class PersonalInfoScreen extends StatefulWidget {
  @override
  _PersonalInfoScreenState createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;

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
            'name': 'Nombre',
            'email': 'Correo electrónico',
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
            'name': 'Ім\'я',
            'email': 'E-mail',
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
            'name': 'Имя',
            'email': 'Электронная почта',
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
            'name': 'Imię i nazwisko',
            'email': 'E-mail',
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
            'name': 'Name',
            'email': 'Email',
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

  @override
  void initState() {
    super.initState();
    // Initialize with current user data
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
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
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Update name if it changed
        if (authProvider.user!.name != _nameController.text) {
          await authProvider.updateProfile(_nameController.text);
        }
        
        // Update email if it changed
        if (authProvider.user!.email != _emailController.text) {
          await authProvider.updateUserEmail(_emailController.text);
        }
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_translate('changes_saved', languageProvider)),
            backgroundColor: Colors.green,
          ),
        );
        
        // Go back to profile screen
        Navigator.pop(context);
        
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _translate('personal_info', languageProvider),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                )
              else
                TextButton(
                  onPressed: () => _saveChanges(context, languageProvider),
                  child: Text(
                    _translate('save', languageProvider),
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _translate('change_personal_data', languageProvider),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 24),
                          
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
                          ),
                          
                          SizedBox(height: 48),
                          
                          // Delete account button
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () => _showDeleteConfirmation(context, languageProvider),
                                child: Text(_translate('delete_account', languageProvider)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  minimumSize: Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _translate('delete_account_desc', languageProvider),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
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
                ),
                validator: validator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
