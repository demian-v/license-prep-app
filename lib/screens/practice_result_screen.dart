import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/practice_provider.dart';
import '../providers/language_provider.dart';
import '../providers/state_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/progress_provider.dart';
import '../services/analytics_service.dart';
import '../localization/app_localizations.dart';
import 'practice_question_screen.dart';

class PracticeResultScreen extends StatefulWidget {
  @override
  _PracticeResultScreenState createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen> with TickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late AnimationController _cardAnimationController;

  late Animation<double> _iconScaleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _iconAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    // Setup animations
    _iconScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.elasticOut,
    ));

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

    // Start animations with delays
    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _iconAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) _cardAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  // Helper method to get custom result icon asset path based on result state
  String? _getResultIconAsset(bool isPassed) {
    return isPassed 
      ? 'assets/images/success_fail/success.png'
      : 'assets/images/success_fail/fail.png';
  }

  // Helper method to get gradient for result
  LinearGradient _getResultGradient(bool isPassed) {
    if (isPassed) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.green.shade100,
          Colors.green.shade50,
        ],
        stops: [0.0, 1.0],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.orange.shade100,
          Colors.orange.shade50,
        ],
        stops: [0.0, 1.0],
      );
    }
  }

  // Helper method to get gradient for action buttons
  LinearGradient _getActionButtonGradient(int cardType) {
    switch(cardType) {
      case 0: // Next ticket - blue
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
          stops: [0.0, 1.0],
        );
      case 4: // Mistakes - red
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.red.shade50.withOpacity(0.4)],
          stops: [0.0, 1.0],
        );
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50.withOpacity(0.4)],
          stops: [0.0, 1.0],
        );
    }
  }

  /// Analytics method for practice finished event
  Future<void> _logPracticeFinished(String completionMethod) async {
    final practiceProvider = Provider.of<PracticeProvider>(context, listen: false);
    final practice = practiceProvider.currentPractice;
    
    if (practice != null) {
      // Get providers for analytics
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      
      // Calculate analytics parameters
      final practiceId = 'practice_${practice.startTime.millisecondsSinceEpoch}';
      final finalScore = practice.correctAnswersCount;
      final totalQuestions = practice.answeredQuestionsCount;
      final correctAnswers = practice.correctAnswersCount;
      final incorrectAnswers = practice.incorrectAnswersCount;
      final practicePassed = practice.isPassed;
      final timeSpentSeconds = practice.elapsedTime.inSeconds;
      final state = authProvider.user?.state ?? stateProvider.selectedState?.id ?? 'IL';
      final language = languageProvider.language;
      final licenseType = progressProvider.progress.selectedLicense ?? 'driver';
      
      // Log practice finished analytics event
      await analyticsService.logPracticeFinished(
        practiceId: practiceId,
        finalScore: finalScore,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        incorrectAnswers: incorrectAnswers,
        practicePassed: practicePassed,
        timeSpentSeconds: timeSpentSeconds,
        completionMethod: completionMethod,
        state: state,
        language: language,
        licenseType: licenseType,
      );
      
      print('📊 Analytics: practice_finished logged (practice_id: $practiceId, score: $correctAnswers/$totalQuestions, passed: $practicePassed, method: $completionMethod)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final practiceProvider = Provider.of<PracticeProvider>(context);
    final practice = practiceProvider.currentPractice;
    
    if (practice == null) {
      // If no practice data, navigate back to test screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
      
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final correctAnswers = practice.correctAnswersCount;
    final totalAnswered = practice.answeredQuestionsCount;
    final incorrectAnswers = practice.incorrectAnswersCount;
    final isPassed = practice.isPassed;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('result'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            // Log analytics before navigation
            await _logPracticeFinished('back_arrow');
            
            // Return to test screen
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            // Reset practice
            practiceProvider.cancelPractice();
          },
        ),
      ),
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50.withOpacity(0.3),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 20),
                      
                      // Animated result icon
                      _buildAnimatedResultIcon(isPassed),
                      
                      SizedBox(height: 32),
                      
                      // Enhanced stats card
                      _buildEnhancedStatsCard(
                        correctAnswers,
                        incorrectAnswers,
                        isPassed,
                      ),
                      
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom button area - same size as Skip button, centered
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6, // Same width as Skip button
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)], // Same blue as Skip button
                    ),
                    borderRadius: BorderRadius.circular(30),
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
                      onTap: () async {
                        // Log analytics before navigation
                        await _logPracticeFinished('back_to_tests_button');
                        
                        // Cancel current practice
                        practiceProvider.cancelPractice();
                        
                        // Navigate back to test screen (home)
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context).translate('back_to_tests'),
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedResultIcon(bool isPassed) {
    return Center(
      child: AnimatedBuilder(
        animation: _iconAnimationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _iconScaleAnimation.value,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getResultGradient(isPassed),
                boxShadow: [
                  BoxShadow(
                    color: (isPassed ? Colors.green : Colors.orange).withOpacity(0.3),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: _getResultIconAsset(isPassed) != null
                  ? Image.asset(
                      _getResultIconAsset(isPassed)!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to Material icon if asset fails to load
                        debugPrint('❌ PracticeResultScreen: Failed to load result icon: ${_getResultIconAsset(isPassed)}');
                        return Icon(
                          isPassed ? Icons.emoji_events : Icons.block,
                          color: isPassed ? Colors.amber.shade700 : Colors.red.shade600,
                          size: 80,
                        );
                      },
                    )
                  : Icon(
                      isPassed ? Icons.emoji_events : Icons.block,
                      color: isPassed ? Colors.amber.shade700 : Colors.red.shade600,
                      size: 80,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedStatsCard(int correctAnswers, int incorrectAnswers, bool isPassed) {
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
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.grey.shade50.withOpacity(0.4)],
                  stops: [0.0, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 0,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Enhanced statistics row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatChip(
                          icon: Icons.check_circle,
                          value: correctAnswers.toString(),
                          label: AppLocalizations.of(context).translate('correct'),
                          color: Colors.green,
                        ),
                        _buildStatChip(
                          icon: Icons.cancel,
                          value: incorrectAnswers.toString(),
                          label: AppLocalizations.of(context).translate('incorrect'),
                          color: Colors.red,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      isPassed 
                          ? AppLocalizations.of(context).translate('practice_passed')
                          : AppLocalizations.of(context).translate('practice_not_passed'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isPassed ? Colors.green.shade700 : Colors.red.shade700,
                      ),
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

  Widget _buildStatChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

}
