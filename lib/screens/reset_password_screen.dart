import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String code;
  
  const ResetPasswordScreen({Key? key, required this.code}) : super(key: key);
  
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _email;
  List<String> _validationErrors = [];
  
  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _verifyResetCode() async {
    try {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _email = await authProvider.verifyPasswordResetCode(widget.code);
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  bool _validatePassword(String password) {
    _validationErrors.clear();
    
    // Password validation rules
    bool hasMinLength = password.length >= 8;
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    
    int strengthCount = 0;
    if (hasLowercase) strengthCount++;
    if (hasUppercase) strengthCount++;
    if (hasNumber) strengthCount++;
    if (hasSpecialChar) strengthCount++;
    
    if (!hasMinLength) {
      _validationErrors.add('At least 8 characters');
    }
    
    if (strengthCount < 3) {
      _validationErrors.add('At least 3 of: lowercase letters, uppercase letters, numbers, special characters');
    }
    
    return _validationErrors.isEmpty;
  }
  
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    
    if (!_validatePassword(_passwordController.text)) {
      setState(() {}); // Refresh to show validation errors
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.confirmPasswordReset(widget.code, _passwordController.text);
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/reset-success');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Your Password'),
      ),
      body: SafeArea(
        child: _isLoading && _email == null
            ? Center(child: CircularProgressIndicator())
            : _errorMessage != null && _email == null
                ? _buildErrorWidget()
                : _buildResetForm(),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            SizedBox(height: 16),
            Text(
              'Password Reset Link Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage ?? 'The password reset link is invalid or has expired.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/forgot-password');
              },
              child: Text('Request New Reset Link'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResetForm() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change Your Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Enter a new password below to change your password.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
                SizedBox(height: 16),
              ],
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  
                  _validatePassword(value);
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _validatePassword(value);
                  });
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Re-enter new password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              if (_validationErrors.isNotEmpty || _passwordController.text.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your password must contain:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      _buildValidationItem(
                        'At least 8 characters', 
                        _passwordController.text.length >= 8
                      ),
                      SizedBox(height: 8),
                      _buildValidationItem(
                        'At least 3 of the following:', 
                        true
                      ),
                      SizedBox(height: 4),
                      Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildValidationSubItem(
                              'Lower case letters (a-z)',
                              _passwordController.text.contains(RegExp(r'[a-z]'))
                            ),
                            SizedBox(height: 4),
                            _buildValidationSubItem(
                              'Upper case letters (A-Z)',
                              _passwordController.text.contains(RegExp(r'[A-Z]'))
                            ),
                            SizedBox(height: 4),
                            _buildValidationSubItem(
                              'Numbers (0-9)',
                              _passwordController.text.contains(RegExp(r'[0-9]'))
                            ),
                            SizedBox(height: 4),
                            _buildValidationSubItem(
                              'Special characters (e.g. !@#\$%^&*)',
                              _passwordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : Text(
                        'Reset password',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildValidationItem(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.circle_outlined,
          color: isValid ? Colors.green : Colors.grey,
          size: 16,
        ),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }
  
  Widget _buildValidationSubItem(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.circle_outlined,
          color: isValid ? Colors.green : Colors.grey,
          size: 16,
        ),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
