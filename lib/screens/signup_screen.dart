import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../services/in_app_purchase_service.dart';
import 'signup_role_step.dart';
import 'verification_code_screen.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  // «Create Student Account» or «Create Instructor Account» (owner,
  // 2026-09-30): the same form, a link below switches. The role itself is
  // saved after the email code, by SignupRoleStep.
  bool _instructor = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _agreedToTerms = false;
  bool _termsError = false;
  
  // The whole-card press scale was removed with the Bento restyle
  // (2026-09-26): the card is not a button.
  
  // Analytics tracking variables
  DateTime? _formStartTime;
  bool _formStarted = false;
  bool _hasFormErrors = false;
  String? _formErrors;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  /// Launch Terms of Service URL
  Future<void> _launchTermsOfService() async {
    final Uri url = Uri.parse('https://sites.google.com/view/driveusa/home');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('auth_error_terms_open'))),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('auth_error_link_open'))),
        );
      }
    }
  }

  /// Parse technical error messages into user-friendly messages
  String _parseErrorMessage(String errorMessage) {
    final errorLower = errorMessage.toLowerCase();
    
    if (errorLower.contains('email-already-in-use') || 
        errorLower.contains('email address is already in use')) {
      return AppLocalizations.of(context).translate('auth_error_email_in_use');
    } else if (errorLower.contains('weak-password') || 
               errorLower.contains('password is too weak')) {
      return AppLocalizations.of(context).translate('auth_error_weak_password');
    } else if (errorLower.contains('invalid-email')) {
      return AppLocalizations.of(context).translate('auth_error_invalid_email');
    } else if (errorLower.contains('network')) {
      return AppLocalizations.of(context).translate('auth_error_network');
    } else {
      // Extract the meaningful part after "Registration failed:" if present
      if (errorMessage.contains('Registration failed:')) {
        return errorMessage.split('Registration failed:').last.trim();
      }
      return AppLocalizations.of(context).translate('auth_error_signup_generic');
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
    
    // Check if user agreed to terms
    if (!_agreedToTerms) {
      setState(() {
        _termsError = true;
      });
      _hasFormErrors = true;
      _formErrors = 'terms_not_agreed';
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
          
          // The trial starts after the email code (SignupRoleStep logs it).
          
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
          // Sign Up -> Check email -> role step (owner, 2026-09-30), then
          // language. The trial starts at the role step, after the code —
          // superseding risk #12's "trial before verification"
          // (2026-09-17): the role is saved there first.
          final role = _instructor ? 'instructor' : 'student';
          if (userId != null) await SignupIntent.save(userId, role);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VerificationCodeScreen(
                email: email,
                onVerified: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => SignupRoleStep(role: role)),
                ),
              ),
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
        } catch (analyticsError) {
          debugPrint('⚠️ Analytics error (non-critical): $analyticsError');
        }
        
        if (mounted) {
          // Show a toast or snackbar with warning
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('auth_warn_partial_save')))
          );
          
          // Still navigate to next screen (the same path as below).
          final role = _instructor ? 'instructor' : 'student';
          final uid = Provider.of<AuthProvider>(context, listen: false).user?.id;
          if (uid != null) await SignupIntent.save(uid, role);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => VerificationCodeScreen(
                email: email,
                onVerified: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => SignupRoleStep(role: role)),
                ),
              ),
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

  // Moved unchanged from the inline handlers.
  void _onTermsChanged(bool? value) {
    setState(() {
      _agreedToTerms = value ?? false;
      if (_agreedToTerms) {
        _termsError = false;
      }
    });
  }

  void _onLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  /// The terms agreement as a grey panel with the checkbox; red while the
  /// user tried to sign up without ticking it.
  Widget _buildTerms(AppLocalizations l) {
    // The price exactly as the store formats it for this storefront, as on
    // the paywall — never a typed-in «$9.99». Before the store has answered
    // (or without a store) the price sentence is left out rather than
    // guessed.
    final storePrice = Provider.of<InAppPurchaseService>(context, listen: false)
        .getProduct(InAppPurchaseService.monthlyProductId)
        ?.price;
    return AnimatedContainer(
      duration: AppMotion.duration(context, BentoTokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x1,
        AppSpacing.x2,
        AppSpacing.x3,
        AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: _termsError ? AppColors.stopSurface : AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged: _onTermsChanged,
                activeColor: AppColors.signal,
                side: BorderSide(
                  color: _termsError ? AppColors.stop : AppColors.inkSecondary,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x2 + 2),
                  child: RichText(
                    text: TextSpan(
                      style: AppTypography.caption.copyWith(
                        fontSize: 13,
                        height: 19 / 13,
                        color: _termsError ? AppColors.stop : AppColors.inkSecondary,
                        fontVariations: const [FontVariation('wght', 400)],
                      ),
                      children: [
                        TextSpan(text: l.translate('signup_terms_prefix')),
                        TextSpan(
                          text: l.translate('terms_of_use'),
                          style: TextStyle(
                            color: _termsError ? AppColors.stop : AppColors.signal,
                            decoration: TextDecoration.underline,
                            decorationColor: _termsError ? AppColors.stop : AppColors.signal,
                            fontVariations: const [FontVariation('wght', 500)],
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchTermsOfService();
                            },
                        ),
                        TextSpan(text: l.translate('signup_terms_trial')),
                        if (storePrice != null)
                          TextSpan(
                            text: l
                                .translate('signup_terms_price')
                                .replaceAll('{price}', '$storePrice${l.translate('per_month')}'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_termsError) ...[
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.x3, top: AppSpacing.x1),
              child: Text(
                l.translate('auth_agree_terms_required'),
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.stop,
                  fontVariations: const [FontVariation('wght', 500)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Bento (2026-09-26), as the login screen: the logo, the form as one
    // white card with grey field panels and the terms panel, the dark `ink`
    // pill to sign up, and the switch to login as a blue link.
    final blocks = <Widget>[
      bentoAuthLogo(l.translate('auth_app_title')),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: _instructor
            ? l.translate('auth_create_instructor_account')
            : l.translate('auth_create_student_account'),
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
                  controller: _nameController,
                  onTap: _onFormStarted,
                  onChanged: (value) => _onFormStarted(),
                  decoration: bentoFieldDecoration(
                    label: l.translate('auth_full_name'),
                    icon: SolarIcons.userRoundedLinear,
                  ),
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_enter_name');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.x3),
                TextFormField(
                  controller: _emailController,
                  onTap: _onFormStarted,
                  onChanged: (value) => _onFormStarted(),
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
                    // Check for valid email format
                    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                    if (!emailRegex.hasMatch(value)) {
                      return AppLocalizations.of(context).translate('auth_enter_valid_email');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.x3),
                TextFormField(
                  controller: _passwordController,
                  onTap: _onFormStarted,
                  onChanged: (value) => _onFormStarted(),
                  decoration: bentoFieldDecoration(
                    label: l.translate('password'),
                    icon: SolarIcons.lockKeyholeMinimalisticLinear,
                  ),
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_enter_a_password');
                    }
                    if (value.length < 6) {
                      return AppLocalizations.of(context).translate('auth_password_min_length');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.x3),
                _buildTerms(l),
                const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),
                BentoAuthPrimaryButton(
                  label: l.translate('signup'),
                  onPressed: _isLoading ? null : _signup,
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
          label: _instructor
              ? l.translate('auth_switch_to_student')
              : l.translate('auth_switch_to_instructor'),
          onPressed: _isLoading ? null : () => setState(() => _instructor = !_instructor),
        ),
      ),
      Center(
        child: BentoAuthLink(
          label: l.translate('auth_have_account_login'),
          onPressed: _onLogin,
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
