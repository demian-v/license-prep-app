import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import '../widgets/enhanced_language_card.dart';
import '../services/analytics_service.dart';
import 'state_selection_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  @override
  _LanguageSelectionScreenState createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  // Analytics tracking variables
  DateTime? _selectionStartTime;
  String? _initialLanguage;
  
  @override
  void initState() {
    super.initState();
    
    // Track selection start time and initial language
    _selectionStartTime = DateTime.now();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _initialLanguage = languageProvider.language;
    
    // Log selection started
    analyticsService.logLanguageSelectionStarted(
      selectionContext: 'signup',
      currentLanguage: _initialLanguage,
    );
    debugPrint('📊 Analytics: language_selection_started logged (context: signup)');
    
    // Perform a final check for incorrect default values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyUserDefaults(context);
    });
  }
  
  Future<void> _verifyUserDefaults(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user;
      
      if (currentUser != null) {
        debugPrint('🔍 [LANGUAGE SCREEN] Verifying user default values:');
        debugPrint('    - Language: ${currentUser.language}');
        debugPrint('    - State: ${currentUser.state}');
        
        bool needsUpdate = false;
        
        // Verify language is correctly set to 'en' initially
        if (currentUser.language != 'en') {
          debugPrint('⚠️ [LANGUAGE SCREEN] Incorrect language detected: "${currentUser.language}", should be "en"');
          needsUpdate = true;
          
          // Update language provider to ensure UI is consistent
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          languageProvider.setLanguage('en');
        }
        
        // Verify state is correctly set to null initially
        if (currentUser.state != null) {
          debugPrint('⚠️ [LANGUAGE SCREEN] Incorrect state detected: "${currentUser.state}", should be null');
          needsUpdate = true;
        }
        
        // If needed, update the backend as final failsafe
        if (needsUpdate) {
          debugPrint('🔄 [LANGUAGE SCREEN] Fixing incorrect default values');
          
          try {
            // Access Firestore directly for a final fix attempt
            final firestore = FirebaseFirestore.instance;
            await firestore.collection('users').doc(currentUser.id).update({
              'language': 'en',
              'state': null,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            debugPrint('✅ [LANGUAGE SCREEN] Fixed user default values in Firestore');
          } catch (e) {
            debugPrint('⚠️ [LANGUAGE SCREEN] Failed to update default values in Firestore: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [LANGUAGE SCREEN] Error verifying user defaults: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🏳️‍🌈 [LANGUAGE SCREEN] Building language selection screen');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Language Selection', // This remains hardcoded in English as specified
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Select your language'), // This remains hardcoded in English as specified
                SizedBox(height: 8),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, _) => Column(
                    children: [
                      _buildLanguageButton(context, 'English', 'en'),
                      _buildLanguageButton(context, 'Spanish', 'es'),
                      _buildLanguageButton(context, 'Ukrainian', 'uk'),
                      _buildLanguageButton(context, 'Polish', 'pl'),
                      _buildLanguageButton(context, 'Russian', 'ru'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  String _getErrorType(String errorMessage) {
    if (errorMessage.contains('provider')) {
      return 'provider_error';
    } else if (errorMessage.contains('auth')) {
      return 'auth_error';
    } else if (errorMessage.contains('network')) {
      return 'network_error';
    } else {
      return 'unknown_error';
    }
  }

  Widget _buildLanguageButton(BuildContext context, String language, String code) {
    // Get the color for the language (for the snackbar)
    final Map<String, Color> languageColors = {
      'en': Color(0xFF3F51B5), // Indigo for English
      'es': Color(0xFFE91E63), // Pink for Spanish
      'uk': Color(0xFF2196F3), // Blue for Ukrainian
      'pl': Color(0xFF4CAF50), // Green for Polish
      'ru': Color(0xFFF44336), // Red for Russian
    };
    
    return EnhancedLanguageCard(
      language: language,
      languageCode: code,
      onTap: () async {
        // Visual feedback
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setting UI language to $language...'), // Updated message
            duration: Duration(seconds: 2),
            backgroundColor: languageColors[code],
          ),
        );
        
        try {
          // Get current language before change
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          final previousLanguage = languageProvider.language;
          
          // Update language provider
          print('🔄 [LANGUAGE SCREEN] Setting language to: $code');
          await languageProvider.setLanguage(code);
          
          // Verify language was set correctly
          print('✅ [LANGUAGE SCREEN] Language set to: ${languageProvider.language}');
          
          // Update auth provider
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.updateUserLanguage(code);
          print('✅ [LANGUAGE SCREEN] User language updated in auth provider');
          
          // Calculate time spent
          final timeSpent = _selectionStartTime != null 
              ? DateTime.now().difference(_selectionStartTime!).inSeconds 
              : null;
          
          // Track successful language change
          analyticsService.logLanguageChanged(
            selectionContext: 'signup',
            previousLanguage: previousLanguage,
            newLanguage: code,
            languageName: language,
            timeSpentSeconds: timeSpent,
          );
          debugPrint('📊 Analytics: language_changed logged (signup: $previousLanguage → $code)');
          
          // Wait longer to ensure the language is properly loaded
          print('⏳ [LANGUAGE SCREEN] Waiting for language to propagate...');
          await Future.delayed(Duration(milliseconds: 800));
          
          if (context.mounted) {
            // Pop all routes except first one
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            print('🔍 [LANGUAGE SCREEN] Current language before navigation: ${languageProvider.language}');
            print('🔍 [LANGUAGE SCREEN] About to navigate to StateSelectionScreen');
            
            // Use pushReplacement with unique key to force rebuild
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                settings: RouteSettings(
                  name: 'state_selection_${code}_${DateTime.now().millisecondsSinceEpoch}'
                ),
                pageBuilder: (context, animation1, animation2) => StateSelectionScreen(
                  key: UniqueKey(), // Force complete rebuild
                ),
                transitionDuration: Duration.zero,
              ),
            );
            print('🔄 [LANGUAGE SCREEN] Navigation completed to StateSelectionScreen');
          }
        } catch (e) {
          // Track failure
          analyticsService.logLanguageChangeFailed(
            selectionContext: 'signup',
            targetLanguage: code,
            errorType: _getErrorType(e.toString()),
            errorMessage: e.toString(),
          );
          debugPrint('📊 Analytics: language_change_failed logged (signup: $code)');
          
          print('🚨 [LANGUAGE SCREEN] Error updating language: $e');
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error selecting language: $e'), // Error message in English
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
}
