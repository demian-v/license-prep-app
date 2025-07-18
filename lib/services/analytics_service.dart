import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// GA4-compliant AnalyticsService that provides proper Firebase Analytics integration
/// with DebugView support and proper stream configuration
class AnalyticsService {
  // Singleton instance
  static final AnalyticsService _instance = AnalyticsService._internal();
  
  // Factory constructor to return the same instance every time
  factory AnalyticsService() => _instance;
  
  // Private constructor
  AnalyticsService._internal();
  
  // Firebase Analytics instance
  late FirebaseAnalytics _analytics;
  late FirebaseAnalyticsObserver _observer;
  
  // GA4 Configuration
  static const String _measurementId = 'G-8TTZX72V8P';
  static const String _streamId = '10381265395';
  static const String _firebaseAppId = '1:987638335534:android:f641ffe1a4f736717937bf';
  String? _clientId;
  String? _currentLanguage;
  String? _currentUserId;
  Map<String, dynamic> _userProperties = {};
  
  bool _isInitialized = false;
  bool _isAnalyticsEnabled = true;
  
  /// Initialize Firebase Analytics with GA4 compliance
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Ensure Firebase is initialized
      await Firebase.initializeApp();
      
      // Initialize Firebase Analytics
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics);
      
      // Generate or retrieve client ID for internal tracking
      _clientId = await _getOrGenerateClientId();
      _currentLanguage = 'en-us'; // Default, will be updated
      
      // Set only non-reserved default event parameters
      await _analytics.setDefaultEventParameters({
        'app_version': '1.0.0',
        'platform': defaultTargetPlatform.name,
      });
      
      // Enable analytics collection
      await _analytics.setAnalyticsCollectionEnabled(true);
      
      _isInitialized = true;
      
      // Enhanced debug logging for GA4
      if (kDebugMode) {
        debugPrint('🔍 Firebase Analytics Debug Information:');
        debugPrint('📱 App Package: com.example.license_prep_app');
        debugPrint('🔧 Measurement ID: $_measurementId');
        debugPrint('🔢 Stream ID: $_streamId');
        debugPrint('🆔 Firebase App ID: $_firebaseAppId');
        debugPrint('🐛 Debug Mode: ${kDebugMode ? 'ENABLED' : 'DISABLED'}');
        debugPrint('📊 Analytics collection enabled: $_isAnalyticsEnabled');
        debugPrint('🔧 To enable DebugView, run: adb shell setprop debug.firebase.analytics.app com.example.license_prep_app');
        debugPrint('🔍 Then restart your app and check Firebase Console > Analytics > DebugView');
      }
      
      // Log app start event
      await logAppOpened();
      
    } catch (e) {
      debugPrint('❌ Error initializing Firebase Analytics: $e');
      // Don't throw - analytics should fail gracefully
    }
  }
  
  
  /// Generate or retrieve client ID
  Future<String> _getOrGenerateClientId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? clientId = prefs.getString('ga4_client_id');
      
      if (clientId == null) {
        // Generate new client ID
        final random = Random();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        clientId = '${timestamp}.${random.nextInt(999999999)}';
        await prefs.setString('ga4_client_id', clientId);
        debugPrint('🆔 Generated new GA4 client ID: $clientId');
      } else {
        debugPrint('🆔 Retrieved existing GA4 client ID: $clientId');
      }
      
      return clientId;
    } catch (e) {
      debugPrint('❌ Error managing client ID: $e');
      // Fallback to timestamp-based ID
      return '${DateTime.now().millisecondsSinceEpoch}.${Random().nextInt(999999)}';
    }
  }
  
  /// Get screen resolution
  Future<String> _getScreenResolution() async {
    try {
      // This would need to be called from a widget context
      // For now, return a default value
      return '1920x1080';
    } catch (e) {
      return '1920x1080';
    }
  }
  
  /// Get Firebase Analytics Observer for navigation tracking
  FirebaseAnalyticsObserver get observer {
    _checkInitialization();
    return _observer;
  }
  
  /// Enable or disable analytics collection
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    if (!_isInitialized) return;
    
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
      _isAnalyticsEnabled = enabled;
      debugPrint('📊 GA4 analytics collection ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      debugPrint('❌ Error setting analytics collection: $e');
    }
  }
  
  /// Check if analytics is enabled
  bool get isAnalyticsEnabled => _isAnalyticsEnabled;
  
  /// Log a custom event with GA4 compliance
  Future<void> logEvent(String eventName, [Map<String, dynamic>? parameters]) async {
    if (!_isInitialized || !_isAnalyticsEnabled) return;
    
    try {
      // Send parameters as-is without adding reserved GA4 parameters
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
      
      debugPrint('📊 Event logged: $eventName');
      if (parameters != null) {
        debugPrint('   Parameters: $parameters');
      }
    } catch (e) {
      debugPrint('❌ Error logging event $eventName: $e');
    }
  }
  
  /// Set user property (GA4 compliant)
  Future<void> setUserProperty(String name, String? value) async {
    if (!_isInitialized || !_isAnalyticsEnabled) return;
    
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('👤 GA4 User property set: $name = $value');
    } catch (e) {
      debugPrint('❌ Error setting GA4 user property $name: $e');
    }
  }
  
  /// Set user ID (GA4 compliant)
  Future<void> setUserId(String? userId) async {
    if (!_isInitialized || !_isAnalyticsEnabled) return;
    
    try {
      _currentUserId = userId;
      await _analytics.setUserId(id: userId);
      debugPrint('👤 GA4 User ID set: $userId');
    } catch (e) {
      debugPrint('❌ Error setting GA4 user ID: $e');
    }
  }
  
  // MARK: - Authentication Events (GA4 Compliant)
  
  /// Log user login event
  Future<void> logLogin([String? method]) async {
    await logEvent('login', method != null ? {'method': method} : null);
  }
  
  /// Log user signup event
  Future<void> logSignUp([String? method]) async {
    await logEvent('sign_up', method != null ? {'method': method} : null);
  }
  
  // MARK: - Enhanced Signup Journey Events
  
  /// Log when user starts filling the signup form
  Future<void> logSignupFormStarted() async {
    await logEvent('signup_form_started', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'signup_method': 'email',
    });
  }

  /// Log when signup form is successfully submitted
  Future<void> logSignupFormCompleted({
    int? timeSpentSeconds,
    bool? hasFormErrors,
    String? validationErrors,
  }) async {
    await logEvent('signup_form_completed', {
      'signup_method': 'email',
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      if (hasFormErrors != null) 'had_form_errors': hasFormErrors.toString(),
      if (validationErrors != null) 'validation_errors': validationErrors,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log when user account is successfully created
  Future<void> logUserAccountCreated({
    String? userId,
    String? signupMethod,
    bool? hasName,
    bool? emailVerified,
  }) async {
    await logEvent('user_account_created', {
      'signup_method': signupMethod ?? 'email',
      if (hasName != null) 'has_name': hasName.toString(),
      if (emailVerified != null) 'email_verified': emailVerified.toString(),
      'account_type': 'trial',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log when free trial starts
  Future<void> logSignupTrialStarted({
    String? userId,
    String? signupMethod,
    String? trialType,
    int? trialDays,
  }) async {
    await logEvent('signup_trial_started', {
      'signup_method': signupMethod ?? 'email',
      'trial_type': trialType ?? '3_day_free_trial',
      'trial_duration_days': trialDays ?? 3,
      'trial_price_after': '2.50',
      'currency': 'USD',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log signup failure event
  Future<void> logSignupFailed({
    String? errorType,
    String? errorMessage,
    String? signupMethod,
  }) async {
    await logEvent('signup_failed', {
      'signup_method': signupMethod ?? 'email',
      if (errorType != null) 'error_type': errorType,
      if (errorMessage != null) 'error_message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  /// Log password reset event
  Future<void> logPasswordReset() async {
    await logEvent('password_reset');
  }
  
  // MARK: - Enhanced Password Reset Journey Events
  
  /// Log when user starts password reset flow
  Future<void> logPasswordResetFormStarted() async {
    await logEvent('password_reset_form_started', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'reset_method': 'email',
    });
  }

  /// Log when reset email is successfully sent
  Future<void> logPasswordResetEmailRequested({
    String? emailDomain,
    int? timeSpentSeconds,
    bool? hasFormErrors,
    String? validationErrors,
  }) async {
    await logEvent('password_reset_email_requested', {
      'reset_method': 'email',
      if (emailDomain != null) 'email_domain': emailDomain,
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      if (hasFormErrors != null) 'had_form_errors': hasFormErrors.toString(),
      if (validationErrors != null) 'validation_errors': validationErrors,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log when user resends reset email
  Future<void> logPasswordResetEmailResent({
    String? emailDomain,
    int? timeSinceFirstRequest,
  }) async {
    await logEvent('password_reset_email_resent', {
      'reset_method': 'email',
      if (emailDomain != null) 'email_domain': emailDomain,
      if (timeSinceFirstRequest != null) 'time_since_first_request': timeSinceFirstRequest,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log when user accesses reset link
  Future<void> logPasswordResetLinkAccessed({
    int? timeSinceEmailSent,
    bool? validLink,
  }) async {
    await logEvent('password_reset_link_accessed', {
      'reset_method': 'email',
      if (timeSinceEmailSent != null) 'time_since_email_sent': timeSinceEmailSent,
      if (validLink != null) 'valid_link': validLink.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log successful password reset completion
  Future<void> logPasswordResetCompleted({
    int? timeSpentOnForm,
    int? validationAttempts,
    bool? strongPassword,
  }) async {
    await logEvent('password_reset_completed', {
      'reset_method': 'email',
      if (timeSpentOnForm != null) 'time_spent_on_form': timeSpentOnForm,
      if (validationAttempts != null) 'validation_attempts': validationAttempts,
      if (strongPassword != null) 'strong_password': strongPassword.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log failures at any stage
  Future<void> logPasswordResetFailed({
    String? failureStage,
    String? errorType,
    String? errorMessage,
  }) async {
    await logEvent('password_reset_failed', {
      'reset_method': 'email',
      if (failureStage != null) 'failure_stage': failureStage,
      if (errorType != null) 'error_type': errorType,
      if (errorMessage != null) 'error_message': errorMessage,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // MARK: - Language Change Events
  
  /// Log when user opens language selection interface
  Future<void> logLanguageSelectionStarted({
    String? selectionContext,
    String? currentLanguage,
  }) async {
    await logEvent('language_selection_started', {
      'selection_context': selectionContext ?? 'unknown',
      'current_language': currentLanguage ?? 'unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log successful language change
  Future<void> logLanguageChanged({
    String? selectionContext,
    String? previousLanguage,
    String? newLanguage,
    String? languageName,
    int? timeSpentSeconds,
  }) async {
    await logEvent('language_changed', {
      'selection_context': selectionContext ?? 'unknown',
      'previous_language': previousLanguage ?? 'unknown',
      'new_language': newLanguage ?? 'unknown',
      'language_name': languageName ?? 'unknown',
      if (timeSpentSeconds != null) 'time_spent_seconds': timeSpentSeconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Log language change failure
  Future<void> logLanguageChangeFailed({
    String? selectionContext,
    String? targetLanguage,
    String? errorType,
    String? errorMessage,
  }) async {
    await logEvent('language_change_failed', {
      'selection_context': selectionContext ?? 'unknown',
      'target_language': targetLanguage ?? 'unknown',
      'error_type': errorType ?? 'unknown_error',
      'error_message': errorMessage ?? 'unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }
  
  // MARK: - Learning Events
  
  /// Log quiz start event
  Future<void> logQuizStart({
    String? quizId,
    String? quizType,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('quiz_start', {
      if (quizId != null) 'quiz_id': quizId,
      if (quizType != null) 'quiz_type': quizType,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log quiz completion event
  Future<void> logQuizComplete({
    String? quizId,
    String? quizType,
    int? score,
    int? totalQuestions,
    int? correctAnswers,
    int? timeSpent,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('quiz_complete', {
      if (quizId != null) 'quiz_id': quizId,
      if (quizType != null) 'quiz_type': quizType,
      if (score != null) 'score': score,
      if (totalQuestions != null) 'total_questions': totalQuestions,
      if (correctAnswers != null) 'correct_answers': correctAnswers,
      if (timeSpent != null) 'time_spent_seconds': timeSpent,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log exam start event
  Future<void> logExamStart({
    String? examId,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('exam_start', {
      if (examId != null) 'exam_id': examId,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log exam completion event
  Future<void> logExamComplete({
    String? examId,
    int? score,
    int? totalQuestions,
    int? correctAnswers,
    int? timeSpent,
    bool? passed,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('exam_complete', {
      if (examId != null) 'exam_id': examId,
      if (score != null) 'score': score,
      if (totalQuestions != null) 'total_questions': totalQuestions,
      if (correctAnswers != null) 'correct_answers': correctAnswers,
      if (timeSpent != null) 'time_spent_seconds': timeSpent,
      if (passed != null) 'passed': passed.toString(),
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log practice session start event
  Future<void> logPracticeStart({
    String? sessionId,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('practice_start', {
      if (sessionId != null) 'session_id': sessionId,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log practice session completion event
  Future<void> logPracticeComplete({
    String? sessionId,
    int? questionsAnswered,
    int? correctAnswers,
    int? timeSpent,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('practice_complete', {
      if (sessionId != null) 'session_id': sessionId,
      if (questionsAnswered != null) 'questions_answered': questionsAnswered,
      if (correctAnswers != null) 'correct_answers': correctAnswers,
      if (timeSpent != null) 'time_spent_seconds': timeSpent,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log question answered event
  Future<void> logQuestionAnswered({
    String? questionId,
    String? questionType,
    bool? isCorrect,
    int? timeSpent,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('question_answered', {
      if (questionId != null) 'question_id': questionId,
      if (questionType != null) 'question_type': questionType,
      if (isCorrect != null) 'is_correct': isCorrect.toString(),
      if (timeSpent != null) 'time_spent_seconds': timeSpent,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log content viewed event
  Future<void> logContentViewed({
    String? contentId,
    String? contentType,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('content_viewed', {
      if (contentId != null) 'content_id': contentId,
      if (contentType != null) 'content_type': contentType,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  // MARK: - User Journey Events
  
  /// Log state selection event
  Future<void> logStateSelected(String state) async {
    await logEvent('state_selected', {'state': state});
    await setUserProperty('user_state', state);
  }
  
  /// Log license type selection event
  Future<void> logLicenseSelected(String licenseType) async {
    await logEvent('license_selected', {'license_type': licenseType});
    await setUserProperty('license_type', licenseType);
  }
  
  
  /// Log subscription viewed event
  Future<void> logSubscriptionViewed() async {
    await logEvent('subscription_viewed');
  }
  
  /// Log subscription purchased event (GA4 purchase event)
  Future<void> logSubscriptionPurchased({
    String? planType,
    double? price,
    String? currency,
  }) async {
    await logEvent('purchase', {
      if (planType != null) 'item_name': planType,
      if (price != null) 'value': price,
      if (currency != null) 'currency': currency,
      'item_category': 'subscription',
    });
    if (planType != null) {
      await setUserProperty('subscription_status', planType);
    }
  }
  
  // MARK: - Engagement Events
  
  /// Log question saved event
  Future<void> logQuestionSaved({
    String? questionId,
    String? questionType,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('question_saved', {
      if (questionId != null) 'question_id': questionId,
      if (questionType != null) 'question_type': questionType,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log question unsaved event
  Future<void> logQuestionUnsaved({
    String? questionId,
    String? questionType,
    String? state,
    String? licenseType,
  }) async {
    await logEvent('question_unsaved', {
      if (questionId != null) 'question_id': questionId,
      if (questionType != null) 'question_type': questionType,
      if (state != null) 'state': state,
      if (licenseType != null) 'license_type': licenseType,
    });
  }
  
  /// Log app opened event
  Future<void> logAppOpened() async {
    await logEvent('app_opened');
  }
  
  /// Log session start event
  Future<void> logSessionStart() async {
    await logEvent('session_start', {
      'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
    });
  }
  
  // MARK: - GA4 User Properties Management
  
  /// Set user properties for a logged-in user (GA4 compliant)
  Future<void> setUserProperties({
    String? userId,
    String? state,
    String? licenseType,
    String? language,
    String? subscriptionStatus,
    String? registrationDate,
  }) async {
    // Update internal tracking
    _currentUserId = userId;
    _currentLanguage = language ?? _currentLanguage;
    
    // Build GA4-compliant user properties
    _userProperties = {
      if (state != null) 'user_state': state,
      if (licenseType != null) 'license_type': licenseType,
      if (language != null) 'language_preference': language,
      if (subscriptionStatus != null) 'subscription_status': subscriptionStatus,
      if (registrationDate != null) 'registration_date': registrationDate,
    };
    
    // Set GA4 user properties according to standards
    if (userId != null) await setUserId(userId);
    if (state != null) await setUserProperty('user_state', state);
    if (licenseType != null) await setUserProperty('license_type', licenseType);
    if (language != null) {
      await setUserProperty('language', language);
      await setUserProperty('language_preference', language);
    }
    if (subscriptionStatus != null) await setUserProperty('subscription_status', subscriptionStatus);
    if (registrationDate != null) await setUserProperty('registration_date', registrationDate);
    
    // Log user properties update
    await logEvent('user_properties_updated', {
      'properties_count': _userProperties.length,
      'has_user_id': userId != null ? 'true' : 'false',
      'has_state': state != null ? 'true' : 'false',
      'has_language': language != null ? 'true' : 'false',
    });
    
    debugPrint('👤 GA4 User properties updated: $_userProperties');
  }
  
  /// Clear user properties on logout
  Future<void> clearUserProperties() async {
    await setUserId(null);
    await setUserProperty('user_state', null);
    await setUserProperty('license_type', null);
    await setUserProperty('subscription_status', null);
    // Keep language preference and registration date
    
    _userProperties.clear();
    _currentUserId = null;
    
    debugPrint('👤 GA4 User properties cleared');
  }
  
  void _checkInitialization() {
    if (!_isInitialized) {
      debugPrint('⚠️ GA4 AnalyticsService not initialized. Some features may not work.');
    }
  }
  
  /// Reset service (useful for testing)
  void reset() {
    _isInitialized = false;
    _isAnalyticsEnabled = true;
    _userProperties.clear();
    _currentUserId = null;
    debugPrint('🔄 GA4 AnalyticsService reset');
  }
}

/// Global instance for easy access throughout the app
final analyticsService = AnalyticsService();
