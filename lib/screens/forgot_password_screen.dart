import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  // Animation controller for card press effect
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  // Analytics tracking variables
  DateTime? _formStartTime;
  bool _formStarted = false;
  bool _hasFormErrors = false;
  String? _formErrors;
  
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
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Analytics tracking methods
  void _onFormStarted() {
    if (!_formStarted) {
      _formStarted = true;
      _formStartTime = DateTime.now();
      analyticsService.logPasswordResetFormStarted();
      debugPrint('📊 Analytics: password_reset_form_started logged');
    }
  }

  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('user-not-found')) {
      return 'user_not_found';
    } else if (errorMessage.contains('too-many-requests')) {
      return 'rate_limited';
    } else if (errorMessage.contains('network')) {
      return 'network_error';
    } else if (errorMessage.contains('invalid-email')) {
      return 'invalid_email';
    } else {
      return 'unknown_error';
    }
  }

  Future<void> _sendResetEmail() async {
    // Reset error tracking
    _hasFormErrors = false;
    _formErrors = null;
    
    if (!_formKey.currentState!.validate()) {
      // Track validation errors
      _hasFormErrors = true;
      _formErrors = 'validation_failed';
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final email = _emailController.text.trim();
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendPasswordResetEmail(email);
      
      // Track successful email request
      final timeSpent = _formStartTime != null 
          ? DateTime.now().difference(_formStartTime!).inSeconds 
          : null;
      final emailDomain = email.split('@').length > 1 ? email.split('@')[1] : null;
      
      analyticsService.logPasswordResetEmailRequested(
        emailDomain: emailDomain,
        timeSpentSeconds: timeSpent,
        hasFormErrors: _hasFormErrors,
        validationErrors: _formErrors,
      );
      debugPrint('📊 Analytics: password_reset_email_requested logged (time: ${timeSpent}s)');
      
      if (mounted) {
        Navigator.pushNamed(
          context, 
          '/reset-email-sent',
          arguments: {'email': email},
        );
      }
    } catch (e) {
      // Track failure
      analyticsService.logPasswordResetFailed(
        failureStage: 'email_request',
        errorType: _getErrorType(e.toString()),
        errorMessage: e.toString(),
      );
      debugPrint('📊 Analytics: password_reset_failed logged (stage: email_request)');
      
      if (mounted) {
        setState(() {
          // For security reasons, we don't show specific errors
          _errorMessage = 'An error occurred. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Forgot Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Forgot Your Password?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Enter your email address and we will send you instructions to reset your password.',
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
                                  controller: _emailController,
                                  onTap: _onFormStarted,
                                  onChanged: (value) => _onFormStarted(),
                                  decoration: InputDecoration(
                                    labelText: 'Email address',
                                    hintText: 'Enter your email',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.indigo.shade400),
                                    ),
                                    prefixIcon: Icon(Icons.email, color: Colors.grey.shade600),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    
                                    // Basic email validation
                                    final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                    if (!emailRegExp.hasMatch(value)) {
                                      return 'Please enter a valid email address';
                                    }
                                    
                                    return null;
                                  },
                                ),
                                SizedBox(height: 24),
                                Container(
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
                                    onPressed: _isLoading ? null : _sendResetEmail,
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
                                            'Continue',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Back to Log In',
                                    style: TextStyle(
                                      color: Colors.indigo.shade400,
                                      fontWeight: FontWeight.w500,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
