import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String code;
  
  const ResetPasswordScreen({Key? key, required this.code}) : super(key: key);
  
  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _email;
  List<String> _validationErrors = [];
  bool _showValidationErrors = false;
  
  // Animation controller for card press effect
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _verifyResetCode();
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
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
    
    // Required criteria - all of these must be met
    if (!hasMinLength) {
      _validationErrors.add('At least 8 characters');
    }
    
    // Must have at least one uppercase letter
    if (!hasUppercase) {
      _validationErrors.add('Must include at least one uppercase letter');
    }
    
    // Must have at least one lowercase letter
    if (!hasLowercase) {
      _validationErrors.add('Must include at least one lowercase letter');
    }
    
    // Must have at least one number
    if (!hasNumber) {
      _validationErrors.add('Must include at least one number');
    }
    
    // Must have at least one special character
    if (!hasSpecialChar) {
      _validationErrors.add('Must include at least one special character');
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
      setState(() {
        _showValidationErrors = true; // Show validation errors visually
      });
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
        title: Text(
          'Change Your Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: GestureDetector(
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) => _animationController.reverse(),
          onTapCancel: () => _animationController.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Card(
              elevation: 3,
              shadowColor: Colors.black.withOpacity(0.3),
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50.withOpacity(0.5)],
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
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.7)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/forgot-password');
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.indigo.shade700,
                              elevation: 0,
                              minimumSize: Size(double.infinity, 50),
                            ),
                            child: Text(
                              'Request New Reset Link',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildResetForm() {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: GestureDetector(
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) => _animationController.reverse(),
          onTapCancel: () => _animationController.reverse(),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Card(
              elevation: 3,
              shadowColor: Colors.black.withOpacity(0.3),
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Colors.grey.shade50.withOpacity(0.5)],
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
                child: Padding(
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
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: _showValidationErrors && !_validatePassword(_passwordController.text)
                                ? OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                            focusedBorder: _showValidationErrors && !_validatePassword(_passwordController.text)
                                ? OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.indigo.shade400),
                                  ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: _showValidationErrors && !_validatePassword(_passwordController.text) 
                                  ? Colors.red 
                                  : Colors.grey.shade600,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                              _showValidationErrors = false; // Reset validation error highlighting
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Re-enter new password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: _showValidationErrors && (_passwordController.text != _confirmPasswordController.text)
                                ? OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                            focusedBorder: _showValidationErrors && (_passwordController.text != _confirmPasswordController.text)
                                ? OutlineInputBorder(
                                    borderSide: BorderSide(color: Colors.red, width: 2.0),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.indigo.shade400),
                                  ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: _showValidationErrors && (_passwordController.text != _confirmPasswordController.text)
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey.shade600,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                          onChanged: (value) {
                            setState(() {
                              _showValidationErrors = false; // Reset validation error highlighting
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        if (_validationErrors.isNotEmpty || _passwordController.text.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _showValidationErrors && !_validatePassword(_passwordController.text)
                                    ? Colors.red 
                                    : Colors.grey.shade300,
                                width: _showValidationErrors && !_validatePassword(_passwordController.text) ? 2.0 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: _showValidationErrors && !_validatePassword(_passwordController.text)
                                  ? Colors.red.shade50
                                  : Colors.grey.shade50.withOpacity(0.3),
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
                                  'All of the following criteria are required:', 
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
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Colors.indigo.shade50.withOpacity(0.7)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.indigo.shade700,
                                elevation: 0,
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.indigo.shade700,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Text(
                                      'Reset password',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildValidationItem(String text, bool isValid) {
    final bool highlightError = _showValidationErrors && !isValid;
    
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : (highlightError ? Icons.cancel : Icons.circle_outlined),
          color: isValid ? Colors.green.shade600 : (highlightError ? Colors.red.shade600 : Colors.grey),
          size: 16,
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: highlightError ? Colors.red.shade800 : (isValid ? Colors.grey.shade800 : Colors.grey.shade700),
            fontWeight: highlightError ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
  
  Widget _buildValidationSubItem(String text, bool isValid) {
    final bool highlightError = _showValidationErrors && !isValid;
    
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : (highlightError ? Icons.cancel : Icons.circle_outlined),
          color: isValid ? Colors.green.shade600 : (highlightError ? Colors.red.shade600 : Colors.grey),
          size: 16,
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: highlightError ? Colors.red.shade800 : (isValid ? Colors.grey.shade800 : Colors.grey.shade700),
            fontWeight: highlightError ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }
}
