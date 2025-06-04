import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/practice_provider.dart';
import 'practice_question_screen.dart';

class PracticeResultScreen extends StatefulWidget {
  @override
  _PracticeResultScreenState createState() => _PracticeResultScreenState();
}

class _PracticeResultScreenState extends State<PracticeResultScreen> with TickerProviderStateMixin {
  late AnimationController _iconAnimationController;
  late AnimationController _cardAnimationController;
  late AnimationController _buttonsAnimationController;
  late AnimationController _scaleController;

  late Animation<double> _iconScaleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _buttonsSlideAnimation;
  late Animation<double> _buttonsFadeAnimation;
  late Animation<double> _buttonScaleAnimation;

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
    _buttonsAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 100),
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

    _buttonsSlideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _buttonsAnimationController,
      curve: Curves.easeOut,
    ));

    _buttonsFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonsAnimationController,
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
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) _iconAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) _cardAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) _buttonsAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _cardAnimationController.dispose();
    _buttonsAnimationController.dispose();
    _scaleController.dispose();
    super.dispose();
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
    
    // Format elapsed time
    final elapsedTime = practice.elapsedTime;
    final minutes = elapsedTime.inMinutes;
    final seconds = elapsedTime.inSeconds % 60;
    final timeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Результат',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Return to test screen
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            // Reset practice
            practiceProvider.cancelPractice();
          },
        ),
      ),
      body: Container(
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
                  timeText,
                  isPassed,
                ),
                
                SizedBox(height: 40),
                
                // Enhanced action buttons
                _buildAnimatedActionButtons(practiceProvider),
                
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
              child: Icon(
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

  Widget _buildEnhancedStatsCard(int correctAnswers, int incorrectAnswers, String timeText, bool isPassed) {
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
                          label: 'Вірних',
                          color: Colors.green,
                        ),
                        _buildStatChip(
                          icon: Icons.cancel,
                          value: incorrectAnswers.toString(),
                          label: 'Невірних',
                          color: Colors.red,
                        ),
                        _buildStatChip(
                          icon: Icons.timer,
                          value: timeText,
                          label: 'Час',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      isPassed ? 'Тест складено' : 'Тест не складено',
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

  Widget _buildAnimatedActionButtons(PracticeProvider practiceProvider) {
    return AnimatedBuilder(
      animation: _buttonsAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _buttonsSlideAnimation.value),
          child: Opacity(
            opacity: _buttonsFadeAnimation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEnhancedActionButton(
                  icon: Icons.error_outline,
                  title: 'Мої помилки',
                  onTap: () {
                    // Show mistakes (could navigate to a dedicated screen)
                  },
                  cardType: 4, // Red gradient
                ),
                
                SizedBox(height: 8),
                
                _buildEnhancedActionButton(
                  icon: Icons.assignment,
                  title: 'Наступний білет',
                  onTap: () {
                    // Reset and start a new practice
                    practiceProvider.cancelPractice();
                    practiceProvider.startNewPractice();
                    
                    // Navigate to practice screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PracticeQuestionScreen(),
                      ),
                    );
                  },
                  cardType: 0, // Blue gradient
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required int cardType,
  }) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) => _scaleController.reverse(),
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _buttonScaleAnimation,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: _getActionButtonGradient(cardType),
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
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white.withOpacity(0.3),
              highlightColor: Colors.white.withOpacity(0.2),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (cardType == 0 ? Colors.blue : Colors.red).shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: cardType == 0 ? Colors.blue : Colors.red,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
