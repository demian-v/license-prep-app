import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import 'language_selection_screen.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Helper method to build app logo with fallback
  Widget _buildAppLogo() {
    return Container(
      height: 80,
      child: Image.asset(
        'assets/images/logo/logo.png',
        height: 80,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ SignupScreen: Failed to load logo asset: $error');
          return Text(
            'USA License Prep',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade400,
            ),
            textAlign: TextAlign.center,
          );
        },
      ),
    );
  }
  
  // Analytics tracking methods
  void _onFormStarted() {
    if (!_formStarted) {
      _formStarted = true;
      _formStartTime = DateTime.now();
      analyticsService.logSignupFormStarted();
      debugPrint('📊 Analytics: signup_form_started logged');
    }
  }
  
  void _onFormCompleted() {
    final timeSpent = _formStartTime != null 
        ? DateTime.now().difference(_formStartTime!).inSeconds 
        : null;
        
    analyticsService.logSignupFormCompleted(
      timeSpentSeconds: timeSpent,
      hasFormErrors: _hasFormErrors,
      validationErrors: _formErrors,
    );
    debugPrint('📊 Analytics: signup_form_completed logged (time: ${timeSpent}s)');
  }
  
  void _onAccountCreated(String? userId) {
    analyticsService.logUserAccountCreated(
      userId: userId,
      signupMethod: 'email',
      hasName: _nameController.text.trim().isNotEmpty,
      emailVerified: false, // Usually false at signup
    );
    debugPrint('📊 Analytics: user_account_created logged');
  }
  
  void _onTrialStarted(String? userId) {
    analyticsService.logSignupTrialStarted(
      userId: userId,
      signupMethod: 'email',
      trialType: '3_day_free_trial',
      trialDays: 3,
    );
    debugPrint('📊 Analytics: signup_trial_started logged');
  }
  
  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('email-already-in-use')) {
      return 'email_already_in_use';
    } else if (errorMessage.contains('weak-password')) {
      return 'weak_password';
    } else if (errorMessage.contains('invalid-email')) {
      return 'invalid_email';
    } else if (errorMessage.contains('createUserDocument')) {
      return 'document_creation_failed';
    } else {
      return 'unknown_error';
    }
  }

  /// Parse technical error messages into user-friendly messages
  String _parseErrorMessage(String errorMessage) {
    final errorLower = errorMessage.toLowerCase();
    
    if (errorLower.contains('email-already-in-use') || 
        errorLower.contains('email address is already in use')) {
      return 'This email is already in use. Please try a different email or log in.';
    } else if (errorLower.contains('weak-password') || 
               errorLower.contains('password is too weak')) {
      return 'Password is too weak. Please use a stronger password.';
    } else if (errorLower.contains('invalid-email')) {
      return 'Invalid email format. Please check your email address.';
    } else if (errorLower.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    } else {
      // Extract the meaningful part after "Registration failed:" if present
      if (errorMessage.contains('Registration failed:')) {
        return errorMessage.split('Registration failed:').last.trim();
      }
      return 'An error occurred during signup. Please try again.';
    }
  }

  Future<void> _signup() async {
    // Reset error tracking
    _hasFormErrors = false;
    _formErrors = null;
    
    if (!_formKey.currentState!.validate()) {
      // Track validation errors
      _hasFormErrors = true;
      _formErrors = 'validation_failed';
      return;
    }
    
    // Log form completed event
    _onFormCompleted();
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Use the AuthProvider instead of direct service
    try {
      debugPrint('🔍 [SignupScreen] Attempting signup with name=$name, email=$email');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.signup(name, email, password, context: context);
      
      if (success) {
        debugPrint('✅ [SignupScreen] Signup successful');
        
        // Get user ID from auth provider
        final currentUser = authProvider.user;
        final userId = currentUser?.id;
        
        // Log all the analytics events in sequence
        try {
          // Log standard GA4 signup event
          await analyticsService.logSignUp('email');
          
          // Log account created event
          _onAccountCreated(userId);
          
          // Log trial started event
          _onTrialStarted(userId);
          
          debugPrint('📊 Analytics: All signup events logged successfully');
        } catch (analyticsError) {
          debugPrint('⚠️ Analytics error (non-critical): $analyticsError');
        }
        
        // Verify that the user has the correct default values
        if (currentUser != null) {
          debugPrint('🔍 [SignupScreen] Verifying user default values:');
          debugPrint('    - Language: ${currentUser.language}');
          debugPrint('    - State: ${currentUser.state}');
          
          // Auto-fix if somehow the values are still incorrect
          if (currentUser.language != 'en' || currentUser.state != null) {
            debugPrint('⚠️ [SignupScreen] Incorrect default values detected, fixing before navigation');
            // This is an additional safeguard, but we already implemented fixes in multiple places
          }
        }
        
        if (mounted) {
          debugPrint('🔄 [SignupScreen] Navigating to language selection screen');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LanguageSelectionScreen(),
            ),
          );
        }
      } else {
        debugPrint('SignupScreen: Signup failed');
        
        // Log signup failure
        analyticsService.logSignupFailed(
          errorType: 'signup_failed',
          errorMessage: 'Unknown signup failure',
          signupMethod: 'email',
        );
        
        if (mounted) {
          setState(() {
            _errorMessage = 'Signup failed. Please check your information and try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('SignupScreen: Error during signup: $e');
      
      // Log signup failure with error details
      analyticsService.logSignupFailed(
        errorType: _getErrorType(e.toString()),
        errorMessage: e.toString(),
        signupMethod: 'email',
      );
      
      // Check if this is a document creation error (special handling)
      if (e.toString().contains('createUserDocument')) {
        // User was created in Firebase Auth but document creation failed
        // This is a non-critical error, so we can still proceed
        debugPrint('SignupScreen: User created but document creation failed: $e');
        
        // Still log the successful events since the user was created
        try {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final currentUser = authProvider.user;
          final userId = currentUser?.id;
          
          await analyticsService.logSignUp('email');
          _onAccountCreated(userId);
          _onTrialStarted(userId);
        } catch (analyticsError) {
          debugPrint('⚠️ Analytics error (non-critical): $analyticsError');
        }
        
        if (mounted) {
          // Show a toast or snackbar with warning
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account created but some data could not be saved. Some features may be limited.'))
          );
          
          // Still navigate to next screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LanguageSelectionScreen(),
            ),
          );
        }
      } else {
        // For other errors, parse and show user-friendly message
        if (mounted) {
          setState(() {
            _errorMessage = _parseErrorMessage(e.toString());
          });
        }
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 0),
                _buildAppLogo(),
                SizedBox(height: 20),
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
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
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
                                  controller: _nameController,
                                  onTap: _onFormStarted,
                                  onChanged: (value) => _onFormStarted(),
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
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
                                    prefixIcon: Icon(Icons.person, color: Colors.grey.shade600),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  onTap: _onFormStarted,
                                  onChanged: (value) => _onFormStarted(),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
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
                                    // Check for valid email format
                                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  onTap: _onFormStarted,
                                  onChanged: (value) => _onFormStarted(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
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
                                    prefixIcon: Icon(Icons.lock, color: Colors.grey.shade600),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  ),
                                  obscureText: true,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'By signing up, you agree to our Terms of Service and start your 3-day free trial. After the trial ends, you\'ll be charged \$2.50/month.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                                    onPressed: _isLoading ? null : _signup,
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
                                            'Sign Up',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/login');
                                  },
                                  child: Text(
                                    'Already have an account? Log In',
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
