import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/teaching_languages.dart';
import '../localization/app_localizations.dart';
import '../models/instructor_listing.dart';
import '../services/instructor_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'instructor_stage_badge.dart';

/// An instructor's approved photo, round, or the placeholder avatar when
/// there is none yet (plan v2 §5: nobody is hidden for a pending photo).
class InstructorAvatar extends StatelessWidget {
  const InstructorAvatar({super.key, required this.photoPath, this.size = 64});

  final String? photoPath;
  final double size;

  /// One download-URL lookup per photo for the app session: the list
  /// rebuilds often, and a new `photoPath` (a new upload) is a new key.
  static final Map<String, Future<String>> _urls = {};

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration:
          const BoxDecoration(color: AppColors.field, shape: BoxShape.circle),
      child: Icon(SolarIcons.userRoundedBold,
          size: size * 0.45, color: AppColors.inkTertiary),
    );
    final path = photoPath;
    if (path == null) return placeholder;
    final url = _urls.putIfAbsent(
        path, () => InstructorService().photoUrl(path)..ignore());
    return FutureBuilder<String>(
      future: url,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return placeholder;
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: snapshot.data!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => placeholder,
          ),
        );
      },
    );
  }
}

/// A small grey fact pill: rating, price, languages (plan v2 §13).
class InstructorFactPill extends StatelessWidget {
  const InstructorFactPill({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(BentoTokens.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpacing.x1),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink,
                fontVariations: const [FontVariation('wght', 600)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A language code in its own name (owner rule 11), e.g. `pl` → Polski.
String teachingLanguageName(String code) => teachingLanguages
    .firstWhere((l) => l.$1 == code, orElse: () => (code, code))
    .$2;

/// «$65/ч», or the hidden-price text for a private instructor whose licence
/// hasn't been checked (owner, 2026-09-30) — [short] for the card's pill,
/// where the full sentence would be cut off.
String instructorPrice(AppLocalizations l, InstructorListing i,
    {bool short = false}) {
  final cents = i.hourlyRateCents;
  if (i.priceHidden || cents == null) {
    return l.translate(
        short ? 'instructor_price_hidden_short' : 'instructor_price_hidden');
  }
  final dollars =
      cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2);
  return l
      .translate('instructor_price_hour')
      .replaceAll('{price}', '\$$dollars');
}

/// «4.7», or «Новый» under 3 reviews (plan v2 §11).
String instructorRating(AppLocalizations l, InstructorListing i) =>
    i.isNew ? l.translate('instructor_new') : i.ratingAvg.toStringAsFixed(1);

/// One instructor in Поиск / Избранное (plan v2 §13): a white Bento card,
/// the whole card is the target, no chevron; the heart saves it.
class InstructorCard extends StatelessWidget {
  const InstructorCard({
    super.key,
    required this.instructor,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });

  final InstructorListing instructor;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = instructor;
    final shownLanguages =
        i.languages.take(2).map(teachingLanguageName).toList();
    final more = i.languages.length - shownLanguages.length;
    final radius = BorderRadius.circular(BentoTokens.card);

    return PressScale(
      scale: 0.98,
      duration: BentoTokens.state,
      // The white card and its shadow outside any clip; the ripple on a
      // transparent Material above the fill.
      child: DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: radius,
            boxShadow: AppColors.shadowCard),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4, AppSpacing.x4, AppSpacing.x1, AppSpacing.x4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InstructorAvatar(photoPath: i.photoPath),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            fontSize: 17,
                            height: 22 / 17,
                            color: AppColors.ink,
                            fontVariations: const [FontVariation('wght', 600)],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${i.city}, ${i.state}',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.inkSecondary),
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        Wrap(
                          spacing: AppSpacing.x1 + 2,
                          runSpacing: AppSpacing.x1 + 2,
                          children: [
                            InstructorFactPill(
                              icon: i.isNew
                                  ? null
                                  : SolarIcons.medalRibbonsStarBold,
                              text: instructorRating(l, i),
                            ),
                            InstructorFactPill(
                                text: instructorPrice(l, i, short: true)),
                            if (shownLanguages.isNotEmpty)
                              InstructorFactPill(
                                text: [
                                  ...shownLanguages,
                                  if (more > 0) '+$more'
                                ].join(' · '),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x2),
                        InstructorStageBadge(stage: i.stage),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.translate(
                        saved ? 'instructor_unsave' : 'instructor_save'),
                    onPressed: onToggleSaved,
                    icon: AnimatedSwitcher(
                      duration: AppMotion.duration(context, BentoTokens.state),
                      switchInCurve: AppMotion.enter,
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: Tween<double>(begin: 0.7, end: 1)
                            .animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(saved),
                        child: AppIcons.icon(
                          saved ? AppIcons.savedFilled : AppIcons.saved,
                          size: 22,
                          color:
                              saved ? AppColors.stop : AppColors.inkSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
