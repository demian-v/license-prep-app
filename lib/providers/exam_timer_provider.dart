import 'dart:async';
import 'package:flutter/material.dart';

class ExamTimerProvider extends ChangeNotifier {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _isActive = false;
  
  Duration get remainingTime => _remainingTime;
  bool get isActive => _isActive;
  bool get isTimeLimitExceeded => _remainingTime.inSeconds <= 0;
  
  void startTimer(Duration initialTime) {
    _remainingTime = initialTime;
    _isActive = true;
    
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        notifyListeners(); // Only timer updates, no exam state changes
      } else {
        // Time's up - stop timer but let ExamProvider handle completion
        stopTimer();
      }
    });
    
    notifyListeners();
  }
  
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
    _isActive = false;
    notifyListeners();
  }
  
  void updateRemainingTime(Duration newTime) {
    _remainingTime = newTime;
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}
