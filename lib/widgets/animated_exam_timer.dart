import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../providers/exam_timer_provider.dart';

class AnimatedExamTimer extends StatefulWidget {
  const AnimatedExamTimer({
    Key? key,
  }) : super(key: key);
  
  @override
  _AnimatedExamTimerState createState() => _AnimatedExamTimerState();
}

class _AnimatedExamTimerState extends State<AnimatedExamTimer> 
    with SingleTickerProviderStateMixin {
  late AnimationController _timerAnimationController;
  late Animation<double> _timerPulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }
  
  void _initializeAnimation() {
    _timerAnimationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    
    _timerPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _timerAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _timerAnimationController.repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _timerAnimationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ExamTimerProvider>(
      builder: (context, timerProvider, child) {
        final remainingTime = timerProvider.remainingTime;
        final minutes = remainingTime.inMinutes;
        final seconds = remainingTime.inSeconds % 60;
        final timeText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        bool isCritical = remainingTime.inMinutes < 5;
        
        // Update animation speed for critical time
        if (isCritical) {
          _timerAnimationController.duration = Duration(milliseconds: 800);
        } else {
          _timerAnimationController.duration = Duration(seconds: 2);
        }
        
        return AnimatedBuilder(
          animation: _timerPulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: isCritical ? _timerPulseAnimation.value : 1.0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: _getTimerGradient(remainingTime),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'monospace',
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  LinearGradient _getTimerGradient(Duration remainingTime) {
    Color startColor = Colors.white;
    Color endColor;
    
    if (remainingTime.inMinutes > 30) {
      endColor = Colors.green.shade50.withOpacity(0.6);
    } else if (remainingTime.inMinutes > 10) {
      endColor = Colors.orange.shade50.withOpacity(0.6);
    } else {
      endColor = Colors.red.shade50.withOpacity(0.8);
    }
    
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [startColor, endColor],
      stops: [0.0, 1.0],
    );
  }
}
