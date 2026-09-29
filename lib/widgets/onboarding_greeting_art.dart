import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The onboarding greeting drawing: a line car saying «Привет!» from a blue
/// speech bubble, on a moving road under the sun (owner's pick, 2026-09-29,
/// variant 2 of `design/onboarding/_src/greeting-variants.html`).
///
/// Every line draws itself in, 60 ms apart, over 0.82 s each. The bubble pops,
/// floods with blue and the greeting fades in. After that the scene idles: the
/// wheels spin, the road moves, the sun turns and the sparkles blink. Under
/// Reduce Motion it is drawn complete and still.
class OnboardingGreetingArt extends StatefulWidget {
  const OnboardingGreetingArt({super.key, required this.greeting});

  /// The word in the bubble, already translated.
  final String greeting;

  @override
  State<OnboardingGreetingArt> createState() => _OnboardingGreetingArtState();
}

class _OnboardingGreetingArtState extends State<OnboardingGreetingArt>
    with TickerProviderStateMixin {
  /// The draw-in, in milliseconds of [_drawMs].
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: const Duration(milliseconds: _drawMs));

  /// The idle loop. 9 s holds a whole number of every cycle in it (wheels
  /// 0.75 s, road 1 s, bob 1 s, sparkles 1.5 s, sun 9 s), so the wrap is seamless.
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 9));

  static const int _drawMs = 1700;

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _draw.value = 1;
    } else {
      _draw.forward();
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _GreetingPainter.w / _GreetingPainter.h,
      child: LayoutBuilder(builder: (context, box) {
        final s = box.maxWidth / _GreetingPainter.w;
        return AnimatedBuilder(
          animation: Listenable.merge([_draw, _loop]),
          builder: (context, _) {
            final ms = _draw.value * _drawMs;
            final pop = _GreetingPainter.popScale(ms);
            final textIn = ((ms - 700) / 420).clamp(0.0, 1.0);
            return Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GreetingPainter(ms: ms, loop: _loop.value),
                ),
              ),
              // The greeting sits in the bubble and pops with it, from the
              // bubble's tail corner.
              Positioned(
                left: 80 * s,
                top: 32 * s,
                width: 140 * s,
                height: 58 * s,
                child: Transform.scale(
                  scale: pop,
                  alignment: const Alignment(-0.9, 2.3),
                  child: Opacity(
                    opacity: textIn,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.greeting,
                        maxLines: 1,
                        style: AppTypography.display.copyWith(
                          fontSize: 30 * s,
                          height: 1,
                          color: AppColors.onSignal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        );
      }),
    );
  }
}

class _GreetingPainter extends CustomPainter {
  _GreetingPainter({required this.ms, required this.loop});

  /// Milliseconds into the draw-in.
  final double ms;

  /// 0..1 through the 9 s idle loop.
  final double loop;

  static const double w = 280;
  static const double h = 230;

  static const Color _line = AppColors.signal;
  static const Color _hill = AppColors.signal200;

  /// The bubble's pop: 0.6 → 1.06 → 1 over 0.52 s, starting at 40 ms.
  static double popScale(double ms) {
    final t = ((ms - 40) / 520).clamp(0.0, 1.0);
    if (t < 0.6) return 0.6 + 0.46 * Curves.easeOut.transform(t / 0.6);
    return 1.06 - 0.06 * Curves.easeInOut.transform((t - 0.6) / 0.4);
  }

  /// How much of element [i] is drawn: each starts 60 ms after the last.
  double _drawn(int i) =>
      Curves.easeInOutCubic.transform(((ms - i * 60) / 820).clamp(0.0, 1.0));

  Paint _stroke(double width, [Color color = _line]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  void _drawPartial(Canvas canvas, Path path, double t, Paint paint) {
    if (t <= 0) return;
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t), paint);
    }
  }

  static Path _sparkle(double x, double y, double r) => Path()
    ..moveTo(x, y - r)
    ..quadraticBezierTo(x, y, x + r, y)
    ..quadraticBezierTo(x, y, x, y + r)
    ..quadraticBezierTo(x, y, x - r, y)
    ..quadraticBezierTo(x, y, x, y - r)
    ..close();

  static final Path _sun = Path()..addOval(Rect.fromCircle(center: const Offset(256, 26), radius: 12));

  static final Path _rays = () {
    final p = Path();
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      p
        ..moveTo(256 + 20 * math.cos(a), 26 + 20 * math.sin(a))
        ..lineTo(256 + 26 * math.cos(a), 26 + 26 * math.sin(a));
    }
    return p;
  }();

  // M0,176 Q50,150 104,168 T210,160 T280,170, with the smooth controls reflected.
  static final Path _hills = Path()
    ..moveTo(0, 176)
    ..quadraticBezierTo(50, 150, 104, 168)
    ..quadraticBezierTo(158, 186, 210, 160)
    ..quadraticBezierTo(262, 134, 280, 170);

  static final Path _bubble = Path()
    ..moveTo(86, 24)
    ..lineTo(214, 24)
    ..quadraticBezierTo(228, 24, 228, 38)
    ..lineTo(228, 84)
    ..quadraticBezierTo(228, 98, 214, 98)
    ..lineTo(148, 98)
    ..lineTo(126, 118)
    ..lineTo(130, 98)
    ..lineTo(86, 98)
    ..quadraticBezierTo(72, 98, 72, 84)
    ..lineTo(72, 38)
    ..quadraticBezierTo(72, 24, 86, 24)
    ..close();

  static final Path _sparkles = Path()
    ..addPath(_sparkle(40, 44, 7), Offset.zero)
    ..addPath(_sparkle(250, 119, 6), Offset.zero);

  static final Path _speed = Path()
    ..moveTo(18, 170)
    ..lineTo(44, 170)
    ..moveTo(8, 182)
    ..lineTo(40, 182)
    ..moveTo(22, 194)
    ..lineTo(48, 194);

  static final Path _road = Path()
    ..moveTo(0, 208)
    ..lineTo(280, 208);

  // The car, in its own 200-ish box; placed with translate(20, 20) scale(.95).
  static final Path _body = Path()
    ..moveTo(68, 190)
    ..lineTo(68, 176)
    ..quadraticBezierTo(68, 166, 78, 164)
    ..lineTo(98, 161)
    ..lineTo(112, 143)
    ..quadraticBezierTo(116, 137, 124, 137)
    ..lineTo(168, 137)
    ..quadraticBezierTo(176, 137, 181, 143)
    ..lineTo(196, 161)
    ..lineTo(214, 165)
    ..quadraticBezierTo(222, 167, 222, 176)
    ..lineTo(222, 190)
    ..close();

  static final Path _windows = Path()
    ..moveTo(118, 159)
    ..lineTo(127, 147)
    ..lineTo(146, 147)
    ..lineTo(146, 159)
    ..close()
    ..moveTo(154, 159)
    ..lineTo(154, 147)
    ..lineTo(170, 147)
    ..lineTo(180, 159)
    ..close();

  static final Path _handle = Path()
    ..moveTo(208, 172)
    ..lineTo(216, 172);

  static Path _wheel(double cx) =>
      Path()..addOval(Rect.fromCircle(center: Offset(cx, 192), radius: 13));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / w;
    canvas
      ..save()
      ..scale(s)
      ..clipRect(const Rect.fromLTWH(0, 0, w, h));

    final idle = ms >= 1400 ? 1.0 : 0.0; // loops start once the lines are in
    final sec = loop * 9;

    // Sun and its turning rays.
    _drawPartial(canvas, _sun, _drawn(0), _stroke(3.4));
    canvas
      ..save()
      ..translate(256, 26)
      ..rotate(idle * loop * 2 * math.pi)
      ..translate(-256, -26);
    _drawPartial(canvas, _rays, _drawn(1), _stroke(2.2));
    canvas.restore();

    _drawPartial(canvas, _hills, _drawn(2), _stroke(2.2, _hill));

    // Bubble: pops, draws, then floods with blue.
    final pop = popScale(ms);
    canvas
      ..save()
      ..translate(118.8, 118)
      ..scale(pop)
      ..translate(-118.8, -118);
    final flood = ((ms - 560) / 380).clamp(0.0, 1.0);
    if (flood > 0) {
      canvas.drawPath(_bubble, Paint()..color = _line.withValues(alpha: flood));
    }
    _drawPartial(canvas, _bubble, _drawn(3), _stroke(3.4));
    canvas.restore();

    // Sparkles blink on a 1.5 s cycle once idle.
    final blink = idle == 0 ? 1.0 : 0.625 + 0.375 * math.cos(sec / 1.5 * 2 * math.pi);
    _drawPartial(canvas, _sparkles, _drawn(4), _stroke(2.2, _line.withValues(alpha: blink)));

    _drawPartial(canvas, _speed, _drawn(5), _stroke(2.2));
    _drawPartial(canvas, _road, _drawn(6), _stroke(3.4));

    // The dashed centre line fades in and then moves, 26 per second.
    final dashIn = ((ms - 700) / 420).clamp(0.0, 1.0);
    if (dashIn > 0) {
      final dash = _stroke(3.4, _line.withValues(alpha: dashIn));
      final phase = idle * (sec % 1) * 26;
      for (var x = -26.0 - phase; x < w + 26; x += 26) {
        canvas.drawLine(Offset(x, 222), Offset(x + 14, 222), dash);
      }
    }

    // The car bobs 1.5 at 1 Hz.
    final bob = idle * -1.5 * (1 - math.cos(sec * 2 * math.pi)) / 2;
    canvas
      ..save()
      ..translate(20, 20 + bob)
      ..scale(0.95);
    final white = Paint()..color = AppColors.paper;
    if (_drawn(7) > 0) canvas.drawPath(_body, white);
    _drawPartial(canvas, _body, _drawn(7), _stroke(3.6));
    _drawPartial(canvas, _windows, _drawn(8), _stroke(2.4));
    _drawPartial(canvas, _handle, _drawn(9), _stroke(2.4));
    for (final (i, cx) in [(10, 102.0), (11, 190.0)]) {
      final wheel = _wheel(cx);
      if (_drawn(i) > 0) canvas.drawPath(wheel, white);
      _drawPartial(canvas, wheel, _drawn(i), _stroke(3.6));
      final spokesIn = ((ms - 900) / 420).clamp(0.0, 1.0);
      if (spokesIn > 0) {
        canvas
          ..save()
          ..translate(cx, 192)
          ..rotate(idle * sec / 0.75 * 2 * math.pi);
        final spoke = _stroke(2.4, _line.withValues(alpha: spokesIn));
        canvas
          ..drawLine(const Offset(0, -8), const Offset(0, 8), spoke)
          ..drawLine(const Offset(-8, 0), const Offset(8, 0), spoke)
          ..restore();
      }
    }
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_GreetingPainter old) => old.ms != ms || old.loop != loop;
}
