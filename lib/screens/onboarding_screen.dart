import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_question_parts.dart' show bentoRoundIconStyle;
import '../widgets/onboarding_greeting_art.dart';
import '../widgets/onboarding_shots.dart';

/// Whether this device has seen the first-run onboarding.
///
/// Per device (owner, 2026-09-29): a reinstall shows it again, and
/// «Сбросить настройки» clears it so it can be replayed.
abstract final class OnboardingGate {
  static const String prefsKey = 'onboarding_seen_v1';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(prefsKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }
}

/// The first-run onboarding, shown over HomeScreen the first time it opens.
///
/// One Line-style greeting card, then six **screenshot steps**: a real
/// screenshot of the app, dimmed, with one element and its tab lifted out and
/// ringed. It never navigates into the real screens, which is the point: the
/// app loads its content underneath meanwhile. «Начать» zooms the Tests
/// screenshot to full screen, dips it into the plain page, and fades in the
/// real Tests tab.
///
/// Prototype and decisions: `design/onboarding/`. Screenshots and their rects
/// come from `design/onboarding/_src/export_onboarding_assets.py`.
/// Инструкторы is left out on purpose: it gets its own onboarding
/// (`design/prompts/next-session-onboarding-instructors.md`).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  /// Called once, after «Начать» or «Пропустить» has played out.
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Step {
  const _Step(this.title, this.body, {this.screen, this.element});

  /// null for the greeting card.
  final String? screen;

  /// The lifted card on [screen]; null lifts only the tab.
  final String? element;

  final String title;
  final String body;
}

/// The Next button's travel: a spring with a little overshoot.
const Curve _spring = Cubic(0.34, 1.5, 0.64, 1);

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _i = 0;

  /// +1 moving forward, -1 moving back: which way a screenshot swap slides.
  int _dir = 1;

  /// The screenshot on stage.
  String _screen = 'tests';

  /// The step whose highlight is showing; null while the stage moves.
  int? _marks;
  int _marksToken = 0;

  /// Bumped each time the greeting comes back, so its drawing redraws.
  int _greetingRun = 0;

  bool _finishing = false;

  /// 0 = greeting card, 1 = screenshot stage.
  late final AnimationController _tour =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 640));

  /// The final zoom of the screenshot into the full screen.
  late final AnimationController _zoom =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 720));

  /// After the zoom, the screenshot dips into the plain page before the real
  /// screen fades in. The screenshots have no trial card and the real Tests
  /// screen does, so a straight crossfade would show the content jump down.
  late final AnimationController _dip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 180));

  /// The fade into the real app after the zoom.
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  bool get _reduced => AppMotion.reduced(context);

  Duration _ms(int ms) => _reduced ? Duration.zero : Duration(milliseconds: ms);

  String get _locale {
    final lang = Localizations.localeOf(context).languageCode;
    if (onboardingShotLocales.contains(lang)) return lang;
    return onboardingShotLocales.contains('en') ? 'en' : onboardingShotLocales.first;
  }

  String _asset(String screen) => 'assets/images/onboarding/$_locale/$screen.webp';

  Rect _rect(String key) => onboardingShotRects[_locale]![key]!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final screen in const ['tests', 'theory', 'profile']) {
      precacheImage(AssetImage(_asset(screen)), context);
    }
  }

  @override
  void dispose() {
    _tour.dispose();
    _zoom.dispose();
    _dip.dispose();
    _fade.dispose();
    super.dispose();
  }

  List<_Step> _steps(AppLocalizations l) => [
        _Step(l.translate('onboarding_welcome_title'), l.translate('onboarding_welcome_body')),
        _Step(l.translate('onboarding_tests_title'), l.translate('onboarding_tests_body'),
            screen: 'tests'),
        _Step(l.translate('onboarding_exam_title'), l.translate('onboarding_exam_body'),
            screen: 'tests', element: 'hero'),
        _Step(l.translate('onboarding_topics_title'), l.translate('onboarding_topics_body'),
            screen: 'tests', element: 'tiles'),
        _Step(l.translate('onboarding_mistakes_title'), l.translate('onboarding_mistakes_body'),
            screen: 'tests', element: 'mistakes'),
        _Step(l.translate('onboarding_theory_title'), l.translate('onboarding_theory_body'),
            screen: 'theory', element: 'module'),
        _Step(l.translate('onboarding_profile_title'), l.translate('onboarding_profile_body'),
            screen: 'profile', element: 'settings'),
      ];

  void _showMarksAfter(int ms) {
    final token = ++_marksToken;
    if (ms == 0 || _reduced) {
      setState(() => _marks = _i);
      return;
    }
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && token == _marksToken && !_finishing) setState(() => _marks = _i);
    });
  }

  void _go(int i, List<_Step> steps) {
    if (_finishing || i < 0 || i >= steps.length) return;
    final prev = _i;
    final next = steps[i];
    final wasTour = prev > 0;
    setState(() {
      _i = i;
      _dir = i > prev ? 1 : -1;
      _marks = null;
      _marksToken++;
    });
    if (next.screen == null) {
      // Back to the greeting: the stage sinks away and the drawing redraws.
      setState(() => _greetingRun++);
      _tour.animateBack(0, duration: _ms(420), curve: AppMotion.exit);
      return;
    }
    if (!wasTour) {
      setState(() => _screen = next.screen!);
      _tour.animateTo(1, duration: _ms(640), curve: AppMotion.enter);
      _showMarksAfter(900);
    } else if (next.screen != _screen) {
      setState(() => _screen = next.screen!);
      _showMarksAfter(600);
    } else {
      _showMarksAfter(0);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _marks = null;
      _marksToken++;
    });
    if (_i == 0) {
      // Skipped from the greeting: nothing to zoom, just step aside.
      await _fade.animateTo(1, duration: _ms(260));
    } else {
      if (_screen != 'tests') {
        setState(() {
          _dir = -1;
          _screen = 'tests';
        });
        await Future<void>.delayed(_ms(560));
      }
      await _zoom.animateTo(1, duration: _ms(720), curve: const Cubic(0.65, 0, 0.2, 1));
      await _dip.animateTo(1, duration: _ms(180), curve: AppMotion.exit);
      await _fade.animateTo(1, duration: _ms(260), curve: AppMotion.enter);
    }
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final steps = _steps(l);
    final step = steps[_i];
    final media = MediaQuery.of(context);
    final size = media.size;
    final top = media.padding.top + AppSpacing.x1;
    final navBottom = media.padding.bottom > 0 ? media.padding.bottom + AppSpacing.x3 : AppSpacing.x6;

    // Vertical budget: top bar, stage, copy, Next.
    const barH = 44.0;
    const navH = 56.0;
    const copyH = 112.0;
    final contentTop = top + barH + AppSpacing.x3;
    final contentBottom = size.height - navBottom - navH - AppSpacing.x6;
    final aspect = onboardingShotSize.height / onboardingShotSize.width;
    final shotW = (size.width * 0.6)
        .clamp(0.0, (contentBottom - contentTop - copyH - AppSpacing.x4) / aspect)
        .toDouble();
    final shotRect = Rect.fromLTWH((size.width - shotW) / 2, contentTop, shotW, shotW * aspect);
    // The zoom ends covering the screen, centred.
    final fullW = (size.height / aspect).clamp(size.width, double.infinity).toDouble();
    final fullRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: fullW,
      height: fullW * aspect,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _i > 0) _go(_i - 1, steps);
      },
      child: FadeTransition(
        opacity: ReverseAnimation(_fade),
        child: Material(
          color: AppColors.field,
          child: AnimatedBuilder(
            animation: Listenable.merge([_tour, _zoom, _dip]),
            builder: (context, _) {
              final t = _tour.value;
              final z = _zoom.value;
              final chrome = (1 - z * 2).clamp(0.0, 1.0);
              return Stack(children: [
                // Greeting card.
                if (t < 1)
                  Positioned(
                    left: AppSpacing.gutter,
                    right: AppSpacing.gutter,
                    top: contentTop,
                    bottom: size.height - contentBottom,
                    child: Opacity(
                      opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1 - 0.06 * t,
                        child: _GreetingCard(
                          key: ValueKey(_greetingRun),
                          greeting: l.translate('onboarding_hello'),
                          title: steps[0].title,
                          body: steps[0].body,
                        ),
                      ),
                    ),
                  ),
                // Screenshot stage.
                if (t > 0)
                  Positioned.fromRect(
                    rect: Rect.lerp(shotRect, fullRect, z)!,
                    child: Opacity(
                      opacity: ((t - 0.3) / 0.7).clamp(0.0, 1.0) * (1 - _dip.value),
                      child: Transform.translate(
                        offset: Offset(0, 60 * (1 - _spring.transform(t.clamp(0.0, 1.0)))),
                        child: _Stage(
                          screen: _screen,
                          dir: _dir,
                          asset: _asset,
                          lifted: _marks == null
                              ? const []
                              : [
                                  _rect('${steps[_marks!].screen}.tab'),
                                  if (steps[_marks!].element != null)
                                    _rect('${steps[_marks!].screen}.${steps[_marks!].element}'),
                                ],
                          liftKey: _marks,
                          ring: _marks == null
                              ? null
                              : _rect(steps[_marks!].element == null
                                  ? '${steps[_marks!].screen}.tab'
                                  : '${steps[_marks!].screen}.${steps[_marks!].element}'),
                          onRingTap: () => _i < steps.length - 1 ? _go(_i + 1, steps) : _finish(),
                          swap: _ms(560),
                        ),
                      ),
                    ),
                  ),
                // Step copy under the screenshot.
                if (t > 0)
                  Positioned(
                    left: AppSpacing.x6,
                    right: AppSpacing.x6,
                    top: shotRect.bottom + AppSpacing.x4,
                    child: Opacity(
                      opacity: (((t - 0.4) / 0.6).clamp(0.0, 1.0)) * chrome,
                      child: _Copy(
                        key: ValueKey('copy-$_i'),
                        title: step.screen == null ? '' : step.title,
                        body: step.screen == null ? '' : step.body,
                        titleStyle: AppTypography.heading,
                      ),
                    ),
                  ),
                // Back and Skip.
                Positioned(
                  left: AppSpacing.gutter,
                  top: top,
                  child: Opacity(
                    opacity: chrome,
                    child: IgnorePointer(
                      ignoring: _i == 0 || _finishing,
                      child: AnimatedOpacity(
                        opacity: _i == 0 ? 0 : 1,
                        duration: _ms(250),
                        child: IconButton(
                          tooltip: l.translate('back'),
                          style: bentoRoundIconStyle,
                          icon: const Icon(SolarIcons.arrowLeftLinear, color: AppColors.ink, size: 24),
                          onPressed: () => _go(_i - 1, steps),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: AppSpacing.x2,
                  top: top,
                  height: barH,
                  child: Opacity(
                    opacity: chrome,
                    child: TextButton(
                      onPressed: _finishing ? null : _finish,
                      style: TextButton.styleFrom(foregroundColor: AppColors.inkSecondary),
                      child: Text(
                        l.translate('skip'),
                        style: AppTypography.label.copyWith(fontSize: 15, color: AppColors.inkSecondary),
                      ),
                    ),
                  ),
                ),
                // Next.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: navBottom,
                  height: navH,
                  child: Opacity(
                    opacity: chrome,
                    child: Center(
                      child: _NextBar(
                        count: steps.length,
                        index: _i,
                        label: _i == 0
                            ? l.translate('onboarding_lets_go')
                            : l.translate('onboarding_start'),
                        tooltip: l.translate('next'),
                        duration: _ms(550),
                        onTap: () => _i < steps.length - 1 ? _go(_i + 1, steps) : _finish(),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

/// The white greeting card: the drawing, then the welcome copy.
class _GreetingCard extends StatelessWidget {
  const _GreetingCard({super.key, required this.greeting, required this.title, required this.body});

  final String greeting;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BentoTokens.card),
        child: LayoutBuilder(builder: (context, box) {
          // The drawing gives way first on a short screen: its height is
          // capped so the copy under it always fits.
          final copy = Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x6),
            child: _Copy(title: title, body: body, titleStyle: AppTypography.title, stagger: true),
          );
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: (box.maxHeight - 220).clamp(0.0, double.infinity)),
                child: OnboardingGreetingArt(greeting: greeting),
              ),
              const SizedBox(height: AppSpacing.x6),
              copy,
            ],
          );
        }),
      ),
    );
  }
}

/// A title and a line of text that rise in; keyed per step so each step
/// replays it.
class _Copy extends StatefulWidget {
  const _Copy({super.key, required this.title, required this.body, required this.titleStyle, this.stagger = false});

  final String title;
  final String body;
  final TextStyle titleStyle;

  /// The greeting waits for its drawing to start before the copy rises.
  final bool stagger;

  @override
  State<_Copy> createState() => _CopyState();
}

class _CopyState extends State<_Copy> with SingleTickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_in.status != AnimationStatus.dismissed) return;
    if (AppMotion.reduced(context)) {
      _in.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: widget.stagger ? 250 : 120), () {
        if (mounted) _in.forward();
      });
    }
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Widget _rise(Widget child, double from) {
    final a = CurvedAnimation(parent: _in, curve: Interval(from, 1, curve: AppMotion.enter));
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _rise(
        Text(widget.title, textAlign: TextAlign.center, style: widget.titleStyle),
        0,
      ),
      const SizedBox(height: AppSpacing.x2),
      _rise(
        Text(
          widget.body,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(fontSize: 15, height: 22 / 15, color: AppColors.inkSecondary),
        ),
        0.15,
      ),
    ]);
  }
}

/// The screenshot card, drawn in the screenshot's own 360×783 space and
/// scaled to fit. A new screen swaps the card sideways like a page.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.screen,
    required this.dir,
    required this.asset,
    required this.lifted,
    required this.liftKey,
    required this.ring,
    required this.onRingTap,
    required this.swap,
  });

  final String screen;
  final int dir;
  final String Function(String screen) asset;
  final List<Rect> lifted;
  final int? liftKey;
  final Rect? ring;
  final VoidCallback onRingTap;
  final Duration swap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: swap,
      switchInCurve: const Cubic(0.34, 1.3, 0.64, 1),
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(screen);
        final dx = incoming ? 90.0 * dir : -80.0 * dir;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final v = animation.value;
            return Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(dx * (1 - v), 0),
                child: Transform.rotate(
                  angle: (incoming ? 5 : -5) * dir * (1 - v) * 3.14159 / 180,
                  child: Transform.scale(scale: 0.94 + 0.06 * v, child: child),
                ),
              ),
            );
          },
        );
      },
      child: _ShotCard(
        key: ValueKey(screen),
        image: AssetImage(asset(screen)),
        lifted: lifted,
        liftKey: liftKey,
        ring: ring,
        onRingTap: onRingTap,
      ),
    );
  }
}

class _ShotCard extends StatelessWidget {
  const _ShotCard({
    super.key,
    required this.image,
    required this.lifted,
    required this.liftKey,
    required this.ring,
    required this.onRingTap,
  });

  final ImageProvider image;
  final List<Rect> lifted;
  final int? liftKey;
  final Rect? ring;
  final VoidCallback onRingTap;

  static const double _radius = 48;

  @override
  Widget build(BuildContext context) {
    final w = onboardingShotSize.width;
    final h = onboardingShotSize.height;
    final shot = Image(image: image, width: w, height: h, fit: BoxFit.fill, gaplessPlayback: true);
    return LayoutBuilder(builder: (context, box) {
      final k = box.maxWidth / w;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius * k),
          boxShadow: AppColors.shadowRaised,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius * k),
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(children: [
                shot,
                // Dim everything, then lift the highlighted pieces back out.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: lifted.isEmpty ? 0 : 1,
                      duration: AppMotion.duration(context, const Duration(milliseconds: 350)),
                      child: ColoredBox(color: AppColors.ink.withValues(alpha: 0.64)),
                    ),
                  ),
                ),
                for (final (n, r) in lifted.indexed)
                  _LiftedPiece(key: ValueKey('$liftKey-$n'), rect: r, radius: n == 0 ? 26 : 24, shot: shot),
                if (ring != null) _Ring(rect: ring!, onTap: onRingTap),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

/// A piece of the screenshot, cut out above the dim layer, that pops once.
class _LiftedPiece extends StatefulWidget {
  const _LiftedPiece({super.key, required this.rect, required this.radius, required this.shot});

  final Rect rect;
  final double radius;
  final Widget shot;

  @override
  State<_LiftedPiece> createState() => _LiftedPieceState();
}

class _LiftedPieceState extends State<_LiftedPiece> with SingleTickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 560));

  static final Animatable<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.045).chain(CurveTween(curve: Curves.easeOut)), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.045, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 55),
  ]);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pop.status == AnimationStatus.dismissed && !AppMotion.reduced(context)) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) _pop.forward();
      });
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rect;
    return Positioned.fromRect(
      rect: r,
      child: ScaleTransition(
        scale: _scale.animate(_pop),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: onboardingShotSize.width,
            maxWidth: onboardingShotSize.width,
            minHeight: onboardingShotSize.height,
            maxHeight: onboardingShotSize.height,
            child: Transform.translate(offset: -r.topLeft, child: widget.shot),
          ),
        ),
      ),
    );
  }
}

/// The white ring around the highlight. It springs to each new target and
/// pulses; tapping it is the same as Next.
class _Ring extends StatefulWidget {
  const _Ring({required this.rect, required this.onTap});

  final Rect rect;
  final VoidCallback onTap;

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_pulse.isAnimating) _pulse.repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rect.inflate(6);
    final ring = BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: AppColors.paper, width: 2),
    );
    return AnimatedPositioned.fromRect(
      rect: r,
      duration: AppMotion.duration(context, const Duration(milliseconds: 500)),
      curve: const Cubic(0.34, 1.3, 0.64, 1),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: DecoratedBox(decoration: ring)),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final v = Curves.easeOut.transform(_pulse.value);
                return Opacity(
                  opacity: 0.7 * (1 - v),
                  child: Transform.scale(scaleX: 1 + 0.06 * v, scaleY: 1 + 0.12 * v, child: DecoratedBox(decoration: ring)),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Dots and the round Next button that springs from dot to dot. On the first
/// and last step it widens into a pill with a label («Начнём», «Начать»).
class _NextBar extends StatelessWidget {
  const _NextBar({
    required this.count,
    required this.index,
    required this.label,
    required this.tooltip,
    required this.duration,
    required this.onTap,
  });

  final int count;
  final int index;
  final String label;
  final String tooltip;
  final Duration duration;
  final VoidCallback onTap;

  static const double _dot = 16;
  static const double _slot = 72;
  static const double _button = 56;
  static const double _pill = 176;

  double _centre(int k) {
    var x = 0.0;
    for (var m = 0; m < k; m++) {
      x += m == index ? _slot : _dot;
    }
    return x + (k == index ? _slot / 2 : _dot / 2);
  }

  @override
  Widget build(BuildContext context) {
    final width = (count - 1) * _dot + _slot;
    final wide = index == 0 || index == count - 1;
    final bw = wide ? _pill : _button;
    final left = wide ? (width - _pill) / 2 : _centre(index) - _button / 2;
    return SizedBox(
      width: width,
      height: _button,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var k = 0; k < count; k++)
          AnimatedPositioned(
            duration: duration,
            curve: _spring,
            left: _centre(k) - 3,
            top: _button / 2 - 3,
            child: AnimatedOpacity(
              duration: duration,
              opacity: k == index || wide ? 0 : 1,
              child: AnimatedContainer(
                duration: duration,
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: k < index ? AppColors.signal300 : AppColors.signal100,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        AnimatedPositioned(
          duration: duration,
          curve: _spring,
          left: left,
          top: 0,
          width: bw,
          height: _button,
          child: Tooltip(
            message: wide ? label : tooltip,
            child: Material(
              color: AppColors.signal,
              shape: const StadiumBorder(),
              elevation: 0,
              shadowColor: Colors.transparent,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTap,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: duration,
                    child: wide
                        ? Text(
                            label,
                            key: ValueKey(label),
                            maxLines: 1,
                            style: AppTypography.label.copyWith(fontSize: 16, color: AppColors.onSignal),
                          )
                        : const Icon(
                            SolarIcons.altArrowRightLinear,
                            key: ValueKey('arrow'),
                            color: AppColors.onSignal,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
