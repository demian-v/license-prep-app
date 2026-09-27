import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/email_verification_handler.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';
import '../widgets/bento_result_parts.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String oobCode;
  
  const EmailVerificationScreen({
    Key? key,
    required this.oobCode,
  }) : super(key: key);
  
  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  
  bool _isProcessing = true;
  EmailVerificationResult? _result;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Set up animations
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    // One settle-in as the result lands — no bounce (AppMotion.enter).
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: AppMotion.enter),
    );
    
    // Start processing verification
    _processVerification();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _processVerification() async {
    try {
      debugPrint('📧 EmailVerificationScreen: Starting verification process');
      
      // 1. Use the handler to process the verification code
      final result = await EmailVerificationHandler.handleVerificationCode(widget.oobCode);
      
      setState(() {
        _result = result;
        _isProcessing = false;
      });
      
      // Start animation
      _animationController.forward();
      
      if (result == EmailVerificationResult.success) {
        // 2. Update the AuthProvider with the verified email (only if still signed in)
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.applyVerifiedEmail();
        
        debugPrint('✅ EmailVerificationScreen: Verification completed successfully');
        
        // Navigate to profile after showing success for 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        });
        
      } else if (result == EmailVerificationResult.successButSignedOut) {
        debugPrint('✅ EmailVerificationScreen: Email verified but user signed out');
        // Don't auto-navigate - user needs to sign in with new email
        
      } else {
        debugPrint('❌ EmailVerificationScreen: Verification failed');
      }
      
    } catch (e) {
      debugPrint('❌ EmailVerificationScreen: Error during verification process: $e');
      
      setState(() {
        _isProcessing = false;
        _result = EmailVerificationResult.failed;
        _errorMessage = EmailVerificationHandler.getErrorMessage(e.toString());
      });
      
      // Start error animation
      _animationController.forward();
    }
  }
  
  void _retryVerification() {
    setState(() {
      _isProcessing = true;
      _result = null;
      _errorMessage = null;
    });
    
    _animationController.reset();
    _processVerification();
  }
  
  void _goToProfile() {
    Navigator.pushReplacementNamed(context, '/profile');
  }
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(
        title: _getHeaderTitle(localizations),
        onBack: _goToProfile,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4 + AppSpacing.x1,
              vertical: AppSpacing.x6,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.x6),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(BentoTokens.card),
                  boxShadow: AppColors.shadowCard,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The status on its disc, settling in once as it lands
                    AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isProcessing || reduceMotion ? 1.0 : _scaleAnimation.value,
                          child: _buildStatusIcon(),
                        );
                      },
                    ),
                    
                    const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),
                    
                    // Title — one line; a long translation shrinks rather than wraps
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _getStatusTitle(localizations),
                        maxLines: 1,
                        style: AppTypography.title.copyWith(
                          fontSize: 22,
                          height: 28 / 22,
                          color: AppColors.ink,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.x2),
                    
                    // Message
                    Text(
                      _getStatusMessage(localizations),
                      style: AppTypography.body.copyWith(
                        fontSize: 15,
                        height: 22 / 15,
                        color: AppColors.inkSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: AppSpacing.x6),
                    
                    // Action buttons
                    _buildActionButtons(localizations),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Blue while it works, green once verified, red if it failed.
  Widget _buildStatusIcon() {
    if (_isProcessing) {
      return Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.signal50,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: AppColors.signal,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    } else if (_result == EmailVerificationResult.success || 
               _result == EmailVerificationResult.successButSignedOut) {
      return bentoAuthBadge(
        SolarIcons.checkLinear,
        tone: AppColors.guide,
        surface: AppColors.guideSurface,
      );
    } else {
      return bentoAuthBadge(
        SolarIcons.closeLinear,
        tone: AppColors.stop,
        surface: AppColors.stopSurface,
      );
    }
  }
  
  Widget _buildActionButtons(AppLocalizations localizations) {
    if (_isProcessing) {
      return SizedBox.shrink(); // No buttons while processing
    } else if (_result == EmailVerificationResult.success) {
      return BentoAuthPrimaryButton(
        label: localizations.translate('go_to_profile') ?? 'Go To Profile',
        onPressed: _goToProfile,
      );
    } else if (_result == EmailVerificationResult.successButSignedOut) {
      return BentoAuthPrimaryButton(
        label: localizations.translate('go_to_signin') ?? 'Go to Sign In',
        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BentoAuthPrimaryButton(
            label: localizations.translate('try_again') ?? 'Try Again',
            onPressed: _retryVerification,
          ),
          
          const SizedBox(height: AppSpacing.x2),
          
          BentoAuthLink(
            label: localizations.translate('go_to_profile') ?? 'Go To Profile',
            onPressed: _goToProfile,
          ),
        ],
      );
    }
  }
  
  String _getHeaderTitle(AppLocalizations localizations) {
    if (_result == EmailVerificationResult.success || 
        _result == EmailVerificationResult.successButSignedOut) {
      return localizations.translate('email_verified') ?? 'Email Changed Successfully';
    } else if (!_isProcessing && _result == EmailVerificationResult.failed) {
      return localizations.translate('verification_failed') ?? 'Verification Failed';
    } else {
      return localizations.translate('verify_email') ?? 'Verify Email';
    }
  }
  
  String _getStatusTitle(AppLocalizations localizations) {
    if (_isProcessing) {
      return localizations.translate('verifying_email') ?? 'Verifying Your Email';
    } else if (_result == EmailVerificationResult.success) {
      return localizations.translate('email_verified') ?? 'Email Verified!';
    } else if (_result == EmailVerificationResult.successButSignedOut) {
      return localizations.translate('email_changed_success_title') ?? 'Email Changed Successfully!';
    } else {
      return localizations.translate('verification_failed') ?? 'Verification Failed';
    }
  }
  
  String _getStatusMessage(AppLocalizations localizations) {
    if (_isProcessing) {
      return localizations.translate('verifying_email_message') ?? 
          'Please wait while we verify your new email address...';
    } else if (_result == EmailVerificationResult.success) {
      return localizations.translate('email_verified_message') ?? 
          'Your email address has been successfully verified. You will be redirected to your profile shortly.';
    } else if (_result == EmailVerificationResult.successButSignedOut) {
      return localizations.translate('email_changed_success_message') ?? 
          'Your email has been changed successfully! Please sign in with your new email address.';
    } else {
      return _errorMessage ?? 
          (localizations.translate('verification_failed_message') ?? 
           'Failed to verify email. Please try again or request a new verification email.');
    }
  }
}
