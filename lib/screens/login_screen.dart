import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
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
  }

  @override
  void dispose() {
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
          debugPrint('❌ LoginScreen: Failed to load logo asset: $error');
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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    try {
      // Use auth provider instead of direct service
      debugPrint('LoginScreen: Logging in with email: $email');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(email, password);
      
      if (success) {
        debugPrint('LoginScreen: Login successful');
        if (mounted) {
          // Navigate to home screen
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Login failed. Please check your credentials.';
        });
      }
    } catch (e) {
      debugPrint('LoginScreen: Error during login: $e');
      String errorMessage = 'An error occurred. Please try again.';
      
      // Check for specific Firebase auth errors to provide better guidance
      String errorString = e.toString().toLowerCase();
      
      if (errorString.contains('user-not-found') || 
          errorString.contains('no user record corresponding') ||
          errorString.contains('invalid-email')) {
        
        errorMessage = 'Email not found. If you recently verified a new email address, please use that email to log in.';
      } else if (errorString.contains('wrong-password') || 
                errorString.contains('invalid-credential')) {
        
        errorMessage = 'Invalid password. Please try again.';
      } else if (errorString.contains('user-disabled')) {
        errorMessage = 'This account has been disabled. Please contact support.';
      } else if (errorString.contains('too-many-requests')) {
        errorMessage = 'Too many failed login attempts. Please try again later.';
      } else if (errorString.contains('session-expired') || 
                errorString.contains('user-token-expired')) {
        
        errorMessage = 'Your session has expired. If you recently changed your email, please use your new email address to log in.';
      }
      
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
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
                                  'Log In',
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
                                  controller: _emailController,
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
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
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
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/forgot-password');
                                    },
                                    child: Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: Colors.indigo.shade400,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
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
                                    onPressed: _isLoading ? null : _login,
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
                                            'Log In',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/signup');
                                  },
                                  child: Text(
                                    'Don\'t have an account? Sign Up',
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
