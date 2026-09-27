import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';

class ResetEmailSentScreen extends StatefulWidget {
  @override
  _ResetEmailSentScreenState createState() => _ResetEmailSentScreenState();
}

class _ResetEmailSentScreenState extends State<ResetEmailSentScreen> {
  bool _isResending = false;
  
  // Analytics tracking variables
  DateTime? _emailSentTime;
  
  @override
  void initState() {
    super.initState();
    
    // Track when email confirmation screen is shown
    _emailSentTime = DateTime.now();
  }
  
  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('too-many-requests')) {
      return 'rate_limited';
    } else if (errorMessage.contains('network')) {
      return 'network_error';
    } else if (errorMessage.contains('invalid-email')) {
      return 'invalid_email';
    } else {
      return 'unknown_error';
    }
  }

  Future<void> _resendEmail() async {
    final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final email = args['email'] as String;
    
    setState(() {
      _isResending = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.sendPasswordResetEmail(email);
      
      // Track resend success
      final timeSinceFirst = _emailSentTime != null 
          ? DateTime.now().difference(_emailSentTime!).inSeconds 
          : null;
      final emailDomain = email.split('@').length > 1 ? email.split('@')[1] : null;
      
      analyticsService.logPasswordResetEmailResent(
        emailDomain: emailDomain,
        timeSinceFirstRequest: timeSinceFirst,
      );
      debugPrint('📊 Analytics: password_reset_email_resent logged (time since first: ${timeSinceFirst}s)');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('auth_reset_email_resent')))
        );
      }
    } catch (e) {
      // Track resend failure
      analyticsService.logPasswordResetFailed(
        failureStage: 'email_resend',
        errorType: _getErrorType(e.toString()),
        errorMessage: e.toString(),
      );
      debugPrint('📊 Analytics: password_reset_failed logged (stage: email_resend)');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('auth_error_sending_email')))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final email = args['email'] as String;
    final l = AppLocalizations.of(context);

    final blocks = <Widget>[
      bentoAuthBadge(SolarIcons.letterLinear),
      const SizedBox(height: AppSpacing.x6),
      BentoAuthCard(
        title: l.translate('auth_check_your_email'),
        children: [
          Text(
            l.translate('auth_check_email_instructions').replaceAll('{0}', email),
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              height: 22 / 15,
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          BentoAuthPrimaryButton(
            label: l.translate('auth_resend_email'),
            loading: _isResending,
            onPressed: _isResending ? null : _resendEmail,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x3),
      Center(
        child: BentoAuthLink(
          label: l.translate('auth_back_to_login'),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoAuthAppBar(
        onBack: () => Navigator.of(context).pushReplacementNamed('/login'),
      ),
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
