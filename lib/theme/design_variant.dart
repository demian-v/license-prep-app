import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';
import 'app_motion.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Three live presentations of Тесты and Экзамен, compared on device before
/// one is chosen. Presentation only: every variant runs the same handlers.
///
///   * [refined] — direction A, tuned. Same structure, stricter rhythm.
///   * [boldA]   — "Signal". Display-weight hero, deeper blue, springier.
///   * [boldB]   — "Ledger". Ink on paper, list-first, crisp and fast.
///   * [bento]   — "Bento". Refined's structure in a dashboard's language:
///     borderless bento cards, pill controls, a gradient hero, a dark card.
enum DesignVariant { refined, boldA, boldB, bento }

extension DesignVariantLabel on DesignVariant {
  String get label {
    switch (this) {
      case DesignVariant.refined:
        return 'Refined';
      case DesignVariant.boldA:
        return 'Signal';
      case DesignVariant.boldB:
        return 'Ledger';
      case DesignVariant.bento:
        return 'Bento';
    }
  }
}

/// The variant being shown. Only the debug switcher ever changes it, so a
/// release build always renders [DesignVariant.refined].
final ValueNotifier<DesignVariant> designVariant =
    ValueNotifier<DesignVariant>(DesignVariant.refined);

/// Debug-only display override for the exam countdown, so the amber and red
/// states can be inspected without waiting out an hour. Read by
/// `AnimatedExamTimer` for rendering only; the exam's real timer is untouched.
final ValueNotifier<Duration?> debugTimerPreview =
    ValueNotifier<Duration?>(null);

/// Per-variant radii and motion. Every value resolves to an [AppRadius] or
/// [AppMotion] token — a variant changes the scale, never invents a number.
class VariantTokens {
  const VariantTokens._({
    required this.card,
    required this.button,
    required this.chip,
    required this.bar,
    required this.state,
    required this.reveal,
    required this.swap,
    required this.curve,
    required this.pressScale,
  });

  /// Cards and option surfaces.
  final double card;

  /// Buttons.
  final double button;

  /// Chips, pills, keys.
  final double chip;

  /// The floating tab bar.
  final double bar;

  /// Selection and press feedback.
  final Duration state;

  /// Correct/wrong verdict.
  final Duration reveal;

  /// Question-to-question transition.
  final Duration swap;

  final Curve curve;
  final double pressScale;

  static const VariantTokens _refined = VariantTokens._(
    card: AppRadius.lg,
    button: AppRadius.md,
    chip: AppRadius.sm,
    bar: AppRadius.xl,
    state: AppMotion.fast,
    reveal: AppMotion.base,
    swap: AppMotion.base,
    curve: AppMotion.enter,
    pressScale: 0.98,
  );

  static const VariantTokens _signal = VariantTokens._(
    card: AppRadius.xl,
    button: AppRadius.lg,
    chip: AppRadius.md,
    bar: AppRadius.xxl,
    state: AppMotion.base,
    reveal: AppMotion.base,
    swap: AppMotion.base,
    curve: AppMotion.spring,
    pressScale: 0.97,
  );

  static const VariantTokens _ledger = VariantTokens._(
    card: AppRadius.sm,
    button: AppRadius.sm,
    chip: AppRadius.xs,
    bar: AppRadius.md,
    state: AppMotion.instant,
    reveal: AppMotion.fast,
    swap: AppMotion.fast,
    curve: AppMotion.crisp,
    pressScale: 0.99,
  );

  /// Bento: large soft cards, every control a pill. Presses lift rather
  /// than shrink, the touch version of a hover lift.
  static const VariantTokens _bento = VariantTokens._(
    card: AppRadius.xl,
    button: AppRadius.pill,
    chip: AppRadius.pill,
    bar: AppRadius.pill,
    state: AppMotion.fast,
    reveal: AppMotion.base,
    swap: AppMotion.base,
    curve: AppMotion.enter,
    pressScale: 1,
  );

  static VariantTokens of(DesignVariant variant) {
    switch (variant) {
      case DesignVariant.refined:
        return _refined;
      case DesignVariant.boldA:
        return _signal;
      case DesignVariant.boldB:
        return _ledger;
      case DesignVariant.bento:
        return _bento;
    }
  }
}

/// Wraps a screen with the variant switcher — in debug builds only.
///
/// `kDebugMode` is a compile-time constant, so in profile and release builds
/// this returns [child] untouched and the switcher is tree-shaken away.
///
/// Tap the edge tab to cycle variants; long-press it to cycle the exam timer
/// preview (off → 4:59 → 0:59 → off).
class DesignVariantSwitcher extends StatefulWidget {
  const DesignVariantSwitcher({super.key, required this.child});

  final Widget child;

  @override
  State<DesignVariantSwitcher> createState() => _DesignVariantSwitcherState();
}

class _DesignVariantSwitcherState extends State<DesignVariantSwitcher> {
  static const String _prefsKey = 'debug_design_variant';
  static bool _restored = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode && !_restored) {
      _restored = true;
      SharedPreferences.getInstance().then((prefs) {
        final saved = prefs.getString(_prefsKey);
        for (final v in DesignVariant.values) {
          if (v.name == saved) designVariant.value = v;
        }
      });
    }
  }

  void _cycleVariant() {
    const values = DesignVariant.values;
    final next = values[(designVariant.value.index + 1) % values.length];
    designVariant.value = next;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_prefsKey, next.name));
  }

  void _cycleTimerPreview() {
    const low = Duration(minutes: 4, seconds: 59);
    const critical = Duration(seconds: 59);
    final current = debugTimerPreview.value;
    debugTimerPreview.value = current == null
        ? low
        : current == low
            ? critical
            : null;
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 0,
          top: MediaQuery.of(context).size.height * 0.44,
          // The exam route wraps its Scaffold in this switcher, so the tab
          // needs its own Material for text to render without the debug
          // "no Material" underline.
          child: Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<DesignVariant>(
            valueListenable: designVariant,
            builder: (context, variant, _) {
              return ValueListenableBuilder<Duration?>(
                valueListenable: debugTimerPreview,
                builder: (context, preview, _) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cycleVariant,
                    onLongPress: _cycleTimerPreview,
                    // The visible tab is thin so it covers little content; the
                    // transparent inset widens the hit target to 44pt.
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.x6 - 2),
                      child: Container(
                        width: 22,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.72),
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(AppRadius.sm),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            preview == null
                                ? variant.label
                                : '${variant.label} ${preview.inMinutes}:${(preview.inSeconds % 60).toString().padLeft(2, '0')}',
                            maxLines: 1,
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              color: AppColors.onSignal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          ),
        ),
      ],
    );
  }
}
