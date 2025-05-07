import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'language_selection_screen.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
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
      final success = await authProvider.signup(name, email, password);
      
      if (success) {
        debugPrint('✅ [SignupScreen] Signup successful');
        
        // Verify that the user has the correct default values
        final currentUser = authProvider.user;
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
        if (mounted) {
          setState(() {
            _errorMessage = 'Signup failed. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('SignupScreen: Error during signup: $e');
      
      // Check if this is a Firebase-specific error that we can handle
      if (e.toString().contains('email-already-in-use')) {
        setState(() {
          _errorMessage = 'This email is already in use. Please try a different email or log in.';
        });
      } else if (e.toString().contains('weak-password')) {
        setState(() {
          _errorMessage = 'Password is too weak. Please use a stronger password.';
        });
      } else if (e.toString().contains('invalid-email')) {
        setState(() {
          _errorMessage = 'Invalid email format. Please check your email address.';
        });
      } else if (e.toString().contains('createUserDocument')) {
        // User was created in Firebase Auth but document creation failed
        // This is a non-critical error, so we can still proceed
        debugPrint('SignupScreen: User created but document creation failed: $e');
        
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
        // For other errors, show generic message
        if (mounted) {
          setState(() {
            _errorMessage = 'An error occurred: ${e.toString().split(':').last}';
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
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'USA License Prep',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
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
                            decoration: InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
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
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock),
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'By signing up, you agree to our Terms of Service and start your 3-day free trial. After the trial ends, you\'ll be charged \$2.50/month.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signup,
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
                                    'Sign Up',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                          SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text('Already have an account? Log In'),
                          ),
                        ],
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
