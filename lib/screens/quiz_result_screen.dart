import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quiz_topic.dart';
import '../localization/app_localizations.dart';
import '../services/analytics_service.dart';
import '../services/service_locator.dart';
import '../providers/state_provider.dart';

class QuizResultScreen extends StatefulWidget {
  final QuizTopic topic;
  final Map<String, bool> answers;
  final bool isTopicMode;
  final String? sessionId;
  final DateTime? startTime;
  
  const QuizResultScreen({
    Key? key,
    required this.topic,
    required this.answers,
    this.isTopicMode = false,
    this.sessionId,
    this.startTime,
  }) : super(key: key);

  @override
  _QuizResultScreenState createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _iconAnimationController;
  late AnimationController _cardAnimationController;

  late Animation<double> _headerFadeAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _headerAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _cardAnimationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    // Setup animations
    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeIn,
    ));

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
    // Start animations with staggered timing
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _headerAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) _iconAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 400), () {
      if (mounted) _cardAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _iconAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  int get _correctAnswers => widget.answers.values.where((result) => result).length;
  int get _totalQuestions => widget.answers.length;
  double get _accuracyPercentage => (_correctAnswers / _totalQuestions) * 100;
  int get _timeSpentSeconds {
    if (widget.startTime != null) {
      return DateTime.now().difference(widget.startTime!).inSeconds;
    }
    return 0;
  }

  Future<void> _trackTopicFinished(String completionMethod) async {
    if (widget.isTopicMode && widget.sessionId != null) {
      final stateProvider = Provider.of<StateProvider>(context, listen: false);
      await serviceLocator.analytics.trackQTopicFinished(
        sessionId: widget.sessionId!,
        stateId: stateProvider.selectedState?.id ?? 'unknown',
        licenseType: 'cdl',
        topicId: widget.topic.id,
        topicName: widget.topic.title,
        correctAnswers: _correctAnswers,
        totalQuestions: _totalQuestions,
        timeSpentSeconds: _timeSpentSeconds,
        completionMethod: completionMethod,
        accuracyPercentage: _accuracyPercentage,
      );
    }
  }

  // Helper method to get gradient for result (always green for quiz success)
  LinearGradient _getResultGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.green.shade100,
        Colors.green.shade50,
      ],
      stops: [0.0, 1.0],
    );
  }

  // Helper method to get gradient for action buttons
  LinearGradient _getActionButtonGradient(int cardType) {
    switch(cardType) {
      case 0: // Next topic - blue
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

  @override
  Widget build(BuildContext context) {
    int totalAnswered = widget.answers.length;
    int correctAnswers = widget.answers.values.where((v) => v).length;
    int incorrectAnswers = totalAnswered - correctAnswers;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('learn_by_topics'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            await _trackTopicFinished('back_arrow');
            Navigator.pop(context);
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
                      SizedBox(height: 8),
                      
                      // Enhanced topic header
                      _buildEnhancedTopicHeader(),
                      
                      SizedBox(height: 24),
                      
                      // Animated result icon
                      _buildAnimatedResultIcon(),
                      
                      SizedBox(height: 32),
                      
                      // Enhanced stats card
                      _buildEnhancedStatsCard(
                        correctAnswers,
                        incorrectAnswers,
                        totalAnswered,
                      ),
                      
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom button area - two buttons side by side
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Left button - Back to Tests
                Expanded(
                  child: _buildActionButton(
                    text: AppLocalizations.of(context).translate('back_to_tests'),
                    onTap: () async {
                      await _trackTopicFinished('back_to_tests');
                      // Navigate back to test screen (home)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Right button - Back to Topics
                Expanded(
                  child: _buildActionButton(
                    text: AppLocalizations.of(context).translate('back_to_topics'),
                    onTap: () async {
                      await _trackTopicFinished('back_to_topics');
                      // Navigate back to topic selection screen (skip the question screen)
                      Navigator.pop(context); // Pop quiz result screen
                      Navigator.pop(context); // Pop quiz question screen to reach topic selection
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTopicHeader() {
    return AnimatedBuilder(
      animation: _headerAnimationController,
      builder: (context, child) {
        return Opacity(
          opacity: _headerFadeAnimation.value,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.blue.shade50.withOpacity(0.2)],
                stops: [0.0, 1.0],
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
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                widget.topic.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedResultIcon() {
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
                gradient: _getResultGradient(),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    spreadRadius: 0,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events,
                color: Colors.amber.shade700,
                size: 80,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedStatsCard(int correctAnswers, int incorrectAnswers, int totalAnswered) {
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
                child: Row(
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
                    _buildStatChip(
                      icon: Icons.quiz,
                      value: totalAnswered.toString(),
                      label: AppLocalizations.of(context).translate('questions'),
                      color: Colors.blue,
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

  Widget _buildActionButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50.withOpacity(0.4)],
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

}
