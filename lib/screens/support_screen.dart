import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/auth_provider.dart';
import '../services/report_service.dart';
import '../services/service_locator.dart';

class SupportScreen extends StatefulWidget {
  @override
  _SupportScreenState createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  late AnimationController _cardAnimationController;
  late AnimationController _featuresAnimationController;
  late AnimationController _buttonAnimationController;
  late AnimationController _scaleController;

  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _buttonSlideAnimation;
  late Animation<double> _buttonFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool get _canSubmit => _messageController.text.trim().length >= 10;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _featuresAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _buttonAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 100),
      vsync: this,
    );

    // Setup animations
    _cardSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    ));

    _cardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeIn,
    ));

    _buttonSlideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeOut,
    ));

    _buttonFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonAnimationController,
      curve: Curves.easeIn,
    ));

    _buttonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Start animations with delays
    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) _cardAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) _featuresAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 600), () {
      if (mounted) _buttonAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _cardAnimationController.dispose();
    _featuresAnimationController.dispose();
    _buttonAnimationController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  // Helper method to get gradient for main card
  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Colors.blue.shade50.withOpacity(0.3)],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for info section
  LinearGradient _getInfoGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for buttons
  LinearGradient _getButtonGradient(bool isActive, bool isBack) {
    if (isBack) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey.shade50.withOpacity(0.4)],
        stops: [0.0, 1.0],
      );
    } else if (isActive) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
        stops: [0.0, 1.0],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, Colors.grey.shade50.withOpacity(0.4)],
        stops: [0.0, 1.0],
      );
    }
  }

  Future<void> _sendMessage() async {
    if (!_canSubmit) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final reportService = serviceLocator.report;

      await reportService.submitSupportReport(
        message: _messageController.text.trim(),
        language: languageProvider.language,
        state: authProvider.user?.state ?? 'unknown',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.green, size: 16),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).translate('support_thanks'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 8,
            margin: EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = AppLocalizations.of(context).translate('support_error');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('support_title'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50.withOpacity(0.2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8),
              
              // Enhanced support card
              _buildEnhancedSupportCard(),
              
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSupportCard() {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _cardSlideAnimation.value),
          child: Opacity(
            opacity: _cardFadeAnimation.value,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _getCardGradient(),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Enhanced info section
                    _buildEnhancedInfoSection(),
                    
                    SizedBox(height: 24),
                    
                    // Message section
                    Text(
                      AppLocalizations.of(context).translate('message_details'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    // Enhanced message input
                    _buildEnhancedMessageSection(),
                    
                    SizedBox(height: 12),
                    
                    // Enhanced character counter
                    _buildEnhancedCharacterCounter(),
                    
                    SizedBox(height: 24),
                    
                    // Error message
                    if (_errorMessage != null) ...[
                      _buildEnhancedErrorMessage(),
                      SizedBox(height: 16),
                    ],
                    
                    // Enhanced action buttons
                    _buildEnhancedActionButtons(),
                    
                    SizedBox(height: 12),
                    
                    // Fine print
                    Text(
                      AppLocalizations.of(context).translate('support_response_info'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedInfoSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _getInfoGradient(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue.shade100],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue.shade300, width: 2),
            ),
            child: Icon(Icons.support_agent, color: Colors.blue.shade700, size: 24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('contact_support'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).translate('support_desc'),
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMessageSection() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _canSubmit ? Colors.green.shade300 : Colors.grey.shade300,
          width: _canSubmit ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _messageController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          fontSize: 16,
          fontFamily: 'Roboto',
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).translate('support_message_placeholder'),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildEnhancedCharacterCounter() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _canSubmit 
              ? [Colors.white, Colors.green.shade50.withOpacity(0.4)]
              : [Colors.white, Colors.grey.shade50.withOpacity(0.4)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _canSubmit ? Colors.green.shade200 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Text(
          AppLocalizations.of(context).translate('character_counter').replaceAll('{0}', _messageController.text.trim().length.toString()),
          style: TextStyle(
            color: _canSubmit ? Colors.green.shade700 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedErrorMessage() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.red.shade50.withOpacity(0.6)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedActionButtons() {
    return AnimatedBuilder(
      animation: _buttonAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonSlideAnimation.value),
          child: Opacity(
            opacity: _buttonFadeAnimation.value,
            child: Row(
              children: [
                Expanded(
                  child: _buildEnhancedBackButton(),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildEnhancedSendButton(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedBackButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: _getButtonGradient(false, true),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 0,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.2),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                AppLocalizations.of(context).translate('back'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSendButton() {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _buttonScaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: _getButtonGradient(_canSubmit, false),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 0,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSubmitting || !_canSubmit ? null : _sendMessage,
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: _isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.blue.shade700,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context).translate('support_send'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _canSubmit ? Colors.black : Colors.grey.shade500,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
