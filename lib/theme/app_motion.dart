import 'package:flutter/material.dart';

/// Motion tokens.
///
/// Durations and curves are named here rather than written inline, because
/// *which* easing and duration you pick, and why, is the part of a transition
/// that carries meaning — and the part that gets lost when every widget invents
/// its own `Duration(milliseconds: 300)`.
///
/// Rules this file encodes:
///   * entrances decelerate, exits accelerate — never the same curve both ways;
///   * nothing on a quiz screen animates longer than [base]: a learner waiting
///     on a verdict reads delay as lag, not polish;
///   * no ambient or looping motion anywhere near reading content.
class AppMotion {
  const AppMotion._();

  /// Radio fill, checkbox, ripple.
  static const Duration instant = Duration(milliseconds: 100);

  /// Button press, chip selection.
  static const Duration fast = Duration(milliseconds: 180);

  /// Card expand, answer reveal. The ceiling on quiz screens.
  static const Duration base = Duration(milliseconds: 240);

  /// Sheets, banners.
  static const Duration slow = Duration(milliseconds: 320);

  /// Screen transitions.
  static const Duration page = Duration(milliseconds: 380);

  /// Entrances: fast out of the gate, settling gently.
  static const Curve enter = Curves.easeOutCubic;

  /// Exits: the reverse, so leaving feels like leaving.
  static const Curve exit = Curves.easeInCubic;

  /// Presses want a little weight without bounce.
  static const Curve press = Curves.easeOut;

  /// A short, contained overshoot (~4%) for the Signal variant. Springy enough
  /// to read as physical, damped enough that it settles inside [base].
  static const Curve spring = Cubic(0.34, 1.32, 0.64, 1);

  /// A crisp decelerate with no overshoot, for the Ledger variant.
  static const Curve crisp = Cubic(0.2, 0, 0, 1);

  /// Gap between siblings in a staggered entrance.
  static const Duration stagger = Duration(milliseconds: 24);

  /// True when the platform or the user has asked for reduced motion.
  ///
  /// Every animated widget in the design system checks this and collapses to
  /// [Duration.zero] rather than simply running faster.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// A duration that respects the reduce-motion setting.
  static Duration duration(BuildContext context, Duration value) =>
      reduced(context) ? Duration.zero : value;
}

/// A shared-axis forward transition, used when moving deeper into a flow.
///
/// Home → exam is not a neutral navigation: it starts a timed, 40-question
/// test. The outgoing screen recedes slightly while the incoming one arrives
/// from the trailing edge, which reads as entering something rather than
/// swapping between peers.
class ForwardPageRoute<T> extends PageRouteBuilder<T> {
  ForwardPageRoute({required this.child, super.settings})
      : super(
          transitionDuration: AppMotion.page,
          reverseTransitionDuration: AppMotion.base,
          pageBuilder: (_, __, ___) => child,
        );

  final Widget child;

  /// Recede only beneath another full page. A translucent route on top — the
  /// full-screen question image — would otherwise slide this page sideways
  /// behind its scrim and expose a strip of black at the edge.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is PageRoute && nextRoute.opaque;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;

    final incoming = CurvedAnimation(parent: animation, curve: AppMotion.enter);
    final outgoing =
        CurvedAnimation(parent: secondaryAnimation, curve: AppMotion.enter);

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(incoming),
      child: FadeTransition(
        opacity: incoming,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.03, 0),
          ).animate(outgoing),
          child: child,
        ),
      ),
    );
  }
}

/// A one-shot entrance: fade plus a short rise, delayed by [index] steps of
/// [AppMotion.stagger]. Runs once on mount and never loops. Under Reduce
/// Motion the child is shown immediately.
///
/// [total] caps the whole cascade, so a list of [count] items finishes inside
/// it regardless of length — the Tests screen keeps its entrance under
/// [AppMotion.base].
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.count,
    required this.child,
    this.total = AppMotion.base,
    this.step = AppMotion.stagger,
    this.rise = 8,
    this.curve = AppMotion.enter,
  });

  final int index;
  final int count;
  final Duration total;
  final Duration step;
  final double rise;
  final Curve curve;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.total);
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    final totalMs = widget.total.inMilliseconds;
    final stepMs = widget.step.inMilliseconds;
    final itemMs = (totalMs - stepMs * (widget.count - 1)).clamp(1, totalMs);
    final start = (stepMs * widget.index / totalMs).clamp(0.0, 1.0);
    final end = ((stepMs * widget.index + itemMs) / totalMs).clamp(start, 1.0);
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: widget.curve),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, widget.rise * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}

/// Gives under the finger: scales to [scale] while pressed. Pointer-only — it
/// does not consume taps, so the child's own gesture handling is unchanged.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.98,
    this.duration = AppMotion.fast,
    this.curve = AppMotion.press,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled ? (_) => _set(true) : null,
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && widget.enabled ? widget.scale : 1,
        duration: AppMotion.duration(context, widget.duration),
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
