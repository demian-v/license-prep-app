import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/email_verification_handler.dart';
import '../providers/auth_provider.dart';
import '../localization/app_localizations.dart';

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
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
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
    
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header with back button
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.grey[600]),
                    onPressed: _goToProfile,
                  ),
                  Expanded(
                    child: Text(
                      _getHeaderTitle(localizations),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 48), // Balance the back button
                ],
              ),
              
              SizedBox(height: 20),
              
              Expanded(
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(maxWidth: 400),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Animated icon
                            AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isProcessing ? 1.0 : _scaleAnimation.value,
                                  child: _buildStatusIcon(),
                                );
                              },
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Title
                            Text(
                              _getStatusTitle(localizations),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: 12),
                            
                            // Message
                            Text(
                              _getStatusMessage(localizations),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            
                            SizedBox(height: 24),
                            
                            // Action buttons
                            _buildActionButtons(localizations),
                          ],
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
    );
  }
  
  Widget _buildStatusIcon() {
    if (_isProcessing) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Color(0xFFFF6B35),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ),
        ),
      );
    } else if (_result == EmailVerificationResult.success || 
               _result == EmailVerificationResult.successButSignedOut) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check,
          color: Colors.white,
          size: 40,
        ),
      );
    } else {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Color(0xFFFF6B35),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: Colors.white,
          size: 40,
        ),
      );
    }
  }
  
  Widget _buildActionButtons(AppLocalizations localizations) {
    if (_isProcessing) {
      return SizedBox.shrink(); // No buttons while processing
    } else if (_result == EmailVerificationResult.success) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _goToProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF667eea),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: Text(
            localizations.translate('go_to_profile') ?? 'Go To Profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (_result == EmailVerificationResult.successButSignedOut) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF667eea),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: Text(
            localizations.translate('go_to_signin') ?? 'Go to Sign In',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _retryVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                localizations.translate('try_again') ?? 'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          SizedBox(height: 12),
          
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _goToProfile,
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF667eea),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                localizations.translate('go_to_profile') ?? 'Go To Profile',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
