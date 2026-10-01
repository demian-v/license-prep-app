import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import '../widgets/enhanced_language_card.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_auth_parts.dart';
import '../main.dart' show navigatorKey;
import 'instructor_kind_screen.dart';
import 'instructor_registration_screen.dart';
import 'signup_role_step.dart';
import 'state_selection_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  @override
  _LanguageSelectionScreenState createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  /// The language (English name) being applied, while a pick is in flight.
  ///
  /// Risk #77. A pick that changes the language rebuilds the whole app —
  /// `MaterialApp` is keyed by language (`main.dart`) — so this screen is
  /// thrown away and built again from `home` while the pick is still being
  /// saved. The new copy used to run `_verifyUserDefaults`, see the new
  /// language, call it a bad default and put English back; the old copy, now
  /// unmounted, skipped its navigation. Only English ever got through.
  ///
  /// So the pick lives here, outside any one State: a copy built while it is
  /// set shows the overlay and leaves the defaults alone, and the pick
  /// navigates through [navigatorKey], which reaches whichever navigator is
  /// live.
  static final ValueNotifier<String?> _pickInProgress = ValueNotifier(null);

  // Analytics tracking variables
  DateTime? _selectionStartTime;
  String? _initialLanguage;
  
  // Loading state variables
  bool _isLoading = false;
  String? _selectedLanguageName;
  
  @override
  void initState() {
    super.initState();
    
    // Track selection start time and initial language
    _selectionStartTime = DateTime.now();
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    _initialLanguage = languageProvider.language;
    
    // Built again mid-pick (the language change rebuilt the app): wait for
    // the pick to finish instead of starting over — no second "started"
    // event, and no reset of the language just chosen.
    _pickInProgress.addListener(_onPickInProgressChanged);
    final pendingPick = _pickInProgress.value;
    if (pendingPick != null) {
      debugPrint('🔁 [LANGUAGE SCREEN] Rebuilt while "$pendingPick" is being applied — waiting for it');
      _isLoading = true;
      _selectedLanguageName = pendingPick;
      return;
    }
    
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
  
  /// A pick finished or failed: drop the overlay (on success the screen is
  /// being replaced by state selection anyway).
  void _onPickInProgressChanged() {
    if (_pickInProgress.value == null && mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pickInProgress.removeListener(_onPickInProgressChanged);
    super.dispose();
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
      backgroundColor: AppColors.field,
      // The overlay's dim covers the whole screen, status bar included, so
      // the Stack sits outside the SafeArea — and expands, or it is only as
      // tall as the list and the dim stops short of the bottom.
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4 + AppSpacing.x1,
                AppSpacing.x8,
                AppSpacing.x4 + AppSpacing.x1,
                AppSpacing.x6,
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) {
                  final blocks = <Widget>[
                    bentoAuthBadge(SolarIcons.globalLinear),
                    const SizedBox(height: AppSpacing.x4),
                    _buildSectionHeader('Select your language'), // This remains hardcoded in English as specified
                    _buildLanguageButton(context, 'English', 'en'),
                    _buildLanguageButton(context, 'Spanish', 'es'),
                    _buildLanguageButton(context, 'Ukrainian', 'uk'),
                    _buildLanguageButton(context, 'Polish', 'pl'),
                    _buildLanguageButton(context, 'Russian', 'ru'),
                  ];
                  return Column(
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
                  );
                },
              ),
            ),
          ),
          // Loading overlay
          if (_isLoading) Positioned.fill(child: _buildLoadingOverlay()),
        ],
      ),
    );
  }

  /// The page's heading: the screen's name, then the ask under it — both
  /// English, since no language has been chosen yet.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x6),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Language Selection', // This remains hardcoded in English as specified
              maxLines: 1,
              style: AppTypography.title.copyWith(
                fontSize: 26,
                height: 32 / 26,
                color: AppColors.ink,
                fontVariations: const [FontVariation('wght', 700)],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              color: AppColors.inkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: AppColors.ink.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x6),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            boxShadow: AppColors.shadowRaised,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.signal,
                  strokeWidth: 3.5,
                ),
              ),
              const SizedBox(height: AppSpacing.x4 + AppSpacing.x1),
              Text(
                _selectedLanguageName != null
                    ? 'Setting up $_selectedLanguageName...'
                    : 'Please wait...',
                style: AppTypography.body.copyWith(
                  fontSize: 16,
                  color: AppColors.ink,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'This may take a few seconds',
                style: AppTypography.label.copyWith(color: AppColors.inkSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
      isEnabled: !_isLoading,
      isSelected: _isLoading && _selectedLanguageName == language,
      onTap: _isLoading ? null : () async {
        // Set loading state
        setState(() {
          _isLoading = true;
          _selectedLanguageName = language;
        });
        
        // Visual feedback
        ScaffoldMessenger.of(context).clearSnackBars();
        
        // Survives this screen being rebuilt by the language change (#77).
        _pickInProgress.value = language;
        
        try {
          // Get current language before change
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          final previousLanguage = languageProvider.language;
          // Read before any await: the language change below can unmount
          // this screen, and a lookup through its context would then throw.
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          // An instructor whose kind is not saved yet answers «How do you
          // teach?» next (owner, 2026-09-30: language comes right after the
          // email code for instructors too).
          final uid = authProvider.user?.id;
          final pendingInstructor = authProvider.user?.signupRole == null &&
              uid != null &&
              await SignupIntent.read(uid) == 'instructor';
          
          // Update language provider
          print('🔄 [LANGUAGE SCREEN] Setting language to: $code');
          await languageProvider.setLanguage(code);
          
          // Verify language was set correctly
          print('✅ [LANGUAGE SCREEN] Language set to: ${languageProvider.language}');
          
          // Update auth provider
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
          
          // The live navigator, not this screen's: if the language changed,
          // this screen's context belongs to the app that was thrown away.
          final navigator = navigatorKey.currentState;
          if (navigator != null && navigator.mounted) {
            // Pop all routes except first one
            navigator.popUntil((route) => route.isFirst);
            
            print('🔍 [LANGUAGE SCREEN] Current language before navigation: ${languageProvider.language}');
            print('🔍 [LANGUAGE SCREEN] About to navigate to StateSelectionScreen');
            
            // Use pushReplacement with unique key to force rebuild
            navigator.pushReplacement(
              PageRouteBuilder(
                settings: RouteSettings(
                  name: 'state_selection_${code}_${DateTime.now().millisecondsSinceEpoch}'
                ),
                // An instructor picks their teaching state inside the
                // registration wizard (instructors plan v2 §4.3), not here.
                pageBuilder: (context, animation1, animation2) => pendingInstructor
                    ? const InstructorKindScreen()
                    : authProvider.user?.isSigningUpAsInstructor == true
                        ? const InstructorRegistrationScreen()
                        : StateSelectionScreen(
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
          // The overlay used to stay up for good after a failure. Clear it,
          // here and — through the listener — on a copy built mid-pick.
          if (mounted) setState(() => _isLoading = false);
          // Show error snackbar, through the live app (see above)
          final messengerContext = navigatorKey.currentContext;
          if (messengerContext != null) {
            ScaffoldMessenger.maybeOf(messengerContext)?.showSnackBar(
              SnackBar(
                content: Text('Error selecting language: $e'), // Error message in English
                backgroundColor: AppColors.stop,
              ),
            );
          }
        } finally {
          _pickInProgress.value = null;
        }
      },
    );
  }
}
