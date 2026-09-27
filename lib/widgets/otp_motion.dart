import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/solar_icons.dart';

/// The code boxes of the email check, and their motion (owner, 2026-09-26,
/// after the code.xr "OTP Verification V7" reel):
///
/// 1. [gather] 0 → 1 — while the code is being checked, the row of boxes
///    regroups into a 2 × 3 grid and a blue line draws a loop through them.
///    Played back to 0 if the code is refused.
/// 2. [collapse] 0 → 1 — the code was accepted: the digits fade and the boxes
///    fold into one square.
/// 3. [burst] 0 → 1 — the square bursts into green particles and a ✓ settles
///    in its place.
///
/// Presentation only. The boxes themselves ([boxBuilder]) stay the screen's
/// real text fields throughout, so typing, paste and focus are unchanged.
/// Blue is the current step, green is done — the app's colour meanings.
class OtpBoxesMotion extends StatelessWidget {
  const OtpBoxesMotion({
    super.key,
    required this.length,
    required this.boxBuilder,
    required this.gather,
    required this.collapse,
    required this.burst,
  });

  final int length;
  final Widget Function(int index) boxBuilder;
  final Animation<double> gather;
  final Animation<double> collapse;
  final Animation<double> burst;

  static const double _rowHeight = 56;
  static const double _gap = AppSpacing.x2;
  static const double _cell = 56;
  static const double _gridGap = AppSpacing.x6;
  static const int _cols = 3;

  /// The loop the connector draws through the grid: across the top, down,
  /// back along the bottom, and up to close.
  static const List<int> _loop = [0, 1, 2, 5, 4, 3, 0];

  double get _gridHeight => 2 * _cell + _gridGap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([gather, collapse, burst]),
      builder: (context, _) {
        final g = AppMotion.enter.transform(gather.value);
        final c = AppMotion.enter.transform(collapse.value);
        final b = burst.value;
        return LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final height = _lerp(_rowHeight, _gridHeight, g);

          final rowBox = (w - _gap * (length - 1)) / length;
          final gridWidth = _cols * _cell + (_cols - 1) * _gridGap;
          final gridLeft = (w - gridWidth) / 2;
          final centre = Offset(w / 2, _gridHeight / 2);

          Rect rowRect(int i) =>
              Rect.fromLTWH(i * (rowBox + _gap), 0, rowBox, _rowHeight);
          Rect gridRect(int i) => Rect.fromLTWH(
                gridLeft + (i % _cols) * (_cell + _gridGap),
                (i ~/ _cols) * (_cell + _gridGap),
                _cell,
                _cell,
              );
          final folded = Rect.fromCenter(center: centre, width: _cell + 8, height: _cell + 8);

          Rect boxRect(int i) {
            final laidOut = Rect.lerp(rowRect(i), gridRect(i), g)!;
            return Rect.lerp(laidOut, folded, c)!;
          }

          // The line draws in the second half of the gather and leaves as the
          // boxes fold.
          final lineProgress = ((g - 0.45) / 0.55).clamp(0.0, 1.0);
          final lineOpacity = (1 - c * 1.6).clamp(0.0, 1.0);
          // The folded square gives way to the burst.
          final boxesOpacity = (1 - b * 3).clamp(0.0, 1.0);

          return SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (lineProgress > 0 && lineOpacity > 0)
                  Positioned.fill(
                    key: const ValueKey('otp-line'),
                    child: CustomPaint(
                      painter: _LoopPainter(
                        points: [for (final i in _loop) gridRect(i).center],
                        progress: lineProgress,
                        opacity: lineOpacity,
                      ),
                    ),
                  ),
                // Keyed: the layers around the boxes come and go, and without
                // keys a box would inherit its neighbour's text-field state —
                // focus on one box, typing landing in the next.
                for (var i = 0; i < length; i++)
                  Positioned.fromRect(
                    key: ValueKey('otp-box-$i'),
                    rect: boxRect(i),
                    child: IgnorePointer(
                      // Once the code is sent the boxes are only shown.
                      ignoring: g > 0,
                      child: Opacity(
                        opacity: boxesOpacity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // The box itself stays solid while its digit
                            // fades, so the fold reads as boxes merging into
                            // one square, not boxes vanishing. Always present:
                            // adding it mid-way would rebuild the field below
                            // and its autofocus would grab focus again.
                            DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppColors.field,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                ),
                              ),
                            Opacity(
                              // Digits fade first as the boxes fold.
                              opacity: (1 - c * 1.8).clamp(0.0, 1.0),
                              child: boxBuilder(i),
                            ),
                            // The reel's corner accent: a blue arc on the
                            // lower-right corner of each box while checking.
                            if (g > 0)
                              IgnorePointer(
                                child: CustomPaint(
                                  painter: _CornerPainter(opacity: g * (1 - c)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (b > 0) ...[
                  Positioned.fill(
                    key: const ValueKey('otp-burst'),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BurstPainter(progress: b, centre: centre),
                      ),
                    ),
                  ),
                  Positioned(
                    key: const ValueKey('otp-tick'),
                    left: centre.dx - 44,
                    top: centre.dy - 44,
                    child: _Tick(progress: b),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// The ✓ in a soft green square inside a faint rounded ring, settling in.
class _Tick extends StatelessWidget {
  const _Tick({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final t = AppMotion.enter.transform((progress / 0.55).clamp(0.0, 1.0));
    return Opacity(
      opacity: t,
      child: Transform.scale(
        scale: 0.6 + 0.4 * t,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.guide.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.guideSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.guide, width: 1.5),
            ),
            alignment: Alignment.center,
            child: const Icon(SolarIcons.checkLinear, color: AppColors.guide, size: 26),
          ),
        ),
      ),
    );
  }
}

/// The connector: a polyline through the box centres, drawn to [progress]
/// of its length.
class _LoopPainter extends CustomPainter {
  _LoopPainter({required this.points, required this.progress, required this.opacity});

  final List<Offset> points;
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final paint = Paint()
      ..color = AppColors.signal.withValues(alpha: 0.45 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_LoopPainter old) =>
      old.progress != progress || old.opacity != opacity || old.points != points;
}

/// A short blue arc hugging a box's lower-right corner.
class _CornerPainter extends CustomPainter {
  _CornerPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    const r = AppRadius.lg;
    final paint = Paint()
      ..color = AppColors.signal.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width, size.height * 0.45)
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height), radius: const Radius.circular(r))
      ..lineTo(size.width * 0.55, size.height);
    canvas.drawPath(path.shift(const Offset(-1, -1)), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.opacity != opacity;
}

/// Green squares and diamonds flying out from the folded square, easing out
/// and fading. Seeded, so every run draws the same burst.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.centre});

  final double progress;
  final Offset centre;

  static final List<_Particle> _particles = () {
    final rnd = math.Random(7);
    return List.generate(34, (i) {
      final angle = (i / 34) * 2 * math.pi + rnd.nextDouble() * 0.5;
      return _Particle(
        direction: Offset(math.cos(angle), math.sin(angle)),
        distance: 50 + rnd.nextDouble() * 120,
        size: 3 + rnd.nextDouble() * 4.5,
        delay: rnd.nextDouble() * 0.18,
        diamond: rnd.nextBool(),
        alpha: 0.45 + rnd.nextDouble() * 0.55,
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _particles) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final travel = AppMotion.enter.transform(t);
      final fadeIn = (t / 0.12).clamp(0.0, 1.0);
      final fadeOut = 1 - ((t - 0.55) / 0.45).clamp(0.0, 1.0);
      paint.color = AppColors.guide.withValues(alpha: p.alpha * fadeIn * fadeOut);
      final at = centre + p.direction * (p.distance * travel);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      if (p.diamond) canvas.rotate(math.pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
          const Radius.circular(1),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress || old.centre != centre;
}

class _Particle {
  const _Particle({
    required this.direction,
    required this.distance,
    required this.size,
    required this.delay,
    required this.diamond,
    required this.alpha,
  });

  final Offset direction;
  final double distance;
  final double size;
  final double delay;
  final bool diamond;
  final double alpha;
}
