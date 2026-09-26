import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';

/// A test-mode entry on the Tests tab — direction A.
///
/// The public API is unchanged, so every call site still compiles. [cardType]
/// selects the entry's **role**, never a colour:
///
///   * `0` — the exam. A tall brand-blue card with the two facts that matter
///     as chips. It is what users are training for, so it carries the weight.
///   * `1`, `2` — practice modes. Compact tiles that sit side by side.
///   * `3` — saved. A full-width row with a count.
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

  /// Splits a translated fact into its leading figure and the rest —
  /// "40 вопросов" → ("40", "вопросов"), "100+ pytań na tematy" → ("100+", …).
  /// A string with no leading figure comes back whole, as the label.
  static (String?, String) _splitFigure(String text) {
    final match = RegExp(r'^(\d+\+?)\s+(.+)$').firstMatch(text.trim());
    if (match == null) return (null, text);
    return (match.group(1), match.group(2)!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DesignVariant>(
      valueListenable: designVariant,
      builder: (context, variant, _) {
        final tokens = VariantTokens.of(variant);
        final Widget body;
        switch (variant) {
          case DesignVariant.refined:
            body = widget.cardType == 0
                ? _buildPrimary(context)
                : widget.cardType == 3
                    ? _buildSavedRow(context)
                    : _buildTile(context);
            break;
          case DesignVariant.boldA:
            body = widget.cardType == 0
                ? _buildSignalHero(context, tokens)
                : widget.cardType == 3
                    ? _buildSignalSaved(context, tokens)
                    : _buildSignalTile(context, tokens);
            break;
          case DesignVariant.boldB:
            body = widget.cardType == 0
                ? _buildLedgerLead(context, tokens)
                : _buildLedgerRow(context, tokens);
            break;
          case DesignVariant.bento:
            body = widget.cardType == 0
                ? _buildBentoHero(context, tokens)
                : widget.cardType == 3
                    ? _buildBentoSaved(context, tokens)
                    : _buildBentoTile(context, tokens);
            break;
        }

        // Ledger rows sit inside a shared list block; they answer a press
        // with a fill, not a scale, so the block's edges never move.
        final bool scales =
            variant != DesignVariant.boldB || widget.cardType == 0;

        return Semantics(
          button: true,
          label: '${widget.title}. ${widget.description}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: AnimatedScale(
              // A card is heavy: it should give under the finger, barely.
              scale: _pressed && scales ? tokens.pressScale : 1,
              duration: AppMotion.duration(context, tokens.state),
              curve: variant == DesignVariant.boldA
                  ? AppMotion.spring
                  : AppMotion.press,
              // Bento lifts instead: the card rises a few points under the
              // finger, the touch reading of a hover lift.
              child: AnimatedSlide(
                offset: Offset(
                  0,
                  _pressed && variant == DesignVariant.bento ? -0.025 : 0,
                ),
                duration: AppMotion.duration(context, tokens.state),
                curve: AppMotion.enter,
                child: body,
              ),
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------ refined ---

  /// The exam.
  Widget _buildPrimary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x6),
      decoration: BoxDecoration(
        color: AppColors.signal,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppColors.shadowRaised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      widget.description,
                      style: AppTypography.label.copyWith(
                        color: AppColors.signal200,
                        fontVariations: const [FontVariation('wght', 400)],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.x1),
                child: AppIcons.icon(
                  AppIcons.chevron,
                  size: 20,
                  color: AppColors.onSignal,
                ),
              ),
            ],
          ),
          if (_facts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x4),
            // Wraps rather than overflows: "Неограниченное время" and other
            // Russian strings run well past their English equivalents.
            Wrap(
              spacing: AppSpacing.x2,
              runSpacing: AppSpacing.x2,
              children: _facts.map(_chip).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: AppColors.onSignal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.onSignal,
          fontVariations: const [FontVariation('wght', 600)],
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// A practice mode. Sized to sit beside its sibling in a two-up row.
  Widget _buildTile(BuildContext context) {
    final fact = _tileFact;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.press,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _pressed ? AppColors.borderStrong : AppColors.border,
        ),
        boxShadow: AppColors.shadowResting,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcons.icon(_iconAsset, size: 20, color: AppColors.signal),
          const SizedBox(height: AppSpacing.x3),
          Text(
            widget.title,
            style: AppTypography.body.copyWith(
              height: 22 / 16,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          if (fact != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              fact,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.inkSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Saved questions.
  Widget _buildSavedRow(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.press,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _pressed ? AppColors.borderStrong : AppColors.border,
        ),
        boxShadow: AppColors.shadowResting,
      ),
      child: Row(
        children: [
          AppIcons.icon(_iconAsset, size: 20, color: AppColors.inkSecondary),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              widget.title,
              style: AppTypography.body.copyWith(
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          AppIcons.icon(
            AppIcons.chevron,
            size: 16,
            color: AppColors.inkTertiary,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- signal ---

  /// The exam as a hero: a machined double-bezel, the two numbers set as
  /// display type, and a start key nested inside the card.
  Widget _buildSignalHero(BuildContext context, VariantTokens tokens) {
    const double bezel = AppSpacing.x2;
    return Container(
      padding: const EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        // The tray: a pale wash of the same blue, never a second hue.
        color: AppColors.signal100.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(tokens.card + bezel),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          AppSpacing.x6,
          AppSpacing.x4,
          AppSpacing.x6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.card),
          // Tonal depth inside the brand colour: light falls from the top
          // right. Every stop is a signal shade.
          gradient: const RadialGradient(
            center: Alignment(0.9, -1.1),
            radius: 1.4,
            colors: [AppColors.signal400, AppColors.signal, AppColors.signal700],
            stops: [0, 0.45, 1],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x330048C3),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: Color(0x1A00338C),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
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
                        style: AppTypography.display.copyWith(
                          fontSize: 28,
                          height: 32 / 28,
                          letterSpacing: -0.8,
                          color: AppColors.onSignal,
                          fontVariations: const [FontVariation('wght', 800)],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        widget.description,
                        style: AppTypography.label.copyWith(
                          color: AppColors.signal100,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                // Button-in-button: the start affordance sits in its own disc.
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.paper,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppIcons.icon(
                    AppIcons.chevron,
                    size: 20,
                    color: AppColors.signal,
                  ),
                ),
              ],
            ),
            if (_facts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x6),
              Wrap(
                spacing: AppSpacing.x8,
                runSpacing: AppSpacing.x3,
                children: _facts.map(_signalFigure).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _signalFigure(String text) {
    final (figure, unit) = _splitFigure(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (figure != null)
          Text(
            figure,
            style: AppTypography.display.copyWith(
              fontSize: 40,
              height: 44 / 40,
              letterSpacing: -1.2,
              color: AppColors.onSignal,
              fontVariations: const [FontVariation('wght', 800)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        Text(
          unit,
          style: AppTypography.caption.copyWith(
            fontSize: 13,
            color: AppColors.signal100,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
      ],
    );
  }

  Widget _buildSignalTile(BuildContext context, VariantTokens tokens) {
    final fact = _tileFact;
    final (figure, unit) =
        fact == null ? (null, '') : _splitFigure(fact);
    return AnimatedContainer(
      duration: AppMotion.duration(context, tokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(tokens.card),
        boxShadow: _pressed
            ? AppColors.shadowResting
            : const [
                BoxShadow(
                  color: Color(0x140E1F4D),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
                BoxShadow(
                  color: Color(0x0A0E1F4D),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.signal50,
              borderRadius: BorderRadius.circular(tokens.chip),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(_iconAsset, size: 22, color: AppColors.signal),
          ),
          const SizedBox(height: AppSpacing.x4),
          // Figure first, as the headline of the tile; the title names it and
          // the unit sits underneath.
          if (figure != null)
            Text(
              figure,
              style: AppTypography.title.copyWith(
                fontSize: 28,
                height: 32 / 28,
                letterSpacing: -0.6,
                fontVariations: const [FontVariation('wght', 800)],
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          Text(
            widget.title,
            style: AppTypography.body.copyWith(
              height: 22 / 16,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              unit,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.inkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalSaved(BuildContext context, VariantTokens tokens) {
    return AnimatedContainer(
      duration: AppMotion.duration(context, tokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(tokens.card),
        boxShadow: _pressed ? null : AppColors.shadowResting,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(tokens.chip),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(_iconAsset, size: 22, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.body.copyWith(
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
                Text(
                  widget.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          AppIcons.icon(AppIcons.chevron, size: 18, color: AppColors.ink),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- ledger ---

  /// The exam as the lead row: ink type, facts inline, one blue key.
  Widget _buildLedgerLead(BuildContext context, VariantTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(tokens.card),
        border: Border.all(
          color: _pressed ? AppColors.signal : AppColors.borderStrong,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTypography.heading.copyWith(
                    fontSize: 18,
                    height: 24 / 18,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.description,
                  style: AppTypography.label.copyWith(
                    color: AppColors.inkSecondary,
                    fontVariations: const [FontVariation('wght', 400)],
                  ),
                ),
                if (_facts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Wrap(
                    spacing: AppSpacing.x1,
                    runSpacing: AppSpacing.x1,
                    children: _facts.map((f) => _ledgerKey(f, tokens)).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          AnimatedContainer(
            duration: AppMotion.duration(context, tokens.state),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _pressed ? AppColors.signal600 : AppColors.signal,
              borderRadius: BorderRadius.circular(tokens.button),
            ),
            alignment: Alignment.center,
            child: AppIcons.icon(
              AppIcons.chevron,
              size: 20,
              color: AppColors.onSignal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ledgerKey(String text, VariantTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(tokens.chip),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// A bare list row. The list block around it (hairlines, radius) is drawn
  /// by the Tests screen, so rows stack into one surface.
  Widget _buildLedgerRow(BuildContext context, VariantTokens tokens) {
    final fact = widget.cardType == 3 ? null : _tileFact;
    return AnimatedContainer(
      duration: AppMotion.duration(context, tokens.state),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      color: _pressed ? AppColors.field : AppColors.paper,
      child: Row(
        children: [
          AppIcons.icon(_iconAsset, size: 20, color: AppColors.inkSecondary),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              widget.title,
              style: AppTypography.body.copyWith(
                fontSize: 15,
                height: 20 / 15,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ),
          if (fact != null) ...[
            const SizedBox(width: AppSpacing.x2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                fact,
                textAlign: TextAlign.right,
                maxLines: 2,
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpacing.x2),
          AppIcons.icon(
            AppIcons.chevron,
            size: 14,
            color: AppColors.inkTertiary,
          ),
        ],
      ),
    );
  }
  // -------------------------------------------------------------- bento ---

  /// The soft, borderless card surface every Bento card shares.
  static const List<BoxShadow> _bentoShadow = [
    BoxShadow(
      color: Color(0x0F0E1F4D),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x080E1F4D),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// The exam as the accent card: a blue gradient with the two facts as
  /// pills, and 40 thin bars — one per question — rising at the right.
  Widget _buildBentoHero(BuildContext context, VariantTokens tokens) {
    return Container(
      height: 168,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.card),
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
        children: [
          // The 40 questions, drawn as a quiet bar strip. Decoration in
          // white only; it never borrows a semantic hue.
          // Sits above the pill row, never under it.
          Positioned(
            right: 0,
            bottom: 44,
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
                            fontVariations: const [FontVariation('wght', 800)],
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
                        tokens,
                        // The first fact is a solid white pill, the rest
                        // outlined — the dashboard's primary/secondary pair.
                        solid: i == 0,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bentoPill(String text, VariantTokens tokens, {required bool solid}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1 + 2,
      ),
      decoration: BoxDecoration(
        color: solid ? AppColors.paper : AppColors.paper.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(tokens.chip),
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
          fontVariations: const [FontVariation('wght', 700)],
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
            width: 2,
            height: h * 0.6,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: AppColors.onSignal.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }

  /// A practice mode as a bento tile: label and icon on top, the count as a
  /// pill, the mode's name set bold at the foot — label above, value below.
  Widget _buildBentoTile(BuildContext context, VariantTokens tokens) {
    final fact = _tileFact;
    return AnimatedContainer(
      duration: AppMotion.duration(context, tokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(tokens.card),
        boxShadow: _bentoShadow,
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
              fontVariations: const [FontVariation('wght', 700)],
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
                borderRadius: BorderRadius.circular(tokens.chip),
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
                        fontVariations: const [FontVariation('wght', 600)],
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
  Widget _buildBentoSaved(BuildContext context, VariantTokens tokens) {
    return AnimatedContainer(
      duration: AppMotion.duration(context, tokens.state),
      curve: AppMotion.enter,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(tokens.card),
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
                        fontVariations: const [FontVariation('wght', 700)],
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
