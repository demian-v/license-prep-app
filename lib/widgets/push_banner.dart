import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../theme/bento_tokens.dart';

/// A push that arrives while the app is open (instructors plan v2 §12, P5).
/// iOS and Android don't show a system banner in the foreground, and the
/// owner chose an in-app one over flutter_local_notifications (2026-10-05):
/// a white Bento card that slides down under the status bar, title first,
/// then the text. Tap opens the push's route; swipe up or wait 4 s dismisses.
class PushBanner {
  static OverlayEntry? _entry;

  static void show(OverlayState overlay, {required String title, required String body, VoidCallback? onTap}) {
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => PushBannerCard(
        title: title,
        body: body,
        onTap: onTap,
        onDismissed: () {
          if (_entry == entry) hide();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class PushBannerCard extends StatefulWidget {
  const PushBannerCard({
    super.key,
    required this.title,
    required this.body,
    required this.onDismissed,
    this.onTap,
    this.visibleFor = const Duration(seconds: 4),
  });

  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback onDismissed;
  final Duration visibleFor;

  @override
  State<PushBannerCard> createState() => _PushBannerCardState();
}

class _PushBannerCardState extends State<PushBannerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _slide =
      AnimationController(vsync: this, duration: AppMotion.base, reverseDuration: AppMotion.fast);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _slide.forward();
    _timer = Timer(widget.visibleFor, _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _slide.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = Tween(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slide, curve: AppMotion.enter, reverseCurve: AppMotion.exit));
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: SlideTransition(
          position: position,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: GestureDetector(
              onTap: () {
                widget.onTap?.call();
                _dismiss();
              },
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) _dismiss();
              },
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(BentoTokens.card),
                    boxShadow: AppColors.shadowCard,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              fontSize: 15,
                              color: AppColors.ink,
                              fontVariations: const [FontVariation('wght', 600)],
                            ),
                          ),
                          if (widget.body.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(color: AppColors.inkSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
