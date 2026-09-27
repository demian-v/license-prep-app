import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  
  // Analytics tracking variables
  DateTime? _formStartTime;
  bool _formStarted = false;
  bool _hasFormErrors = false;
  String? _formErrors;
  
  @override
  void dispose() {
    _emailController.dispose();
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
          _errorMessage = AppLocalizations.of(context).translate('auth_error_try_again');
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
    final l = AppLocalizations.of(context);
    final blocks = <Widget>[
      bentoAuthBadge(SolarIcons.lockKeyholeMinimalisticLinear),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: l.translate('auth_forgot_heading'),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.translate('auth_forgot_instructions'),
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    fontSize: 15,
                    height: 22 / 15,
                    color: AppColors.inkSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                if (_errorMessage != null) ...[
                  BentoAuthError(_errorMessage!),
                  const SizedBox(height: AppSpacing.x4),
                ],
                TextFormField(
                  controller: _emailController,
                  onTap: _onFormStarted,
                  onChanged: (value) => _onFormStarted(),
                  cursorColor: AppColors.signal,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  decoration: bentoFieldDecoration(
                    label: l.translate('auth_email_address'),
                    icon: SolarIcons.letterLinear,
                  ).copyWith(
                    hintText: l.translate('auth_enter_your_email'),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_enter_email');
                    }
                    
                    // Basic email validation
                    final emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegExp.hasMatch(value)) {
                      return AppLocalizations.of(context).translate('auth_enter_valid_email');
                    }
                    
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.x6),
                BentoAuthPrimaryButton(
                  label: l.translate('continue'),
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _sendResetEmail,
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x3),
      Center(
        child: BentoAuthLink(
          label: l.translate('auth_back_to_login'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoAuthAppBar(onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x2,
            AppSpacing.x4 + AppSpacing.x1,
            AppSpacing.x6,
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
    );
  }
}
