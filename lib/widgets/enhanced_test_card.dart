import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

/// A test-mode entry on the Tests tab, in the Bento direction.
///
/// The public API is unchanged, so every call site still compiles. [cardType]
/// selects the entry's **role**, never a colour:
///
///   * `0` — the exam. A blue gradient hero with the two facts that matter
///     as pills. It is what users are training for, so it carries the weight.
///   * `1`, `2` — practice modes. White tiles, stacked full width.
///   * `3` — saved. The ink dark card.
///
/// It previously cycled blue/green/orange/purple pastel gradients by index,
/// which implied the three modes were categorised when they are not, and spent
/// the semantic colours on decoration. Green means one thing in this app now:
/// a correct answer.
class EnhancedTestCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon; // Kept for backward compatibility.
  final VoidCallback onTap;
  final String? leftInfoText;
  final String? rightInfoText;

  /// Entry role, not a colour. See the class doc.
  final int cardType;

  const EnhancedTestCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.leftInfoText,
    this.rightInfoText,
    this.cardType = 0,
  });

  @override
  State<EnhancedTestCard> createState() => _EnhancedTestCardState();
}

class _EnhancedTestCardState extends State<EnhancedTestCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  String get _iconAsset {
    switch (widget.cardType) {
      case 1:
        return AppIcons.theory;
      case 2:
        return AppIcons.practice;
      case 3:
        return AppIcons.saved;
      default:
        return AppIcons.tests;
    }
  }

  /// The counts this entry was given, in the order the mockup shows them.
  List<String> get _facts => [widget.leftInfoText, widget.rightInfoText]
      .whereType<String>()
      .where((s) => s.trim().isNotEmpty)
      .toList();

  /// The one fact a practice tile shows: the question count, not the time
  /// limit. Both practice modes are unlimited, so "Неограниченное время" on
  /// both tiles distinguishes nothing — the count is the fact that differs.
  String? get _tileFact {
    if (widget.rightInfoText?.trim().isNotEmpty == true) {
      return widget.rightInfoText;
    }
    return _facts.isEmpty ? null : _facts.first;
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = widget.cardType == 0
        ? _buildBentoHero(context)
        : widget.cardType == 3
            ? _buildBentoSaved(context)
            : _buildBentoTile(context);

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.description}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        // The card lifts a few points under the finger rather than shrinking:
        // the touch reading of a hover lift.
        child: AnimatedSlide(
          offset: Offset(0, _pressed ? -0.025 : 0),
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          child: body,
        ),
      ),
    );
  }

  /// The exam as the accent card: a blue gradient with the two facts as
  /// pills, and 40 thin bars — one per question — rising at the right.
  Widget _buildBentoHero(BuildContext context) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BentoTokens.card),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.signal600, AppColors.signal, AppColors.signal400],
          stops: [0, 0.55, 1],
        ),
        boxShadow: _pressed
            ? AppColors.shadowRaised
            : const [
                BoxShadow(
                  color: Color(0x290048C3),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The 40 questions, drawn as a quiet bar strip. Decoration in
          // white only; it never borrows a semantic hue. The same size as
          // the Профиль / Подписка / Поддержка heroes (owner, 2026-09-26):
          // rising from the card's bottom edge (out through the padding),
          // faint enough to sit behind the pills.
          Positioned(
            right: 0,
            bottom: -(AppSpacing.x4 + AppSpacing.x1),
            child: ExcludeSemantics(child: _questionBars()),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.title.copyWith(
                            fontSize: 22,
                            height: 28 / 22,
                            color: AppColors.onSignal,
                            fontVariations: const [FontVariation('wght', 700)],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.description,
                          style: AppTypography.label.copyWith(
                            color: AppColors.signal100,
                            fontVariations: const [FontVariation('wght', 400)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // No arrow disc: the whole card is the button.
                ],
              ),
              const Spacer(),
              if (_facts.isNotEmpty)
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (var i = 0; i < _facts.length; i++)
                      _bentoPill(
                        _facts[i],
                        // The last fact («40 запитань») is the solid white
                        // pill, the rest outlined (owner, 2026-09-26: the
                        // solid one reads better beside the bar strip).
                        solid: i == _facts.length - 1,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bentoPill(String text, {required bool solid}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1 + 2,
      ),
      decoration: BoxDecoration(
        color: solid ? AppColors.paper : AppColors.paper.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(BentoTokens.chip),
        border: Border.all(
          color: solid
              ? AppColors.paper
              : AppColors.onSignal.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: solid ? AppColors.signal : AppColors.onSignal,
          fontVariations: const [FontVariation('wght', 600)],
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _questionBars() {
    // A fixed, deterministic rhythm, not data: the strip only says "40".
    const heights = [
      10, 16, 12, 22, 14, 26, 18, 30, 20, 34, 24, 28, 38, 26, 42, 30, 36, 46,
      32, 40, 50, 36, 44, 54, 40, 48, 58, 44, 52, 60, 48, 56, 62, 52, 58, 64,
      56, 60, 66, 62,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in heights)
          Container(
            width: 3,
            height: h * 1.5,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              color: AppColors.onSignal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }

  /// A practice mode as a bento tile: label and icon on top, the count as a
  /// pill, the mode's name set bold at the foot — label above, value below.
  Widget _buildBentoTile(BuildContext context) {
    final fact = _tileFact;
    return AnimatedContainer(
      duration: AppMotion.duration(context, BentoTokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      // Title first, then one pill that carries the mode's icon and its
      // count. The icon used to sit alone on its own row, which left the top
      // of the tile looking empty.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: AppTypography.body.copyWith(
              fontSize: 17,
              height: 22 / 17,
              letterSpacing: -0.2,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          // One line always: a long translation shrinks slightly to fit
          // rather than wrapping the pill onto two lines.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x1 + 2,
                AppSpacing.x1,
                AppSpacing.x2 + 2,
                AppSpacing.x1,
              ),
              decoration: BoxDecoration(
                color: AppColors.signal50,
                borderRadius: BorderRadius.circular(BentoTokens.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcons.icon(_iconAsset, size: 16, color: AppColors.signal),
                  if (fact != null) ...[
                    const SizedBox(width: AppSpacing.x1 + 2),
                    Text(
                      fact,
                      maxLines: 1,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.signal,
                        fontVariations: const [FontVariation('wght', 500)],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Saved questions as the dark card: ink surface, white type, and one
  /// round action — the dashboard's "balance" card, with no invented data.
  Widget _buildBentoSaved(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.duration(context, BentoTokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x290E1422),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // Title first, then what it holds.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // One step below the exam title (22): the exam is the
                    // screen's lead, saved questions are secondary.
                    Text(
                      widget.title,
                      style: AppTypography.heading.copyWith(
                        fontSize: 18,
                        height: 24 / 18,
                        color: AppColors.onSignal,
                        fontVariations: const [FontVariation('wght', 600)],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      widget.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onSignal.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
              ),
              // No arrow button: the whole card is the button.
            ],
          ),
        ],
      ),
    );
  }
}
