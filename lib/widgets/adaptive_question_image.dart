import 'package:flutter/material.dart';

import '../services/service_locator.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/design_variant.dart';
import '../theme/solar_icons.dart';

/// The illustration attached to a question.
///
/// The frame is deliberately short. At the previous `maxHeight` of 265 a single
/// image took roughly 40% of the viewport, pushing the question below the fold
/// and leaving only two of four options reachable before the action bar — on a
/// timed exam, where scrolling to read the options costs seconds.
///
/// Shrinking it would normally trade legibility away, which is unacceptable for
/// a road sign whose details are the answer. So the image is also **tappable**:
/// it opens full-screen with pinch-to-zoom and pan. The frame gets smaller; the
/// detail stays reachable.
///
/// [BoxFit.contain] on a neutral surface, so a tall sign letterboxes into the
/// frame rather than being cropped — cropping a sign can remove the very
/// element the question asks about.
class AdaptiveQuestionImage extends StatelessWidget {
  final String imagePath;
  final String? assetFallback;
  final double maxHeight;
  final double minHeight;
  final String storageFolder;

  const AdaptiveQuestionImage({
    Key? key,
    required this.imagePath,
    this.assetFallback,
    this.maxHeight = 180.0,
    this.minHeight = 120.0,
    this.storageFolder = 'quiz_images', // Default for backward compatibility
  }) : super(key: key);

  Widget _image({required BoxFit fit}) {
    return serviceLocator.storage.getImage(
      storagePath: '$storageFolder/$imagePath',
      assetFallback: assetFallback,
      fit: fit,
      width: double.infinity,
      placeholderIcon: SolarIcons.galleryRemoveLinear,
      placeholderColor: AppColors.field,
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: AppMotion.duration(context, AppMotion.base),
        pageBuilder: (_, __, ___) => _FullScreenImage(child: _image(fit: BoxFit.contain)),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The frame follows the design variant's radius scale; size, fit and the
    // tap-to-zoom behaviour are the same in every variant.
    final variant = designVariant.value;
    final tokens = VariantTokens.of(variant);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Semantics(
        image: true,
        button: true,
        child: GestureDetector(
          onTap: () => _openFullScreen(context),
          child: Container(
            constraints: BoxConstraints(
              minHeight: minHeight,
              maxHeight: maxHeight,
            ),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(tokens.card),
              border: Border.all(
                color: variant == DesignVariant.boldB
                    ? AppColors.borderStrong
                    : variant == DesignVariant.bento
                        ? AppColors.paper
                        : AppColors.border,
              ),
              boxShadow: variant == DesignVariant.boldA ||
                      variant == DesignVariant.bento
                  ? AppColors.shadowResting
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                _image(fit: BoxFit.contain),
                // Affordance only — the whole frame is the tap target, so this
                // is hidden from screen readers to avoid announcing a control
                // that is not separately focusable.
                Positioned(
                  right: AppSpacing.x2,
                  bottom: AppSpacing.x2,
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.paper.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(tokens.chip),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: AppIcons.icon(
                        AppIcons.zoom,
                        size: 16,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The enlarged view: pinch, pan, tap anywhere to dismiss.
class _FullScreenImage extends StatelessWidget {
  const _FullScreenImage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox.expand(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: child),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.x2,
            right: AppSpacing.x4,
            child: IconButton(
              // Flutter ships this string in every locale the app supports, so
              // the close control needs no new translation key.
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
              icon: Container(
                padding: const EdgeInsets.all(AppSpacing.x2),
                decoration: const BoxDecoration(
                  color: AppColors.paper,
                  shape: BoxShape.circle,
                ),
                child: AppIcons.icon(
                  AppIcons.close,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
