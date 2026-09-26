import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

class EnhancedProfileCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int cardType; // For determining the gradient color
  final bool isHighlighted; // For highlighting the subtitle text if needed
  final String? iconAsset; // For custom asset icons

  /// The dark `ink` card, as «Сохраненные» on Тесты — for the page's
  /// secondary destination.
  final bool dark;

  /// A short line under the title saying what the setting is for, beside
  /// the value (owner, 2026-09-26: the tiles looked empty).
  final String? description;

  const EnhancedProfileCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.cardType = 0,
    this.isHighlighted = false,
    this.iconAsset,
    this.dark = false,
    this.description,
  }) : super(key: key);

  @override
  _EnhancedProfileCardState createState() => _EnhancedProfileCardState();
}

class _EnhancedProfileCardState extends State<EnhancedProfileCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  // The per-type pastel washes and icon colours (green, blue, purple,
  // amber…) spent the semantic colours on decoration and are gone; the card
  // is white and the 3D picture carries the identity. [cardType] is kept for
  // callers.

  /// Titles come from translations that end in a colon («Штат:»), which
  /// reads as a form label on a card; the colon is dropped for display only.
  String get _title => widget.title.replaceFirst(RegExp(r'\s*:\s*$'), '');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        // Lifts a few points under the finger rather than shrinking, as the
        // other Bento cards do. The whole card is the button — no chevron.
        child: AnimatedSlide(
          offset: Offset(0, _pressed ? -0.03 : 0),
          duration: AppMotion.duration(context, BentoTokens.state),
          curve: AppMotion.enter,
          child: Container(
            padding: EdgeInsets.all(widget.dark ? AppSpacing.x4 + AppSpacing.x1 : AppSpacing.x4),
            decoration: widget.dark
                ? BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(BentoTokens.card),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x290E1422),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  )
                : BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(BentoTokens.card),
                    boxShadow: AppColors.shadowCard,
                  ),
            // A setting (language, state) or the dark card: the title and a
            // one-line description on the left, the value at the bottom right
            // (owner, 2026-09-26: no empty side, keep the tile's size). A
            // plain description tile (Поддержка) has no value.
            child: (widget.isHighlighted || widget.dark)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTitleText(),
                            if (widget.description != null) ...[
                              const SizedBox(height: AppSpacing.x1),
                              Text(
                                widget.description!,
                                style: AppTypography.body.copyWith(
                                  fontSize: 14,
                                  height: 20 / 14,
                                  color: widget.dark
                                      ? AppColors.onSignal.withValues(alpha: 0.64)
                                      : AppColors.inkSecondary,
                                ),
                              ),
                            ] else
                              const SizedBox(height: AppSpacing.x8),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x3),
                      // A long value scales down rather than wrapping.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: widget.dark ? _buildDarkValue() : _buildValuePill(),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTitleText(),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        widget.subtitle,
                        style: AppTypography.body.copyWith(
                          fontSize: 14,
                          height: 20 / 14,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleText() {
    return Text(
      _title,
      style: widget.dark
          ? AppTypography.heading.copyWith(
              fontSize: 18,
              height: 24 / 18,
              color: AppColors.onSignal,
              fontVariations: const [FontVariation('wght', 600)],
            )
          : AppTypography.body.copyWith(
              fontSize: 17,
              height: 22 / 17,
              letterSpacing: -0.2,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
    );
  }

  /// The dark card's value as an outlined white pill — the exam hero's
  /// secondary pill («40 вопросов»).
  Widget _buildDarkValue() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x1 + 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BentoTokens.chip),
          border: Border.all(color: AppColors.onSignal.withValues(alpha: 0.5)),
        ),
        child: Text(
          widget.subtitle,
          maxLines: 1,
          style: AppTypography.caption.copyWith(
            fontSize: 13,
            color: AppColors.onSignal,
            fontVariations: const [FontVariation('wght', 500)],
          ),
        ),
      ),
    );
  }

  /// The chosen value in a blue pill with its icon, as the counts on the
  /// Тесты tiles («100+ вопросов»). One line; shrinks rather than wraps.
  Widget _buildValuePill() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
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
            Icon(widget.icon, size: 16, color: AppColors.signal),
            const SizedBox(width: AppSpacing.x1 + 2),
            Text(
              widget.subtitle,
              maxLines: 1,
              style: AppTypography.caption.copyWith(
                color: AppColors.signal,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
