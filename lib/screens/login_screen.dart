import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // The whole-card press scale was removed with the Bento restyle
  // (2026-09-26): the card is not a button.

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  // Navigation — moved unchanged from the inline handlers.
  void _onForgotPassword() {
    Navigator.pushNamed(context, '/forgot-password');
  }

  void _onSignup() {
    Navigator.pushNamed(context, '/signup');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Bento (2026-09-26): the logo on the field page, the form as one white
    // card with grey field panels, the dark `ink` pill to log in, and the
    // switch to signup as a blue link under the card.
    final blocks = <Widget>[
      bentoAuthLogo(l.translate('auth_app_title')),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: l.translate('auth_log_in'),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  BentoAuthError(_errorMessage!),
                  const SizedBox(height: AppSpacing.x4),
                ],
                TextFormField(
                  controller: _emailController,
                  decoration: bentoFieldDecoration(
                    label: l.translate('email'),
                    icon: SolarIcons.letterLinear,
                  ),
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_enter_email');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.x3),
                TextFormField(
                  controller: _passwordController,
                  decoration: bentoFieldDecoration(
                    label: l.translate('password'),
                    icon: SolarIcons.lockKeyholeMinimalisticLinear,
                  ),
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_enter_password');
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: BentoAuthLink(
                    label: l.translate('auth_forgot_password_link'),
                    onPressed: _onForgotPassword,
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                BentoAuthPrimaryButton(
                  label: l.translate('auth_log_in'),
                  onPressed: _isLoading ? null : _login,
                  loading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x3),
      Center(
        child: BentoAuthLink(
          label: l.translate('auth_no_account_signup'),
          onPressed: _onSignup,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4 + AppSpacing.x1,
              vertical: AppSpacing.x6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < blocks.length; i++)
                  StaggerIn(
                    index: i,
                    count: blocks.length,
                    curve: BentoTokens.curve,
                    child: blocks[i],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
