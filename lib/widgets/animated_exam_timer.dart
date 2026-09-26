import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/exam_timer_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';

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
    return ValueListenableBuilder<DesignVariant>(
      valueListenable: designVariant,
      builder: (context, selected, _) => ValueListenableBuilder<Duration?>(
        valueListenable: debugTimerPreview,
        builder: (context, preview, _) => Consumer<ExamTimerProvider>(
      builder: (context, timerProvider, child) {
        // The debug preview only ever changes what is drawn; the provider,
        // and so the exam, keep their real time.
        final remaining = preview ?? timerProvider.remainingTime;
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        final timeText =
            "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

        final bool isCritical = remaining <= _critical;
        final bool isLow = remaining <= _low;

        final Color foreground = isCritical
            ? AppColors.stop
            : isLow
                ? AppColors.warn
                : AppColors.ink;

        // Bare text, no pill. The countdown sits in the middle of the app bar
        // with a back arrow on one side and two actions on the other — a
        // filled capsule there reads as a fourth control, and the app bar
        // already separates itself from the page with a hairline. Colour is
        // the only thing that changes as time runs out.
        return Semantics(
          liveRegion: isLow,
          label: '$minutes мин $seconds сек',
          child: _buildFace(
            context,
            selected,
            timeText,
            foreground,
            isLow: isLow,
            isCritical: isCritical,
          ),
        );
      },
        ),
      ),
    );
  }

  Widget _buildFace(
    BuildContext context,
    DesignVariant variant,
    String timeText,
    Color foreground, {
    required bool isLow,
    required bool isCritical,
  }) {
    final tokens = VariantTokens.of(variant);
    final duration = AppMotion.duration(context, AppMotion.base);

    switch (variant) {
      case DesignVariant.refined:
        return AnimatedDefaultTextStyle(
          duration: duration,
          curve: AppMotion.enter,
          style: AppTypography.timer.copyWith(color: foreground),
          child: Text(timeText),
        );

      case DesignVariant.boldA:
        // Signal: the countdown is the hero of the bar. Once time is short it
        // gains a surface in its own semantic colour, so the state reads from
        // across the room — not just the digits.
        final Color surface = isCritical
            ? AppColors.stopSurface
            : isLow
                ? AppColors.warnSurface
                : AppColors.paper.withValues(alpha: 0);
        return AnimatedContainer(
          duration: duration,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x1,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(tokens.chip),
          ),
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: AppMotion.enter,
            style: AppTypography.timer.copyWith(
              fontSize: 26,
              height: 30 / 26,
              color: foreground,
              fontVariations: const [FontVariation('wght', 800)],
            ),
            child: Text(timeText),
          ),
        );

      case DesignVariant.bento:
        // Bento: the countdown is a pill — ink while time is ample, then the
        // pill itself turns amber and red. White on each passes as large text.
        final Color fill = isCritical
            ? AppColors.stop
            : isLow
                ? AppColors.warn
                : AppColors.ink;
        return AnimatedContainer(
          duration: duration,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x1 + 2,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(tokens.chip),
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

      case DesignVariant.boldB:
        // Ledger: small and exact. A clock glyph joins the digits only when
        // time is short, so colour is never the sole signal.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.crisp,
              child: isLow
                  ? Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.x1),
                      child: AppIcons.icon(
                        AppIcons.clock,
                        size: 16,
                        color: foreground,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            AnimatedDefaultTextStyle(
              duration: AppMotion.duration(context, AppMotion.fast),
              curve: AppMotion.crisp,
              style: AppTypography.timer.copyWith(
                // 20/700 keeps it "large text" for WCAG, which amber on
                // paper (4.2:1) needs.
                fontSize: 20,
                height: 24 / 20,
                letterSpacing: 0.2,
                color: foreground,
                fontVariations: const [FontVariation('wght', 700)],
              ),
              child: Text(timeText),
            ),
          ],
        );
    }
  }
}
