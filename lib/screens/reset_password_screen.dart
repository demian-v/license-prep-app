import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../services/password_reset_handler.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

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
  bool _showValidationErrors = false;
  
  // Analytics tracking variables
  DateTime? _formStartTime;
  int _validationAttempts = 0;
  
  @override
  void initState() {
    super.initState();
    
    // Track form start time
    _formStartTime = DateTime.now();
    
    _verifyResetCode();
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('expired')) {
      return 'expired_link';
    } else if (errorMessage.contains('invalid')) {
      return 'invalid_code';
    } else if (errorMessage.contains('malformed')) {
      return 'malformed_link';
    } else if (errorMessage.contains('network')) {
      return 'network_error';
    } else if (errorMessage.contains('token')) {
      return 'token_expired';
    } else {
      return 'unknown_error';
    }
  }
  
  Future<void> _verifyResetCode() async {
    try {
      setState(() => _isLoading = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _email = await authProvider.verifyPasswordResetCode(widget.code);
      
      // Track successful link access
      analyticsService.logPasswordResetLinkAccessed(
        validLink: true,
      );
      debugPrint('📊 Analytics: password_reset_link_accessed logged (valid: true)');
      
      setState(() => _errorMessage = null);
    } catch (e) {
      // Track failed link access
      analyticsService.logPasswordResetLinkAccessed(
        validLink: false,
      );
      
      analyticsService.logPasswordResetFailed(
        failureStage: 'link_access',
        errorType: _getErrorType(e.toString()),
        errorMessage: e.toString(),
      );
      debugPrint('📊 Analytics: password_reset_failed logged (stage: link_access)');
      
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
  
  bool _isStrongPassword(String password) {
    // Check if password meets all criteria beyond basic validation
    return password.length >= 8 &&
           password.contains(RegExp(r'[a-z]')) &&
           password.contains(RegExp(r'[A-Z]')) &&
           password.contains(RegExp(r'[0-9]')) &&
           password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  }

  Future<void> _resetPassword() async {
    _validationAttempts++;
    
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage =
          AppLocalizations.of(context).translate('auth_passwords_do_not_match'));
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
      
      // Track successful completion
      final timeSpent = _formStartTime != null 
          ? DateTime.now().difference(_formStartTime!).inSeconds 
          : null;
      final strongPassword = _isStrongPassword(_passwordController.text);
      
      analyticsService.logPasswordResetCompleted(
        timeSpentOnForm: timeSpent,
        validationAttempts: _validationAttempts,
        strongPassword: strongPassword,
      );
      debugPrint('📊 Analytics: password_reset_completed logged (time: ${timeSpent}s, attempts: $_validationAttempts)');
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/reset-success');
      }
    } catch (e) {
      // Track failure
      String errorType = 'unknown_error';
      if (e.toString().contains('weak-password')) {
        errorType = 'weak_password';
      } else if (e.toString().contains('expired')) {
        errorType = 'token_expired';
      } else if (e.toString().contains('network')) {
        errorType = 'network_error';
      }
      
      analyticsService.logPasswordResetFailed(
        failureStage: 'password_change',
        errorType: errorType,
        errorMessage: e.toString(),
      );
      debugPrint('📊 Analytics: password_reset_failed logged (stage: password_change)');
      
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
    final Widget body;
    if (_isLoading && _email == null) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.signal),
      );
    } else if (_errorMessage != null && _email == null) {
      body = _buildErrorWidget();
    } else {
      body = _buildResetForm();
    }
    return Scaffold(
      backgroundColor: AppColors.field,
      // Opened from an email link this is the first page, with nowhere to go
      // back to; the round back button shows only when there is.
      appBar: Navigator.of(context).canPop()
          ? bentoAuthAppBar(onBack: () => Navigator.of(context).pop())
          : null,
      body: SafeArea(child: body),
    );
  }

  /// The page's blocks, stepping in once, from the top of the page as on the
  /// other sign-in pages (owner, 2026-09-26: centred, it sat too low).
  Widget _page(List<Widget> blocks) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x4 + AppSpacing.x1,
        // Opened from an email link there is no app bar above, so the page
        // keeps a little more room at the top.
        Navigator.of(context).canPop() ? AppSpacing.x2 : AppSpacing.x8,
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
    );
  }

  TextStyle get _leadStyle => AppTypography.body.copyWith(
        fontSize: 15,
        height: 22 / 15,
        color: AppColors.inkSecondary,
      );

  Widget _buildErrorWidget() {
    final l = AppLocalizations.of(context);
    return _page([
      // Red: the link failed.
      bentoAuthBadge(
        SolarIcons.dangerCircleLinear,
        tone: AppColors.stop,
        surface: AppColors.stopSurface,
      ),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: l.translate('auth_reset_link_error'),
        children: [
          // The translated line, not the raw Firebase error (owner,
          // 2026-09-26): that still goes to analytics in _verifyResetCode.
          Text(
            l.translate('auth_reset_link_invalid'),
            textAlign: TextAlign.center,
            style: _leadStyle,
          ),
          const SizedBox(height: AppSpacing.x6),
          BentoAuthPrimaryButton(
            label: l.translate('auth_request_new_link'),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/forgot-password');
            },
          ),
        ],
      ),
    ]);
  }

  /// A password field as the login fields; the ring turns red while the
  /// submitted value breaks a rule ([invalid]).
  InputDecoration _passwordDecoration({
    required String label,
    required bool invalid,
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    final base = bentoFieldDecoration(
      label: label,
      icon: SolarIcons.lockKeyholeMinimalisticLinear,
    );
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: color, width: width),
        );
    return base.copyWith(
      prefixIcon: Icon(
        SolarIcons.lockKeyholeMinimalisticLinear,
        color: invalid ? AppColors.stop : AppColors.inkSecondary,
        size: 22,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          obscured ? SolarIcons.eyeLinear : SolarIcons.eyeClosedLinear,
          color: AppColors.inkSecondary,
          size: 22,
        ),
        onPressed: onToggle,
      ),
      enabledBorder: invalid ? ring(AppColors.stop, 1.5) : null,
      focusedBorder: invalid ? ring(AppColors.stop, 1.5) : null,
    );
  }

  Widget _buildResetForm() {
    final l = AppLocalizations.of(context);
    final passwordInvalid =
        _showValidationErrors && !_validatePassword(_passwordController.text);
    final confirmInvalid = _showValidationErrors &&
        (_passwordController.text != _confirmPasswordController.text);

    // No badge above the form (owner, 2026-09-26): the rules panel needs the
    // room, and the form should sit high enough to read without scrolling.
    return _page([
      BentoAuthCard(
        title: l.translate('auth_change_password_heading'),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.translate('auth_change_password_instructions'),
                  textAlign: TextAlign.center,
                  style: _leadStyle,
                ),
                const SizedBox(height: AppSpacing.x6),
                if (_errorMessage != null) ...[
                  BentoAuthError(_errorMessage!),
                  const SizedBox(height: AppSpacing.x4),
                ],
                TextFormField(
                  controller: _passwordController,
                  cursorColor: AppColors.signal,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  decoration: _passwordDecoration(
                    label: l.translate('auth_new_password'),
                    invalid: passwordInvalid,
                    obscured: _obscurePassword,
                    onToggle: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_enter_a_password');
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
                const SizedBox(height: AppSpacing.x3),
                TextFormField(
                  controller: _confirmPasswordController,
                  cursorColor: AppColors.signal,
                  style: AppTypography.body.copyWith(color: AppColors.ink),
                  decoration: _passwordDecoration(
                    label: l.translate('auth_confirm_new_password'),
                    invalid: confirmInvalid,
                    obscured: _obscureConfirmPassword,
                    onToggle: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('auth_confirm_password_required');
                    }
                    if (value != _passwordController.text) {
                      return AppLocalizations.of(context).translate('auth_passwords_do_not_match');
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      _showValidationErrors = false; // Reset validation error highlighting
                    });
                  },
                ),
                if (_validationErrors.isNotEmpty || _passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x4),
                  _buildRequirements(l, highlighted: passwordInvalid),
                ],
                const SizedBox(height: AppSpacing.x6),
                BentoAuthPrimaryButton(
                  label: l.translate('auth_reset_password'),
                  loading: _isLoading,
                  onPressed: _isLoading ? null : _resetPassword,
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  /// The rules as a grey panel inside the card (a soft red one once a
  /// submit broke them): met rules turn green, broken ones red.
  Widget _buildRequirements(AppLocalizations l, {required bool highlighted}) {
    final text = _passwordController.text;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.stopSurface : AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.translate('auth_password_requirements'),
            style: AppTypography.label.copyWith(
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          _buildValidationItem(l.translate('auth_pw_rule_min_length'), text.length >= 8),
          const SizedBox(height: AppSpacing.x2),
          _buildValidationItem(l.translate('auth_pw_rule_all_required'), true),
          const SizedBox(height: AppSpacing.x1),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildValidationSubItem(
                  l.translate('auth_pw_rule_lower'),
                  text.contains(RegExp(r'[a-z]')),
                ),
                const SizedBox(height: AppSpacing.x1),
                _buildValidationSubItem(
                  l.translate('auth_pw_rule_upper'),
                  text.contains(RegExp(r'[A-Z]')),
                ),
                const SizedBox(height: AppSpacing.x1),
                _buildValidationSubItem(
                  l.translate('auth_pw_rule_number'),
                  text.contains(RegExp(r'[0-9]')),
                ),
                const SizedBox(height: AppSpacing.x1),
                _buildValidationSubItem(
                  l.translate('auth_pw_rule_special'),
                  text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// One password requirement, as an icon and a line of text.
  ///
  /// The text is `Expanded` so it WRAPS instead of overflowing. Without it,
  /// "All of the following criteria are required:" ran 11 pixels past the
  /// panel on an iPhone 16 Pro — the widest phone this app supports — which
  /// means it overflowed on every device, and by more on the narrow ones.
  ///
  /// Wrapping rather than shrinking the font on purpose: a smaller font only
  /// moves the width at which this breaks, and the translations (2026-09-26)
  /// run longer than the English.
  Widget _buildValidationItem(String text, bool isValid) {
    final bool highlightError = _showValidationErrors && !isValid;
    
    return Row(
      // Keeps the icon on the FIRST line once the text wraps to two.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Nudges the icon onto the text's optical baseline; without it the
          // icon sits slightly high against the first line.
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            isValid ? SolarIcons.checkCircleBold : (highlightError ? SolarIcons.closeCircleBold : SolarIcons.recordLinear),
            color: isValid ? AppColors.guide : (highlightError ? AppColors.stop : AppColors.inkTertiary),
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.label.copyWith(
              color: highlightError ? AppColors.stop : (isValid ? AppColors.ink : AppColors.inkSecondary),
              fontVariations: [FontVariation('wght', highlightError ? 600 : 400)],
            ),
          ),
        ),
      ],
    );
  }
  
  /// A nested requirement. Same fix as `_buildValidationItem`, and it needs it
  /// more: these sit inside a 16px indent, so they have less room, and
  /// "Special characters (e.g. !@#\$%^&*)" is the longest string on the panel.
  Widget _buildValidationSubItem(String text, bool isValid) {
    return _buildValidationItem(text, isValid);
  }
}
