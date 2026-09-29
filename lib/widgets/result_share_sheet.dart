import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'bento_question_parts.dart';
import 'bento_result_parts.dart';
import 'result_meme_picture.dart';

const _appStoreUrl =
    'https://apps.apple.com/us/app/drive-usa-theory-and-practice/id6756199100';
const _playUrl = 'https://play.google.com/store/apps/details?id=com.driveusa.app';

/// What a result page hands its share sheet: the verdict card's content and
/// the facts for the `result_shared` event.
class ResultShareData {
  const ResultShareData({
    required this.module,
    required this.memeUrl,
    required this.fallbackAsset,
    required this.verdict,
    required this.titleColor,
    required this.tone,
    required this.toneSurface,
    required this.percent,
    required this.bucket,
    required this.passed,
    this.timeUpLabel,
  });

  /// exam, practice or topic.
  final String module;
  final Future<String?> memeUrl;
  final String fallbackAsset;
  final String verdict;
  final Color titleColor;
  final Color tone;
  final Color toneSurface;
  final int percent;
  final String bucket;
  final bool passed;
  final String? timeUpLabel;
}

/// Opens the result share sheet — the motion.dev sheet-modal reference,
/// measured 2026-09-28, rebuilt with built-ins: a floating card that springs
/// up (no bounce) over a dim that follows it, drags at 0.8×, and goes away
/// past 80 pt of travel or on a fast flick (owner additions: the flick and a
/// one-shot content stagger). A route of its own rather than
/// `showModalBottomSheet`, so no app-wide sheet theme changes the frozen
/// Экзамен sheet.
Future<void> showResultShareSheet(BuildContext context, ResultShareData data) {
  return Navigator.of(context).push(_ShareSheetRoute(data));
}

class _ShareSheetRoute extends PopupRoute<void> {
  _ShareSheetRoute(this.data);

  final ResultShareData data;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  // The sheet runs its own spring; the route itself appears at once.
  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      _ShareSheet(data: data);
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.data});

  final ResultShareData data;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet>
    with SingleTickerProviderStateMixin {
  /// The sheet's offset as a fraction of its own height: 0 open, 1 gone.
  late final AnimationController _offset =
      AnimationController.unbounded(vsync: this, value: 1);
  final GlobalKey _sheetKey = GlobalKey();
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _sendKey = GlobalKey();

  /// The offset the exit started from; opacity fades from there to 0.
  double? _closingFrom;

  static const double _dragFactor = 0.8;
  static const double _dismissOffset = 80;
  static const double _dismissVelocity = 1000;
  static const double _dim = 0.5;

  /// iPhones with a home indicator draw their screen corners at roughly
  /// 47–62pt; Flutter cannot read the exact value, so one that sits well on
  /// all of them.
  static const double _screenCornerRadius = 52;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduced(context)) {
        _offset.value = 0;
      } else {
        _offset.animateWith(SpringSimulation(AppMotion.sheetSpring, 1, 0, 0));
      }
    });
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  double get _sheetHeight =>
      _sheetKey.currentContext?.size?.height ?? MediaQuery.sizeOf(context).height;

  void _onDragStart(DragStartDetails _) {
    if (_closingFrom != null) return;
    _offset.stop();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_closingFrom != null) return;
    final next = _offset.value + d.delta.dy * _dragFactor / _sheetHeight;
    _offset.value = next < 0 ? 0 : next;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_closingFrom != null) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_offset.value * _sheetHeight >= _dismissOffset ||
        velocity >= _dismissVelocity) {
      _dismiss();
    } else {
      _offset.animateWith(SpringSimulation(AppMotion.sheetSpring, _offset.value,
          0, velocity * _dragFactor / _sheetHeight));
    }
  }

  Future<void> _dismiss() async {
    if (_closingFrom != null) return;
    setState(() => _closingFrom = _offset.value);
    final duration = AppMotion.duration(context, AppMotion.base);
    if (duration > Duration.zero) {
      await _offset.animateTo(1.05, duration: duration, curve: AppMotion.exit);
    }
    if (mounted) Navigator.of(context).pop();
  }

  String _shareText(AppLocalizations t) =>
      '${t.translate('share_result_text').replaceAll('{percent}', '${widget.data.percent}%')}'
      '\n\nApp Store: $_appStoreUrl\nGoogle Play: $_playUrl';

  Future<Uint8List?> _captureCard() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return png?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  void _logShared(String method, String status) {
    final d = widget.data;
    analyticsService.logResultShared(
      module: d.module,
      method: method,
      bucket: d.bucket,
      scorePercent: d.percent,
      passed: d.passed,
      status: status,
    );
  }

  Future<void> _onSend() async {
    final t = AppLocalizations.of(context);
    final text = _shareText(t);
    final box = _sendKey.currentContext?.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    final png = await _captureCard();
    final result = await SharePlus.instance.share(ShareParams(
      text: text,
      files: png == null ? null : [XFile.fromData(png, mimeType: 'image/png')],
      fileNameOverrides: png == null ? null : ['driveusa-result.png'],
      sharePositionOrigin: origin,
    ));
    _logShared('system_share', result.status.name);
    if (result.status == ShareResultStatus.success) _dismiss();
  }

  Future<void> _onCopyLink() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: _shareText(t)));
    _logShared('copy_link', 'success');
    messenger?.showSnackBar(SnackBar(
      content: Text(t.translate('share_link_copied')),
      backgroundColor: AppColors.guide,
    ));
    _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // On a phone with rounded screen corners (it has a home indicator) the
    // sheet's bottom corners follow the screen's curve, 8pt inside it, instead
    // of the card's tighter 24 — two curves side by side read as a mistake.
    final hasScreenCorners = bottomInset > 0;
    final radius = BorderRadius.vertical(
      top: const Radius.circular(BentoTokens.card),
      bottom: Radius.circular(
          hasScreenCorners ? _screenCornerRadius - AppSpacing.x2 : BentoTokens.card),
    );
    final blocks = <Widget>[
      _header(t),
      RepaintBoundary(key: _cardKey, child: _ShareCard(data: widget.data)),
      // «Скопировать ссылку» is the longer label in every language, so it
      // gets the wider pill; pill text never truncates (owner rule 5).
      Row(
        children: [
          Expanded(
            flex: 3,
            child: BentoActionButton(
              text: t.translate('share_copy_link'),
              onTap: _onCopyLink,
              primary: false,
              onCard: true,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            flex: 2,
            child: KeyedSubtree(
              key: _sendKey,
              child: BentoInkButton(
                text: t.translate('share_send'),
                onTap: _onSend,
              ),
            ),
          ),
        ],
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dismiss();
      },
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) {
          final v = _offset.value;
          final shown = (1 - v).clamp(0.0, 1.0);
          final from = _closingFrom;
          final opacity =
              from == null ? 1.0 : ((1 - v) / (1 - from)).clamp(0.0, 1.0);
          return Stack(
            children: [
              // The dim follows the sheet: half-black when open, lighter as
              // it is dragged down. Tapping it closes the sheet.
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: t.translate('close'),
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: ColoredBox(
                      color: AppColors.ink.withValues(alpha: _dim * shown),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Opacity(
                  opacity: opacity,
                  child: FractionalTranslation(
                    translation: Offset(0, v),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x2, 0, AppSpacing.x2, AppSpacing.x2),
          child: GestureDetector(
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Material(
              key: _sheetKey,
              color: AppColors.paper,
              elevation: 0,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  // Clear of the home indicator and the deep corners (rule 6).
                  hasScreenCorners ? bottomInset : AppSpacing.x6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The handle says the sheet can be dragged.
                    Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: AppSpacing.x2),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(BentoTokens.chip),
                      ),
                    ),
                    for (var i = 0; i < blocks.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.x4),
                      StaggerIn(
                        index: i,
                        count: blocks.length,
                        curve: BentoTokens.curve,
                        child: blocks[i],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Title first with the round ✕ beside it — one row, no empty band.
  Widget _header(AppLocalizations t) {
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              t.translate('share_result_title'),
              maxLines: 1,
              style: AppTypography.title.copyWith(
                fontSize: 20,
                height: 26 / 20,
                letterSpacing: -0.3,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.x3),
        IconButton(
          tooltip: t.translate('close'),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.field,
            fixedSize: const Size(44, 44),
            shape: const CircleBorder(),
          ),
          icon: const Icon(SolarIcons.closeLinear, color: AppColors.ink, size: 20),
          onPressed: _dismiss,
        ),
      ],
    );
  }
}

/// The picture that is shared: the result's verdict card on the app's field
/// grey, signed with the DriveUSA logo.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.data});

  final ResultShareData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.x3, AppSpacing.x3, AppSpacing.x3, AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(BentoTokens.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BentoVerdictCard(
            picture: ResultMemePicture(
              url: data.memeUrl,
              fallbackAsset: data.fallbackAsset,
              toneSurface: data.toneSurface,
            ),
            title: data.verdict,
            titleColor: data.titleColor,
            score: '${data.percent}%',
            tone: data.tone,
            toneSurface: data.toneSurface,
            timeUpLabel: data.timeUpLabel,
          ),
          const SizedBox(height: AppSpacing.x3),
          Image.asset(
            'assets/images/logo/logo.png',
            height: 28,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}
