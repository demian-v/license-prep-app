import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'unread_badge.dart';

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

  /// Instructors get their own three tabs (instructors plan v2 §14.1).
  final bool forInstructor;

  /// An unread count per tab, by index (plan v2 §14.1: Инструкторы for
  /// students, Чат for instructors). Missing or zero draws nothing.
  final List<int> badges;

  const SuperEnhancedFooter({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.forInstructor = false,
    this.badges = const [],
  }) : super(key: key);

  static const List<_Tab> _tabs = [
    _Tab('tests', AppIcons.tests, AppIcons.testsFilled),
    _Tab('theory', AppIcons.theory, AppIcons.theoryFilled),
    _Tab('instructors', AppIcons.instructors, AppIcons.instructorsFilled),
    _Tab('profile', AppIcons.profile, AppIcons.profileFilled),
  ];

  static const List<_Tab> _instructorTabs = [
    _Tab('calendar', AppIcons.calendar, AppIcons.calendarFilled),
    _Tab('chat', AppIcons.chat, AppIcons.chatFilled),
    _Tab('profile', AppIcons.profile, AppIcons.profileFilled),
  ];

  @override
  Widget build(BuildContext context) {
    final tabs = forInstructor ? _instructorTabs : _tabs;
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        // The bar floats, so it clears the home indicator itself rather
        // than sitting flush against it.
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.x1,
            AppSpacing.gutter,
            bottomInset > 0 ? AppSpacing.x6 : AppSpacing.x4,
          ),
          child: _MeniscusBar(
            currentIndex: currentIndex,
            onTap: onTap,
            tabs: tabs,
            badges: badges,
            labels: [
              for (final tab in tabs) _translate(tab.key, languageProvider),
            ],
          ),
        );
      },
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
                'instructors': 'Instructores',
                'profile': 'Perfil',
                'calendar': 'Calendario',
                'chat': 'Chat',
              }[key] ??
              key;
        case 'uk':
          return {
                'tests': 'Тести',
                'theory': 'Теорія',
                'instructors': 'Інструктори',
                'profile': 'Профіль',
                'calendar': 'Календар',
                'chat': 'Чат',
              }[key] ??
              key;
        case 'ru':
          return {
                'tests': 'Тесты',
                'theory': 'Теория',
                'instructors': 'Инструкторы',
                'profile': 'Профиль',
                'calendar': 'Календарь',
                'chat': 'Чат',
              }[key] ??
              key;
        case 'pl':
          return {
                'tests': 'Testy',
                'theory': 'Teoria',
                'instructors': 'Instruktorzy',
                'profile': 'Profil',
                'calendar': 'Kalendarz',
                'chat': 'Czat',
              }[key] ??
              key;
        case 'en':
        default:
          return {
                'tests': 'Tests',
                'theory': 'Theory',
                'instructors': 'Instructors',
                'profile': 'Profile',
                'calendar': 'Calendar',
                'chat': 'Chat',
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
    this.badges = const [],
  });

  final int currentIndex;
  final Function(int) onTap;
  final List<_Tab> tabs;
  final List<String> labels;
  final List<int> badges;

  int badgeAt(int i) => i < badges.length ? badges[i] : 0;

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

  // Created in initState, not lazily: a lazy controller first touched in
  // dispose() (bead never moved) looks up TickerMode on a deactivated
  // element and throws.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_tick);
  }

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

  static const double _labelSize = 11;

  TextStyle _labelStyle(bool active) => AppTypography.caption.copyWith(
        fontSize: _labelSize,
        color: active ? AppColors.signal : AppColors.inkSecondary,
        fontVariations: [FontVariation('wght', active ? 700 : 500)],
      );

  /// Each tab's centre along the bar. The gaps between tabs (and at the two
  /// ends) are equal, measured from each tab's widest content — so a short
  /// label like «Тесты» does not sit in more air than «Инструкторы». Labels
  /// are measured at the resting weight; the active one grows evenly on both
  /// sides, so nothing shifts on selection. If the labels leave too little
  /// room (very large text), fall back to equal slots.
  List<double> _centers(double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final widths = [
      for (final label in widget.labels)
        math.max(
          24.0,
          (TextPainter(
            text: TextSpan(text: label, style: _labelStyle(false)),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
            maxLines: 1,
          )..layout())
              .width,
        ),
    ];
    final gap = (width - widths.fold(0.0, (a, w) => a + w)) / (_count + 1);
    if (gap < AppSpacing.x4) {
      final slot = width / _count;
      return [for (var i = 0; i < _count; i++) (i + 0.5) * slot];
    }
    final centers = <double>[];
    var x = gap;
    for (final w in widths) {
      centers.add(x + w / 2);
      x += w + gap;
    }
    return centers;
  }

  /// The bead's x for a fractional tab position.
  static double _xAt(List<double> centers, double pos) {
    final i = pos.floor().clamp(0, centers.length - 1);
    final j = math.min(i + 1, centers.length - 1);
    return centers[i] + (centers[j] - centers[i]) * (pos - i);
  }

  int _indexAt(double dx, List<double> centers) {
    var nearest = 0;
    for (var i = 1; i < centers.length; i++) {
      if ((centers[i] - dx).abs() < (centers[nearest] - dx).abs()) nearest = i;
    }
    return nearest;
  }

  void _onDragStart(DragStartDetails _) {
    _controller.stop();
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails details, List<double> centers) {
    final reduced = AppMotion.reduced(context);
    // Tabs are unevenly spaced, so a point of drag is worth the local
    // spacing between the two tabs the bead is between.
    final i = _pos.floor().clamp(0, _count - 2);
    final step = centers[i + 1] - centers[i];
    setState(() {
      _pos = (_pos + details.delta.dx / step).clamp(0.0, _count - 1.0);
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
        final centers = _centers(width);
        final cx = _xAt(centers, _pos);
        final shown = _pos.round().clamp(0, _count - 1);
        final state = AppMotion.duration(context, AppMotion.fast);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              widget.onTap(_indexAt(d.localPosition.dx, centers)),
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, centers),
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
                    ),
                  ),
                ),
                for (var i = 0; i < _count; i++)
                  // Each tab's box is centred on its own centre, as wide as
                  // the space it owns on its narrower side.
                  Builder(builder: (context) {
                    final left = i == 0 ? 0.0 : (centers[i - 1] + centers[i]) / 2;
                    final right = i == _count - 1
                        ? width
                        : (centers[i] + centers[i + 1]) / 2;
                    final half =
                        math.min(centers[i] - left, right - centers[i]);
                    final tab = widget.tabs[i];
                    final selected = i == widget.currentIndex;
                    final active = i == shown;
                    // The icon gives way as the bead passes over its slot.
                    final visible = ((_pos - i).abs() / 0.5).clamp(0.0, 1.0);
                    return Positioned(
                      left: centers[i] - half,
                      width: half * 2,
                      top: _top,
                      height: _barHeight,
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: widget.labels[i],
                        value: widget.badgeAt(i) > 0 ? '${widget.badgeAt(i)}' : null,
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
                                style: _labelStyle(active),
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
                // Unread counts (P6), over the bead so a count on the
                // current tab stays visible: each rides its icon's top-right
                // corner, following the icon into the bead and back out.
                for (var i = 0; i < _count; i++)
                  if (widget.badgeAt(i) > 0)
                    Builder(builder: (context) {
                      final visible = ((_pos - i).abs() / 0.5).clamp(0.0, 1.0);
                      final x = cx + (centers[i] - cx) * visible;
                      final y = _beadRadius + (_top + 24 - _beadRadius) * visible;
                      return Positioned(
                        left: x + 6,
                        top: y - 20,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: UnreadBadge(count: widget.badgeAt(i)),
                          ),
                        ),
                      );
                    }),
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
  });

  final double cx;
  final double lean;

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
    // Tinted to the surface beneath, not generic black.
    canvas.drawPath(
      skin.shift(const Offset(0, 6)),
      Paint()
        ..color = const Color(0x1A0E1F4D)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(skin, Paint()..color = AppColors.paper);
    canvas.drawPath(
      skin,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MeniscusPainter old) =>
      old.cx != cx ||
      old.lean != lean;
}
