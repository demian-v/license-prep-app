import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'bento_question_parts.dart';

/// The Bento pieces the three result pages share — Экзамен
/// (`exam_result_screen.dart`), Практика (`practice_result_screen.dart`) and
/// Обучение по темам (`quiz_result_screen.dart`). Presentation only: each
/// screen keeps its own analytics and navigation.

/// A pushed page's app bar: the round back button and, beside it, the page's
/// name — left-aligned, one line, shrinking rather than wrapping. [actions]
/// (round buttons, e.g. ⚠) sit on the right.
AppBar bentoHeadingAppBar({
  required String title,
  required VoidCallback onBack,
  List<Widget>? actions,
}) {
  return AppBar(
    toolbarHeight: 64,
    centerTitle: false,
    titleSpacing: AppSpacing.x2,
    backgroundColor: AppColors.field,
    surfaceTintColor: Colors.transparent,
    foregroundColor: AppColors.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: Padding(
      padding: const EdgeInsets.only(left: AppSpacing.x2),
      child: Center(
        child: IconButton(
          style: bentoRoundIconStyle,
          icon: const Icon(SolarIcons.arrowLeftLinear,
              color: AppColors.ink, size: 24),
          onPressed: onBack,
        ),
      ),
    ),
    actions: actions,
    title: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        maxLines: 1,
        style: AppTypography.title.copyWith(
          fontSize: 22,
          height: 28 / 22,
          letterSpacing: -0.4,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    ),
  );
}

/// The result as the page's one hero card (variant B, owner 2026-09-28):
/// the picture inset with rounded corners, the score pill riding its bottom
/// edge — joined by an amber [timeUpLabel] pill when the Экзамен timer ran
/// out — and the verdict centred under it on one line. [tone] carries the
/// meaning: green passed, red not passed.
class BentoVerdictCard extends StatelessWidget {
  const BentoVerdictCard({
    super.key,
    required this.picture,
    required this.title,
    required this.score,
    required this.tone,
    required this.toneSurface,
    this.titleColor = AppColors.ink,
    this.timeUpLabel,
  });

  /// A 4:3 picture — [ResultMemePicture] on the result pages.
  final Widget picture;
  final String title;

  /// The score as shown in the pill, e.g. «95%».
  final String score;
  final Color tone;
  final Color toneSurface;
  final Color titleColor;
  final String? timeUpLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x3,
        AppSpacing.x3,
        AppSpacing.x3,
        AppSpacing.x4 + AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: AspectRatio(aspectRatio: 4 / 3, child: picture),
              ),
              // The pills sit on the picture's bottom edge, ringed in the
              // card's white so they read as lifted off it.
              Positioned(
                left: 0,
                right: 0,
                bottom: -18,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RingedPill(text: score, fg: tone, bg: toneSurface),
                      if (timeUpLabel != null) ...[
                        const SizedBox(width: AppSpacing.x2),
                        _RingedPill(
                          text: timeUpLabel!,
                          fg: AppColors.warn,
                          bg: AppColors.warnSurface,
                          icon: SolarIcons.stopwatchLinear,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x8 - 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: AppTypography.title.copyWith(
                fontSize: 22,
                height: 28 / 22,
                letterSpacing: -0.4,
                color: titleColor,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A fact pill on the verdict picture: coloured by meaning, ringed in white.
class _RingedPill extends StatelessWidget {
  const _RingedPill({
    required this.text,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1 + 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
        border: Border.all(color: AppColors.paper, width: 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: AppSpacing.x1 + 2),
          ],
          Text(
            text,
            maxLines: 1,
            style: AppTypography.label.copyWith(
              fontSize: 15,
              color: fg,
              fontVariations: const [FontVariation('wght', 600)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dark `ink` action pill — «Поделиться» on the result pages, the same
/// look as «Назад к теории» (`traffic_rule_content_screen.dart`).
class BentoInkButton extends StatelessWidget {
  const BentoInkButton({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(BentoTokens.button);
    return PressScale(
      scale: 0.97,
      duration: BentoTokens.state,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: radius,
          boxShadow: AppColors.shadowRaised,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontSize: 16,
                    color: AppColors.onSignal,
                    fontVariations: const [FontVariation('wght', 500)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One figure of the result as a small card: the number first, large and
/// tabular, then what it counts. Colour only where it means something —
/// green for correct, red for wrong; time and totals stay ink.
class BentoStatTile extends StatelessWidget {
  const BentoStatTile({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.color = AppColors.ink,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x4,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: AppSpacing.x1 + 2),
                ],
                Text(
                  value,
                  maxLines: 1,
                  style: AppTypography.title.copyWith(
                    fontSize: 28,
                    height: 34 / 28,
                    color: color,
                    fontVariations: const [FontVariation('wght', 600)],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTypography.caption.copyWith(
                fontSize: 13,
                color: AppColors.inkSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of [BentoStatTile]s with even widths.
class BentoStatRow extends StatelessWidget {
  const BentoStatRow({super.key, required this.tiles});

  final List<BentoStatTile> tiles;

  @override
  Widget build(BuildContext context) {
    // Equal heights: a figure that has to shrink to fit (a long time) must
    // not leave its tile shorter than its neighbours.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.x3),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// The result page's body: the hero and the figures from the top of the
/// page (owner rule 9 — the meme card fills the page, so centring it only
/// pushed it down), entering once in a short cascade (instant under Reduce
/// Motion), and the actions pinned below.
class BentoResultBody extends StatelessWidget {
  const BentoResultBody({
    super.key,
    required this.verdict,
    required this.stats,
    required this.actions,
  });

  final Widget verdict;
  final Widget stats;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final blocks = [verdict, stats];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x6,
            ),
            child: Column(
              children: [
                for (var i = 0; i < blocks.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.x3),
                  StaggerIn(
                    index: i,
                    count: blocks.length,
                    curve: BentoTokens.curve,
                    child: blocks[i],
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x1,
            AppSpacing.x4,
            AppSpacing.x6,
          ),
          child: actions,
        ),
      ],
    );
  }
}
