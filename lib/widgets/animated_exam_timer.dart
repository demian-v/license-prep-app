import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/exam_timer_provider.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

/// The exam countdown.
///
/// This is the one bold element on the exam screen. It was a 12px monospace
/// label in a grey pill — the least prominent thing on a screen whose whole
/// premise is that time is running out.
///
/// Three things changed beyond size:
///
/// * **The perpetual pulse is gone.** The old widget called
///   `repeat(reverse: true)` in `initState` and never stopped it, so an
///   animation controller ran for the full hour of every exam, rebuilding on
///   every frame while the user was trying to read. Ambient motion next to
///   reading content competes with the reading.
/// * **No green.** It previously went green above 30 minutes. Green means one
///   thing in this app now: a correct answer. Ample time is simply the normal
///   state, so it gets normal ink.
/// * **Tabular figures.** Proportional digits make a ticking clock twitch
///   sideways once a second.
///
/// A threshold crossing cross-fades its colour over one [AppMotion.base] —
/// once, never looping — so the change is noticed without the digits ever
/// being hard to read. Reduce Motion makes it instant.
class AnimatedExamTimer extends StatelessWidget {
  const AnimatedExamTimer({super.key});

  /// Under a minute: out of time.
  static const Duration _critical = Duration(minutes: 1);

  /// Under five minutes: start wrapping up.
  static const Duration _low = Duration(minutes: 5);

  @override
  Widget build(BuildContext context) {
    return Consumer<ExamTimerProvider>(
      builder: (context, timerProvider, child) {
        final remaining = timerProvider.remainingTime;
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        final timeText =
            "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

        final bool isCritical = remaining <= _critical;
        final bool isLow = remaining <= _low;

        return Semantics(
          liveRegion: isLow,
          label: '$minutes мин $seconds сек',
          child: _buildFace(
            context,
            timeText,
            isLow: isLow,
            isCritical: isCritical,
          ),
        );
      },
    );
  }

  /// The countdown is a pill — ink while time is ample, then the pill itself
  /// turns amber and red. White on each passes as large text.
  Widget _buildFace(
    BuildContext context,
    String timeText, {
    required bool isLow,
    required bool isCritical,
  }) {
    final Color fill = isCritical
        ? AppColors.stop
        : isLow
            ? AppColors.warn
            : AppColors.ink;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.base),
      curve: AppMotion.enter,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x1 + 2,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
      ),
      child: Text(
        timeText,
        style: AppTypography.timer.copyWith(
          fontSize: 20,
          height: 24 / 20,
          color: AppColors.onSignal,
        ),
      ),
    );
  }
}
