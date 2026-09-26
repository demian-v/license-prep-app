import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';

/// The tab bar — the app's most persistent piece of chrome.
///
/// A floating meniscus bar (see [_MeniscusBar]): the current tab rises out of
/// the bar as a brand-blue bead sitting in a socket the bar's edge dips into.
/// Tap a tab, or drag the bead along the bar.
///
/// Labels stay on every tab, unlike the icon-only reference it borrows from.
/// The app ships in five languages to people learning another country's road
/// rules; an unlabelled glyph is a guess.
///
/// What it replaces: each tab painted a `Colors.indigo.shade700` label over an
/// indigo-tinted gradient pill, driven by three `AnimationController`s. That
/// indigo appeared nowhere else in the product and was not the brand.
class SuperEnhancedFooter extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const SuperEnhancedFooter({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  static const List<_Tab> _tabs = [
    _Tab('tests', AppIcons.tests, AppIcons.testsFilled),
    _Tab('theory', AppIcons.theory, AppIcons.theoryFilled),
    _Tab('profile', AppIcons.profile, AppIcons.profileFilled),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) =>
          ValueListenableBuilder<DesignVariant>(
        valueListenable: designVariant,
        builder: (context, variant, _) {
          final bool ledger = variant == DesignVariant.boldB;
          // The bar floats, so it clears the home indicator itself rather
          // than sitting flush against it.
          final bottomInset = MediaQuery.of(context).padding.bottom;

          // Ledger's pages are paper, not field; the bar's surround matches
          // the page so no grey band shows around it.
          return ColoredBox(
            color: ledger ? AppColors.paper : Colors.transparent,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.x1,
                AppSpacing.gutter,
                bottomInset > 0 ? AppSpacing.x6 : AppSpacing.x4,
              ),
              child: _MeniscusBar(
                currentIndex: currentIndex,
                onTap: onTap,
                tabs: _tabs,
                labels: [
                  for (final tab in _tabs)
                    _translate(tab.key, languageProvider),
                ],
                // Ledger keeps its flat, hairline character; the others float.
                edge: ledger ? AppColors.borderStrong : AppColors.border,
                floating: !ledger,
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper method to get correct translations
  String _translate(String key, LanguageProvider languageProvider) {
    try {
      switch (languageProvider.language) {
        case 'es':
          return {
                'tests': 'Pruebas',
                'theory': 'Teoría',
                'profile': 'Perfil',
              }[key] ??
              key;
        case 'uk':
          return {
                'tests': 'Тести',
                'theory': 'Теорія',
                'profile': 'Профіль',
              }[key] ??
              key;
        case 'ru':
          return {
                'tests': 'Тесты',
                'theory': 'Теория',
                'profile': 'Профиль',
              }[key] ??
              key;
        case 'pl':
          return {
                'tests': 'Testy',
                'theory': 'Teoria',
                'profile': 'Profil',
              }[key] ??
              key;
        case 'en':
        default:
          return {
                'tests': 'Tests',
                'theory': 'Theory',
                'profile': 'Profile',
              }[key] ??
              key;
      }
    } catch (e) {
      print('🚨 [SUPER FOOTER] Error getting translation: $e');
      return key;
    }
  }
}

class _Tab {
  const _Tab(this.key, this.outline, this.filled);

  final String key;
  final String outline;
  final String filled;
}

/// The meniscus bar: the current tab is a bead raised out of the bar, sitting
/// in a socket the bar's top edge dips into. The socket's shoulders are fillets
/// tangent to both the edge and the bowl, so the surface reads as one
/// continuous skin rather than a circle stamped out of a rectangle.
///
/// The bead slides to a tapped tab and can be dragged along the bar; it snaps
/// to the nearest tab on release. While it moves, the surface leans: the
/// trailing shoulder draws out and the leading one tightens, then both settle.
/// Under Reduce Motion the bead jumps and nothing leans.
class _MeniscusBar extends StatefulWidget {
  const _MeniscusBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
    required this.labels,
    required this.edge,
    required this.floating,
  });

  final int currentIndex;
  final Function(int) onTap;
  final List<_Tab> tabs;
  final List<String> labels;
  final Color edge;
  final bool floating;

  @override
  State<_MeniscusBar> createState() => _MeniscusBarState();
}

class _MeniscusBarState extends State<_MeniscusBar>
    with SingleTickerProviderStateMixin {
  /// 44pt bead: the minimum hit target, and the whole bead is the target.
  static const double _beadRadius = 22;

  /// Air between the bead and the bowl it sits in.
  static const double _gap = 4;

  /// Resting radius of each shoulder.
  static const double _fillet = 10;

  /// How far the bead's centre sits above the bar's top edge. Negative: the
  /// centre is below the edge, so the bead sits down in a deep socket and
  /// only its top third rises out of the bar.
  static const double _beadRise = -8;

  static const double _barHeight = 64;

  /// Space above the bar that the bead rises into.
  static const double _top = _beadRadius + _beadRise;

  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(_tick);

  /// Bead position in tab units: 0 is the first tab's centre.
  late double _pos = widget.currentIndex.toDouble();
  double _from = 0;
  double _to = 0;

  /// Signed lean, -1..1: positive while moving right.
  double _lean = 0;

  bool _dragging = false;

  int get _count => widget.tabs.length;

  void _tick() {
    final t = _controller.value;
    setState(() {
      _pos = _from + (_to - _from) * AppMotion.enter.transform(t);
      // Peaks mid-flight, settles to zero on arrival.
      final distance = (_to - _from).abs().clamp(0.0, 1.0);
      _lean = (_to - _from).sign * math.sin(math.pi * t) * distance;
    });
  }

  void _animateTo(int index) {
    final duration = AppMotion.duration(context, AppMotion.slow);
    _from = _pos;
    _to = index.toDouble();
    if (duration == Duration.zero || _from == _to) {
      _controller.stop();
      setState(() {
        _pos = _to;
        _lean = 0;
      });
      return;
    }
    _controller
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _MeniscusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging) return;
    final target = widget.currentIndex.toDouble();
    final alreadyHeading = _controller.isAnimating && _to == target;
    if (_pos != target && !alreadyHeading) _animateTo(widget.currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexAt(double dx, double slot) =>
      (dx / slot).floor().clamp(0, _count - 1);

  void _onDragStart(DragStartDetails _) {
    _controller.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details, double slot) {
    final reduced = AppMotion.reduced(context);
    setState(() {
      _pos = (_pos + details.delta.dx / slot).clamp(0.0, _count - 1.0);
      final push = (details.delta.dx / 8).clamp(-1.0, 1.0);
      _lean = reduced ? 0 : _lean * 0.6 + push * 0.4;
    });
  }

  void _onDragEnd([double velocity = 0]) {
    _dragging = false;
    // A flick carries on to the next tab in its direction; a slow release
    // settles on whichever tab the bead is nearest.
    const double flick = 300;
    final double target = velocity > flick
        ? _pos.ceilToDouble()
        : velocity < -flick
            ? _pos.floorToDouble()
            : _pos.roundToDouble();
    final nearest = target.toInt().clamp(0, _count - 1);
    _animateTo(nearest);
    if (nearest != widget.currentIndex) {
      widget.onTap(nearest);
      // The parent may refuse the switch (an invalid session blocks tab
      // navigation). If it did, the bead goes home instead of lying.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.currentIndex != nearest) {
          _animateTo(widget.currentIndex);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final slot = width / _count;
        final cx = (_pos + 0.5) * slot;
        final shown = _pos.round().clamp(0, _count - 1);
        final state = AppMotion.duration(context, AppMotion.fast);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => widget.onTap(_indexAt(d.localPosition.dx, slot)),
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, slot),
          // Count the drag from touch-down, not from where it cleared the
          // slop, so the bead stays under the finger.
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragEnd: (d) => _onDragEnd(d.primaryVelocity ?? 0),
          onHorizontalDragCancel: _onDragEnd,
          child: SizedBox(
            height: _top + _barHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: _top,
                  height: _barHeight,
                  child: CustomPaint(
                    painter: _MeniscusPainter(
                      cx: cx,
                      lean: _lean,
                      edge: widget.edge,
                      floating: widget.floating,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: _top,
                  height: _barHeight,
                  child: Row(
                    children: List.generate(_count, (i) {
                      final tab = widget.tabs[i];
                      final selected = i == widget.currentIndex;
                      final active = i == shown;
                      // The icon gives way as the bead passes over its slot.
                      final visible = ((_pos - i).abs() / 0.5).clamp(0.0, 1.0);
                      return Expanded(
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: widget.labels[i],
                          onTap: () => widget.onTap(i),
                          child: ExcludeSemantics(
                            child: Column(
                              children: [
                                const SizedBox(height: AppSpacing.x3),
                                Opacity(
                                  opacity: visible,
                                  child: AppIcons.icon(
                                    tab.outline,
                                    size: 24,
                                    color: AppColors.inkSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.x1),
                                AnimatedDefaultTextStyle(
                                  duration: state,
                                  style: AppTypography.caption.copyWith(
                                    fontSize: 11,
                                    color: active
                                        ? AppColors.signal
                                        : AppColors.inkSecondary,
                                    fontVariations: [
                                      FontVariation('wght', active ? 700 : 500),
                                    ],
                                  ),
                                  child: Text(
                                    widget.labels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // The bead: brand blue, because it marks "you are here".
                Positioned(
                  left: cx - _beadRadius,
                  top: 0,
                  child: ExcludeSemantics(
                    child: Container(
                      width: _beadRadius * 2,
                      height: _beadRadius * 2,
                      decoration: const BoxDecoration(
                        color: AppColors.signal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4D0048C3),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: state,
                        switchInCurve: AppMotion.enter,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                          scale: Tween<double>(begin: 0.6, end: 1)
                              .animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(shown),
                          child: AppIcons.icon(
                            widget.tabs[shown].filled,
                            size: 22,
                            color: AppColors.onSignal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Paints the bar's skin: a rounded bar whose top edge dips into a socket
/// around the bead, joined by two fillet shoulders.
///
/// Each shoulder is a circle of radius r tangent to the top edge (centre at
/// y = r) and externally tangent to the bowl (radius R, centre at the bead),
/// so its horizontal reach from the bead is sqrt((R + r)² − (r − cy)²).
class _MeniscusPainter extends CustomPainter {
  _MeniscusPainter({
    required this.cx,
    required this.lean,
    required this.edge,
    required this.floating,
  });

  final double cx;
  final double lean;
  final Color edge;
  final bool floating;

  static const double _corner = AppRadius.xl;

  /// Share of the fillet radius the shoulders trade while moving.
  static const double _leanAmount = 0.25;

  Path _skin(Size size) {
    const double bowl = _MeniscusBarState._beadRadius + _MeniscusBarState._gap;
    const double cy = -_MeniscusBarState._beadRise;
    final double w = size.width;
    final double h = size.height;

    // Moving right, the left shoulder trails (draws out) and the right one
    // leads (tightens); moving left, the reverse.
    final double rL = _MeniscusBarState._fillet * (1 + _leanAmount * lean);
    final double rR = _MeniscusBarState._fillet * (1 - _leanAmount * lean);
    double reach(double r) =>
        math.sqrt(math.pow(bowl + r, 2) - math.pow(r - cy, 2));
    final double dL = reach(rL);
    final double dR = reach(rR);
    final double thL = math.atan2(cy - rL, dL);
    final double thR = math.atan2(cy - rR, dR);

    return Path()
      ..moveTo(_corner, 0)
      ..lineTo(cx - dL, 0)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx - dL, rL), radius: rL),
        -math.pi / 2,
        thL + math.pi / 2,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: bowl),
        math.pi + thL,
        -(math.pi + thL + thR),
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx + dR, rR), radius: rR),
        math.pi - thR,
        math.pi / 2 + thR,
        false,
      )
      ..lineTo(w - _corner, 0)
      ..arcToPoint(Offset(w, _corner), radius: const Radius.circular(_corner))
      ..lineTo(w, h - _corner)
      ..arcToPoint(Offset(w - _corner, h),
          radius: const Radius.circular(_corner))
      ..lineTo(_corner, h)
      ..arcToPoint(Offset(0, h - _corner),
          radius: const Radius.circular(_corner))
      ..lineTo(0, _corner)
      ..arcToPoint(const Offset(_corner, 0),
          radius: const Radius.circular(_corner))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final skin = _skin(size);
    if (floating) {
      // Tinted to the surface beneath, not generic black.
      canvas.drawPath(
        skin.shift(const Offset(0, 6)),
        Paint()
          ..color = const Color(0x1A0E1F4D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.drawPath(skin, Paint()..color = AppColors.paper);
    canvas.drawPath(
      skin,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MeniscusPainter old) =>
      old.cx != cx ||
      old.lean != lean ||
      old.edge != edge ||
      old.floating != floating;
}
