import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';

/// The Bento pieces the question pages share — topic questions
/// (`quiz_question_screen.dart`) and Практика (`practice_question_screen.dart`).
///
/// Presentation only: every piece takes its state and callbacks from the
/// screen, so each screen keeps its own logic. Экзамен has its own copy of
/// this look (`exam_question_screen.dart`), frozen by the owner on 2026-09-26.

/// White discs for app-bar controls on the field page.
final ButtonStyle bentoRoundIconStyle = IconButton.styleFrom(
  backgroundColor: AppColors.paper,
  fixedSize: const Size(44, 44),
  shape: const CircleBorder(),
);

/// A pushed question page's app bar: it melts into the field page and floats
/// its controls as white discs. No title — long names wrapped to two lines
/// between the buttons (owner, 2026-09-26). No elevation tint.
AppBar bentoQuestionAppBar({
  required VoidCallback onBack,
  List<Widget>? actions,
}) {
  return AppBar(
    toolbarHeight: 64,
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
  );
}

/// Report (⚠) and save (♥) as round buttons, for [bentoQuestionAppBar].
List<Widget> bentoQuestionActions(
  BuildContext context, {
  required String reportTooltip,
  required VoidCallback onReport,
  required bool isSaved,
  required VoidCallback onToggleSaved,
}) {
  return [
    // Report a problem with this question. Opens ReportSheet.
    IconButton(
      tooltip: reportTooltip,
      style: bentoRoundIconStyle,
      icon: AppIcons.icon(
        AppIcons.report,
        size: 22,
        color: AppColors.inkSecondary,
      ),
      onPressed: onReport,
    ),
    const SizedBox(width: AppSpacing.x1),
    IconButton(
      style: bentoRoundIconStyle,
      // The heart answers the tap: outline to fill with a short scale-in,
      // rather than snapping.
      icon: AnimatedSwitcher(
        duration: AppMotion.duration(context, BentoTokens.state),
        switchInCurve: AppMotion.enter,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: KeyedSubtree(
          key: ValueKey(isSaved),
          child: AppIcons.icon(
            isSaved ? AppIcons.savedFilled : AppIcons.saved,
            size: 22,
            color: isSaved ? AppColors.stop : AppColors.inkSecondary,
          ),
        ),
      ),
      onPressed: onToggleSaved,
    ),
    const SizedBox(width: AppSpacing.x3),
  ];
}

/// What a pill in the question strip shows.
enum BentoPillState { current, correct, wrong, unseen }

/// The question strip in its own soft pill tray. Its ends fade out so a pill
/// scrolling past never meets the tray's rounded edge. Blue = where you are,
/// green = answered right, red = answered wrong, plain = not yet seen — the
/// same semantics the options use.
class BentoPillTray extends StatelessWidget {
  const BentoPillTray({
    super.key,
    required this.controller,
    required this.count,
    required this.stateOf,
    this.onTap,
  });

  final ScrollController controller;
  final int count;
  final BentoPillState Function(int index) stateOf;

  /// Jump to a question. Null makes the pills display-only.
  final ValueChanged<int>? onTap;

  /// Horizontal inset of the pill list; [scrollToPill] needs it.
  static const double listPadding = AppSpacing.x3;

  /// Width of one pill slot: 44pt, whatever size the pill is drawn at.
  static const double extent = 44;

  /// Centres pill [index] in the tray. Reduce Motion makes it a jump.
  static void scrollToPill(
    BuildContext context,
    ScrollController controller,
    int index,
  ) {
    if (!controller.hasClients) return;
    final viewport = controller.position.viewportDimension;
    final target = listPadding + extent * index;
    final offset = (target - viewport / 2 + extent / 2)
        .clamp(0.0, controller.position.maxScrollExtent);
    final duration = AppMotion.duration(context, BentoTokens.swap);
    if (duration == Duration.zero) {
      controller.jumpTo(offset);
    } else {
      controller.animateTo(offset,
          duration: duration, curve: AppMotion.enter);
    }
  }

  /// Scrolls a page back to its top. Reduce Motion makes it a jump.
  static void scrollToTop(BuildContext context, ScrollController controller) {
    if (!controller.hasClients) return;
    final duration = AppMotion.duration(context, AppMotion.base);
    if (duration == Duration.zero) {
      controller.jumpTo(0.0);
    } else {
      controller.animateTo(0.0, duration: duration, curve: AppMotion.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strip = SizedBox(
      height: extent + AppSpacing.x3,
      child: ListView.builder(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: listPadding,
          vertical: AppSpacing.x1 + 2,
        ),
        itemCount: count,
        itemBuilder: (context, index) => _pill(context, index),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x1,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(BentoTokens.bar),
          boxShadow: AppColors.shadowCard,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(BentoTokens.bar),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => const LinearGradient(
              colors: [
                Color(0x00000000),
                Color(0xFF000000),
                Color(0xFF000000),
                Color(0x00000000),
              ],
              stops: [0, 0.04, 0.96, 1],
            ).createShader(rect),
            child: strip,
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, int index) {
    final state = stateOf(index);
    final (Color fill, Color ink) = switch (state) {
      BentoPillState.current => (AppColors.signal, AppColors.onSignal),
      BentoPillState.correct => (AppColors.guideSurface, AppColors.guide),
      BentoPillState.wrong => (AppColors.stopSurface, AppColors.stop),
      BentoPillState.unseen => (AppColors.field, AppColors.inkSecondary),
    };
    final Duration duration = AppMotion.duration(context, BentoTokens.state);

    final Widget pill = SizedBox(
      width: extent,
      child: Center(
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.enter,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: AppTypography.pill.copyWith(
                color: ink,
                fontSize: 14,
                fontVariations: const [FontVariation('wght', 500)],
              ),
              child: Text('${index + 1}'),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: '${index + 1}',
      selected: state == BentoPillState.current,
      button: onTap != null,
      child: onTap == null
          ? pill
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap!(index),
              child: pill,
            ),
    );
  }
}

/// The question as its own card: the counter as a neutral pill, then the
/// question. For multiple-choice questions, a neutral «multiple answers» chip
/// and a one-line hint follow.
class BentoQuestionCard extends StatelessWidget {
  const BentoQuestionCard({
    super.key,
    required this.counter,
    required this.question,
    this.multipleLabel,
    this.selectAllHint,
  });

  final String counter;
  final String question;

  /// Set only for multiple-choice questions.
  final String? multipleLabel;
  final String? selectAllHint;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text,
            {Color fill = AppColors.field,
            Color ink = AppColors.inkSecondary,
            Color? edge}) =>
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x2,
            vertical: AppSpacing.x1,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(BentoTokens.chip),
            border: Border.all(color: edge ?? fill),
          ),
          child: Text(
            text,
            style: AppTypography.caption.copyWith(
              color: ink,
              fontVariations: const [FontVariation('wght', 500)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.x3),
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              chip(counter),
              // Neutral, not blue: a note about the question, not an action.
              if (multipleLabel != null)
                chip(
                  multipleLabel!,
                  fill: AppColors.paper,
                  ink: AppColors.ink,
                  edge: AppColors.borderStrong,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            question,
            style: AppTypography.heading.copyWith(
              fontSize: 19,
              height: 27 / 19,
              letterSpacing: -0.2,
            ),
          ),
          if (selectAllHint != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x3),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x3,
                  vertical: AppSpacing.x2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(BentoTokens.chip),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      SolarIcons.infoCircleLinear,
                      size: 16,
                      color: AppColors.inkSecondary,
                    ),
                    const SizedBox(width: AppSpacing.x2),
                    Expanded(
                      child: Text(
                        selectAllHint!,
                        style: AppTypography.label.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An answer option: a borderless card with a numbered key. Selected turns it
/// blue; after the check the right answer turns green with ✓ and a wrong pick
/// red with ✕ — shape as well as colour, so the verdict reads without relying
/// on hue. Unanswered options are plain paper: per-index pastel tints spent
/// green and red on decoration.
class BentoOptionTile extends StatelessWidget {
  const BentoOptionTile({
    super.key,
    required this.index,
    required this.text,
    required this.isSelected,
    required this.showResult,
    required this.isCorrectOption,
    required this.onTap,
    this.onCard = false,
  });

  final int index;
  final String text;
  final bool isSelected;
  final bool showResult;
  final bool isCorrectOption;

  /// Null once the answer is checked.
  final VoidCallback? onTap;

  /// Drawn inside a white card (Сохраненные): the resting option is a field
  /// panel without a shadow, so it still reads against the card.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final Color rest = onCard ? AppColors.field : AppColors.paper;
    final Color fill = showResult
        ? isCorrectOption
            ? AppColors.guideSurface
            : isSelected
                ? AppColors.stopSurface
                : rest
        : isSelected
            ? AppColors.signal50
            : rest;
    final Color stateColor = showResult
        ? isCorrectOption
            ? AppColors.guide
            : isSelected
                ? AppColors.stop
                : AppColors.border
        : isSelected
            ? AppColors.signal
            : AppColors.border;
    final bool emphasised = isSelected || (showResult && isCorrectOption);

    final String? verdictIcon = showResult && isCorrectOption
        ? AppIcons.check
        : showResult && isSelected
            ? AppIcons.close
            : null;
    final Color verdictColor =
        isCorrectOption ? AppColors.guide : AppColors.stop;

    final Color textColor = showResult && (isSelected || isCorrectOption)
        ? (isSelected && !isCorrectOption)
            ? AppColors.stop
            : AppColors.guide
        : showResult
            // After the check, the unchosen wrong options step back.
            ? AppColors.inkSecondary
            : AppColors.ink;

    // Selection feedback is fast; the verdict gets the full reveal.
    final Duration d = AppMotion.duration(
        context, showResult ? BentoTokens.reveal : BentoTokens.state);

    final Color keyFill = verdictIcon != null
        ? verdictColor
        : isSelected
            ? AppColors.signal
            : AppColors.field;
    final bool onFill = isSelected || verdictIcon != null;

    final Widget tile = AnimatedContainer(
      duration: d,
      curve: AppMotion.enter,
      // Borderless until emphasised; the 2pt border's width is given back by
      // the padding so the text never shifts.
      padding: EdgeInsets.all(emphasised ? AppSpacing.x4 - 2 : AppSpacing.x4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        border: Border.all(
          color: emphasised ? stateColor : rest,
          width: emphasised ? 2 : 0,
        ),
        boxShadow: emphasised || onCard ? null : AppColors.shadowCard,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: d,
            curve: AppMotion.enter,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: onCard && keyFill == AppColors.field ? AppColors.paper : keyFill,
              borderRadius: BorderRadius.circular(BentoTokens.chip),
            ),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: d,
              switchInCurve: AppMotion.enter,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: verdictIcon != null
                  ? KeyedSubtree(
                      key: ValueKey(verdictIcon),
                      child: AppIcons.icon(
                        verdictIcon,
                        size: 18,
                        color: AppColors.onSignal,
                      ),
                    )
                  : Text(
                      '${index + 1}',
                      key: ValueKey('n$onFill'),
                      style: AppTypography.pill.copyWith(
                        fontSize: 15,
                        color: onFill
                            ? AppColors.onSignal
                            : AppColors.inkSecondary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: d,
              style: AppTypography.body.copyWith(
                color: textColor,
                // Weight holds steady on selection: a bolder face re-wraps
                // the option and jolts the layout.
                fontVariations: const [FontVariation('wght', 400)],
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: PressScale(
            enabled: onTap != null,
            scale: 0.98,
            duration: BentoTokens.state,
            child: tile,
          ),
        ),
      ),
    );
  }
}

/// A pill button. Primary: solid blue; secondary: white, borderless, lifted
/// by shadow; disabled (no [onTap]): grey.
class BentoActionButton extends StatelessWidget {
  const BentoActionButton({
    super.key,
    required this.text,
    required this.onTap,
    this.primary = true,
    this.onCard = false,
    this.ink = false,
  });

  final String text;
  final VoidCallback? onTap;
  final bool primary;

  /// The dark `ink` pill — for a page's own action that is not the step
  /// forward in a flow (Сохранить on Персональная информация, owner
  /// 2026-09-28). Disabled it greys out like the others.
  final bool ink;

  /// Inside a white card the secondary pill is a field fill, not a lifted
  /// white one.
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(BentoTokens.button);
    final bool enabled = onTap != null;
    final Color bg = !enabled
        ? AppColors.border
        : ink
            ? AppColors.ink
            : primary
            ? AppColors.signal
            : onCard
                ? AppColors.field
                : AppColors.paper;
    final Color fg = !enabled
        ? AppColors.inkTertiary
        : ink || primary
            ? AppColors.onSignal
            : AppColors.ink;
    return PressScale(
      enabled: enabled,
      scale: 0.97,
      duration: BentoTokens.state,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, BentoTokens.state),
        curve: AppMotion.enter,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          boxShadow: primary || ink
              ? (enabled ? AppColors.shadowRaised : null)
              : onCard
                  ? null
                  : AppColors.shadowResting,
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
                    color: fg,
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

/// Skip and Check side by side; once checked, one full-width Next — never a
/// disabled button left beside it.
class BentoCheckActions extends StatelessWidget {
  const BentoCheckActions({
    super.key,
    required this.isChecked,
    required this.skipLabel,
    required this.onSkip,
    required this.checkLabel,
    required this.onCheck,
    required this.nextLabel,
    required this.onNext,
  });

  final bool isChecked;
  final String skipLabel;
  final VoidCallback onSkip;
  final String checkLabel;

  /// Null while nothing is selected.
  final VoidCallback? onCheck;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final Duration state = AppMotion.duration(context, BentoTokens.state);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x6,
      ),
      child: AnimatedSwitcher(
        duration: state,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: isChecked
            ? KeyedSubtree(
                key: const ValueKey('next'),
                child: SizedBox(
                  width: double.infinity,
                  child: BentoActionButton(text: nextLabel, onTap: onNext),
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('check'),
                child: Row(
                  children: [
                    Expanded(
                      child: BentoActionButton(
                        text: skipLabel,
                        onTap: onSkip,
                        primary: false,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.x4),
                    Expanded(
                      child: BentoActionButton(
                        text: checkLabel,
                        onTap: onCheck,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// The explanation shown after a check: its own card, title first, then the
/// rule it comes from, then the text. [onCard] draws it as a field panel
/// inside a white card instead.
class BentoExplanation extends StatelessWidget {
  const BentoExplanation({
    super.key,
    required this.title,
    required this.text,
    this.ruleReference,
    this.onCard = false,
  });

  final String title;
  final String text;
  final String? ruleReference;
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.x2),
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: onCard ? AppColors.field : AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: onCard ? null : AppColors.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: onCard ? AppColors.paper : AppColors.signal50,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  SolarIcons.lightbulbLinear,
                  size: 18,
                  color: AppColors.signal,
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontSize: 17,
                    height: 22 / 17,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
              ),
            ],
          ),
          if (ruleReference != null) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              ruleReference!,
              style: AppTypography.label.copyWith(
                color: AppColors.inkSecondary,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x2),
          Text(
            text,
            style: AppTypography.body.copyWith(
              fontSize: 15,
              height: 22 / 15,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
