import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import 'bento_hero_bars.dart';

enum BentoChoiceTone {
  /// The page's one blue gradient hero: the primary choice.
  hero,

  /// The `ink` dark card: the secondary destination.
  ink,

  /// A plain white card: equal-weight choices.
  paper,
}

/// One tappable choice as a whole Bento card, built like the app's heroes
/// (Поддержка, the exam card): the icon on a disc beside the title, the
/// description under the title (owner rule 2), and short facts as pills along
/// the bottom — on the hero the first outlined, the rest solid white. No
/// arrow or chevron; the card is the target (rule 7). The hero carries the faint bar strip every
/// blue hero has. It lifts under the finger rather than shrinking.
///
/// Used by the signup role cards and the instructor-kind choice
/// (instructors plan v2 §4.1).
class BentoChoiceCard extends StatefulWidget {
  const BentoChoiceCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
    required this.icon,
    this.tone = BentoChoiceTone.paper,
    this.pills = const [],
  });

  final String title;
  final String description;
  final VoidCallback? onTap;
  final IconData icon;
  final BentoChoiceTone tone;

  /// Facts, one short phrase each (rule 5).
  final List<String> pills;

  @override
  State<BentoChoiceCard> createState() => _BentoChoiceCardState();
}

class _BentoChoiceCardState extends State<BentoChoiceCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  BoxDecoration get _decoration => switch (widget.tone) {
        BentoChoiceTone.hero => BoxDecoration(
            borderRadius: BorderRadius.circular(BentoTokens.card),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.signal600, AppColors.signal, AppColors.signal400],
              stops: [0, 0.55, 1],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x290048C3), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
        BentoChoiceTone.ink => BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            boxShadow: const [
              BoxShadow(color: Color(0x290E1422), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
        BentoChoiceTone.paper => BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(BentoTokens.card),
            boxShadow: AppColors.shadowCard,
          ),
      };

  Widget _disc() {
    final (Color fill, Color glyph) = switch (widget.tone) {
      BentoChoiceTone.hero => (AppColors.paper, AppColors.signal),
      BentoChoiceTone.ink => (AppColors.onSignal.withValues(alpha: 0.12), AppColors.onSignal),
      BentoChoiceTone.paper => (AppColors.signal50, AppColors.signal),
    };
    final size = widget.tone == BentoChoiceTone.hero ? 52.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(widget.icon, color: glyph, size: size * 0.54),
    );
  }

  Widget _pill(String text, {required bool first}) {
    final Color fill;
    final Color? border;
    final Color label;
    switch (widget.tone) {
      // Owner, 2026-09-30: on the role hero the first fact is outlined and
      // the rest are solid white.
      case BentoChoiceTone.hero:
        fill = first ? Colors.transparent : AppColors.paper;
        border = first ? AppColors.onSignal.withValues(alpha: 0.5) : null;
        label = first ? AppColors.onSignal : AppColors.signal;
      case BentoChoiceTone.ink:
        fill = Colors.transparent;
        border = AppColors.onSignal.withValues(alpha: 0.4);
        label = AppColors.onSignal;
      case BentoChoiceTone.paper:
        fill = AppColors.signal50;
        border = null;
        label = AppColors.signal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
        // Same 1px on every pill, transparent on the solid ones, so solid and
        // outlined pills are the same height side by side.
        border: Border.all(color: border ?? Colors.transparent),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: AppTypography.caption.copyWith(
          color: label,
          fontVariations: const [FontVariation('wght', 600)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.tone == BentoChoiceTone.hero;
    final onDark = widget.tone != BentoChoiceTone.paper;
    final titleColor = onDark ? AppColors.onSignal : AppColors.ink;
    final descriptionColor = switch (widget.tone) {
      BentoChoiceTone.hero => AppColors.signal100,
      BentoChoiceTone.ink => AppColors.onSignal.withValues(alpha: 0.64),
      BentoChoiceTone.paper => AppColors.inkSecondary,
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _disc(),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: (hero ? AppTypography.title : AppTypography.heading).copyWith(
                      // The hero is the lead card, so its title is the
                      // largest on the page (rule 4).
                      fontSize: hero ? 22 : 18,
                      height: hero ? 28 / 22 : 24 / 18,
                      color: titleColor,
                      fontVariations: [FontVariation('wght', hero ? 700 : 600)],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.description,
                    style: (hero ? AppTypography.label : AppTypography.caption).copyWith(
                      color: descriptionColor,
                      fontVariations: const [FontVariation('wght', 400)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.pills.isNotEmpty) ...[
          SizedBox(height: hero ? AppSpacing.x6 : AppSpacing.x4),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (var i = 0; i < widget.pills.length; i++)
                _pill(widget.pills[i], first: i == 0),
            ],
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: Offset(0, _pressed ? -0.025 : 0),
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          child: AnimatedOpacity(
            opacity: widget.onTap == null ? 0.5 : 1,
            duration: AppMotion.duration(context, BentoTokens.state),
            child: Container(
              width: double.infinity,
              clipBehavior: hero ? Clip.antiAlias : Clip.none,
              decoration: _decoration,
              child: Stack(
                children: [
                  if (hero)
                    const Positioned(
                      right: AppSpacing.x4 + AppSpacing.x1,
                      bottom: 0,
                      child: BentoHeroBars(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
                    child: content,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
