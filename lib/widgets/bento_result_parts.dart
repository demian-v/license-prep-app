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
/// name — left-aligned, one line, shrinking rather than wrapping.
AppBar bentoHeadingAppBar({
  required String title,
  required VoidCallback onBack,
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

/// The result as the page's one hero card: the 3D picture on a soft disc,
/// then the verdict. [tone] carries the meaning — green for passed, red for
/// not passed, blue where there is no verdict (a topic run).
class BentoVerdictCard extends StatelessWidget {
  const BentoVerdictCard({
    super.key,
    required this.pictureAsset,
    required this.fallbackIcon,
    required this.title,
    required this.tone,
    required this.toneSurface,
    this.titleColor = AppColors.ink,
  });

  final String pictureAsset;
  final IconData fallbackIcon;
  final String title;
  final Color tone;
  final Color toneSurface;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        AppSpacing.x8,
        AppSpacing.x6,
        AppSpacing.x6,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: toneSurface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              pictureAsset,
              width: 104,
              height: 104,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(fallbackIcon, color: tone, size: 72),
            ),
          ),
          const SizedBox(height: AppSpacing.x6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              fontSize: 24,
              height: 30 / 24,
              letterSpacing: -0.4,
              color: titleColor,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
        ],
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

/// The result page's body: the hero and the figures, entering once in a
/// short cascade (instant under Reduce Motion), and the actions pinned below.
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
        // Centred in the space above the actions when it fits, so a short
        // result leaves no empty band; it scrolls when it does not fit.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x4,
                AppSpacing.x6,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.x2 - AppSpacing.x6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
