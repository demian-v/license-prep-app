import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/instructor_listing.dart';
import '../providers/language_provider.dart';
import '../services/analytics_service.dart';
import '../services/instructor_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_empty_card.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart' show bentoHeadingAppBar;
import '../widgets/instructor_card.dart';
import '../widgets/instructor_stage_badge.dart';
import '../widgets/report_sheet.dart';

/// One instructor, for a paid student (instructors plan v2 §13). Pushed from
/// Поиск / Избранное with the card's data, so it draws at once; the weekly
/// hours (getInstructorProfile) and reviews (getInstructorReviews) follow.
///
/// Booking (P7) and messages (P6) don't exist yet: their buttons are shown
/// disabled with the reason, so the page already says what each needs.
class InstructorDetailScreen extends StatefulWidget {
  const InstructorDetailScreen({super.key, required this.instructor, required this.uid, this.service});

  final InstructorListing instructor;

  /// The student, for favourites.
  final String uid;
  final InstructorService? service;

  @override
  State<InstructorDetailScreen> createState() => _InstructorDetailScreenState();
}

/// Reviews shown on the page before «Все отзывы» (plan v2 §13).
const int _reviewsOnPage = 3;

class _InstructorDetailScreenState extends State<InstructorDetailScreen> {
  late final InstructorService _service = widget.service ?? InstructorService();
  late final Future<InstructorListing> _profile = _service.detail(widget.instructor.id);
  late final Future<List<InstructorReview>> _reviews = _service.reviews(widget.instructor.id);
  late final Stream<Set<String>> _favorites = _service.favorites(widget.uid);

  @override
  void initState() {
    super.initState();
    analyticsService.logInstructorProfileViewed(kind: widget.instructor.kind, stage: widget.instructor.stage);
  }

  void _report(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReportSheet(
        contentType: 'instructor',
        contextData: {
          'instructorUid': widget.instructor.id,
          'language': Provider.of<LanguageProvider>(context, listen: false).language,
          'state': widget.instructor.state,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<Set<String>>(
      stream: _favorites,
      builder: (context, favorites) {
        final saved = favorites.data?.contains(widget.instructor.id) ?? false;
        return Scaffold(
          backgroundColor: AppColors.field,
          appBar: bentoHeadingAppBar(
            title: l.translate(widget.instructor.isSchool ? 'kind_school_title' : 'kind_school_instructor_title'),
            onBack: () => Navigator.of(context).pop(),
            actions: bentoQuestionActions(
              context,
              reportTooltip: l.translate('report_instructor_title'),
              onReport: () => _report(context),
              isSaved: saved,
              onToggleSaved: () => _service.setFavorite(widget.uid, widget.instructor.id, !saved),
            ),
          ),
          body: FutureBuilder<InstructorListing>(
            future: _profile,
            builder: (context, snapshot) {
              final error = snapshot.error;
              if (error is FirebaseFunctionsException && error.code == 'not-found') {
                return ListView(
                  padding: _pagePadding,
                  children: [
                    BentoEmptyCard(
                      icon: SolarIcons.userRoundedLinear,
                      title: l.translate('instructor_unavailable_title'),
                      description: l.translate('instructor_unavailable_desc'),
                    ),
                  ],
                );
              }
              // The card's data until the full profile arrives (or if it
              // fails for another reason — only the hours are missing then).
              final i = snapshot.data ?? widget.instructor;
              return ListView(
                padding: _pagePadding,
                children: [
                  _Hero(instructor: i),
                  if (i.stage < 2) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Notice(stage: i.stage),
                  ],
                  const SizedBox(height: AppSpacing.x3),
                  _Actions(instructor: i),
                  if (i.bio != null) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Section(
                      title: l.translate('iprof_bio'),
                      children: [Text(i.bio!, style: AppTypography.body.copyWith(color: AppColors.ink))],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x3),
                  _Section(title: l.translate('instructor_lessons'), children: [_LessonTiles(instructor: i)]),
                  if (i.schoolName != null) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Section(title: l.translate('ireg_school_title'), children: [_School(instructor: i)]),
                  ],
                  if (snapshot.hasData) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Section(title: l.translate('instructor_hours'), children: [_WeekHours(instructor: i)]),
                  ],
                  const SizedBox(height: AppSpacing.x3),
                  _Reviews(instructor: i, reviews: _reviews),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(
  AppSpacing.x4 + AppSpacing.x1,
  AppSpacing.x2,
  AppSpacing.x4 + AppSpacing.x1,
  AppSpacing.x6,
);

BoxDecoration get _card => BoxDecoration(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(BentoTokens.card),
      boxShadow: AppColors.shadowCard,
    );

/// Photo, name, place, price, rating and what was checked.
class _Hero extends StatelessWidget {
  const _Hero({required this.instructor});

  final InstructorListing instructor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = instructor;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InstructorAvatar(photoPath: i.photoPath, size: 88),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.name,
                      style: AppTypography.title.copyWith(
                        fontSize: 22,
                        height: 28 / 22,
                        color: AppColors.ink,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${i.city}, ${i.state}', style: AppTypography.label.copyWith(color: AppColors.inkSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            instructorPrice(l, i),
            style: AppTypography.title.copyWith(
              fontSize: i.priceHidden ? 17 : 22,
              color: i.priceHidden ? AppColors.inkSecondary : AppColors.ink,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              InstructorFactPill(
                star: !i.isNew,
                text: instructorRating(l, i),
              ),
              InstructorStageBadge(stage: i.stage),
            ],
          ),
        ],
      ),
    );
  }
}

/// The big amber notice for a profile whose checks aren't done (plan v2
/// §6.4): amber title at a size where it passes contrast, never red.
class _Notice extends StatelessWidget {
  const _Notice({required this.stage});

  final int stage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (title, desc) = stage == 0
        ? ('instructor_notice_unverified_title', 'instructor_notice_unverified_desc')
        : ('instructor_notice_id_checked_title', 'instructor_notice_id_checked_desc');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.warnSurface,
        borderRadius: BorderRadius.circular(BentoTokens.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(SolarIcons.dangerCircleLinear, size: 24, color: AppColors.warn),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  l.translate(title),
                  style: AppTypography.title.copyWith(
                    fontSize: 20,
                    height: 26 / 20,
                    color: AppColors.warn,
                    fontVariations: const [FontVariation('wght', 700)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(l.translate(desc), style: AppTypography.body.copyWith(color: AppColors.ink)),
        ],
      ),
    );
  }
}

/// «Забронировать» (driving schools only) and «Написать», disabled until
/// P7 / P6, each with the reason under it.
class _Actions extends StatelessWidget {
  const _Actions({required this.instructor});

  final InstructorListing instructor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = instructor;
    final reasons = [
      if (i.isSchool) l.translate(i.stage >= 2 ? 'instructor_book_soon' : 'instructor_book_after_check'),
      l.translate(i.stage >= 1 ? 'instructor_chat_soon' : 'instructor_chat_after_id'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (i.isSchool) ...[
              Expanded(child: BentoActionButton(text: l.translate('instructor_book'), onTap: null)),
              const SizedBox(width: AppSpacing.x3),
            ],
            Expanded(child: BentoActionButton(text: l.translate('instructor_message'), ink: true, onTap: null)),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        for (final reason in reasons)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
            ),
          ),
      ],
    );
  }
}

/// A white card with a title and its rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.body.copyWith(
              fontSize: 17,
              color: AppColors.ink,
              fontVariations: const [FontVariation('wght', 600)],
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          ...children,
        ],
      ),
    );
  }
}

/// One fact as a soft tile: an icon disc, a small label, the value in bold.
class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, this.wide = false});

  final IconData icon;
  final String label;
  final String value;

  /// A whole-row tile: the icon beside the text instead of above it.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final disc = Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(color: AppColors.paper, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: AppColors.signal),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.label.copyWith(
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
      ],
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: wide
          ? Row(children: [disc, const SizedBox(width: AppSpacing.x3), Expanded(child: text)])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [disc, const SizedBox(height: AppSpacing.x2), text],
            ),
    );
  }
}

/// [tiles] two to a row, each pair as tall as its taller tile; a lone last
/// tile takes the whole row.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.x2;
    return Column(
      children: [
        for (var n = 0; n < tiles.length; n += 2) ...[
          if (n > 0) const SizedBox(height: gap),
          if (n + 1 < tiles.length)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: tiles[n]),
                  const SizedBox(width: gap),
                  Expanded(child: tiles[n + 1]),
                ],
              ),
            )
          else
            tiles[n],
        ],
      ],
    );
  }
}

/// Уроки: languages, lesson lengths, car, dual pedals.
class _LessonTiles extends StatelessWidget {
  const _LessonTiles({required this.instructor});

  final InstructorListing instructor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = instructor;
    return _TileGrid(tiles: [
      _Tile(
        icon: SolarIcons.globalLinear,
        label: l.translate('instructor_languages'),
        value: i.languages.map(teachingLanguageName).join(', '),
      ),
      if (i.lessonDurations.isNotEmpty)
        _Tile(
          icon: SolarIcons.clockCircleLinear,
          label: l.translate('ireg_durations'),
          value: l.translate('ireg_minutes').replaceAll('{n}', i.lessonDurations.join(' · ')),
        ),
      if (i.carModel != null)
        _Tile(
          icon: SolarIcons.carLinear,
          label: l.translate('ireg_car_title'),
          value: [i.carModel!, if (i.carYear != null) '${i.carYear}'].join(', '),
        ),
      if (i.hasDualControls)
        _Tile(
          icon: SolarIcons.checkCircleBold,
          label: l.translate('ireg_dual_controls'),
          value: l.translate('instructor_dual_yes'),
        ),
    ]);
  }
}

/// Автошкола: the school with its address, then its licence number (public
/// on purpose — a student can check it with the state, plan v2 §5) and size.
class _School extends StatelessWidget {
  const _School({required this.instructor});

  final InstructorListing instructor;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = instructor;
    final tiles = [
      if (i.schoolLicenseNumber != null)
        _Tile(
          icon: SolarIcons.documentTextLinear,
          label: l.translate('ireg_school_license'),
          value: i.schoolLicenseNumber!,
          wide: true,
        ),
      if (i.fleetSize != null)
        _Tile(icon: SolarIcons.carLinear, label: l.translate('ireg_fleet_size'), value: '${i.fleetSize}'),
      if (i.instructorCount != null)
        _Tile(
          icon: SolarIcons.userRoundedLinear,
          label: l.translate('ireg_instructor_count'),
          value: '${i.instructorCount}',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: AppColors.signal50, shape: BoxShape.circle),
              child: const Icon(SolarIcons.squareAcademicCapBold, size: 22, color: AppColors.signal),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.schoolName!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.ink,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                  if (i.schoolAddress != null)
                    Text(i.schoolAddress!, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                ],
              ),
            ),
          ],
        ),
        if (tiles.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x3),
          // The licence on its own row, the two numbers side by side.
          if (i.schoolLicenseNumber != null) ...[
            tiles.first,
            if (tiles.length > 1) const SizedBox(height: AppSpacing.x2),
            if (tiles.length > 1) _TileGrid(tiles: tiles.sublist(1)),
          ] else
            _TileGrid(tiles: tiles),
        ],
      ],
    );
  }
}

/// The weekly hours as a list a student reads at a glance (owner,
/// 2026-10-05: the timeline was hard to read): each day by its full name,
/// each open range as a chip, days off in grey, and today's row tinted
/// (the phone's day — the student is in the instructor's state).
class _WeekHours extends StatelessWidget {
  const _WeekHours({required this.instructor});

  final InstructorListing instructor;

  /// Weekday id, full-name key, `DateTime.weekday`.
  static const List<(String, String, int)> _week = [
    ('mon', 'day_full_mon', DateTime.monday),
    ('tue', 'day_full_tue', DateTime.tuesday),
    ('wed', 'day_full_wed', DateTime.wednesday),
    ('thu', 'day_full_thu', DateTime.thursday),
    ('fri', 'day_full_fri', DateTime.friday),
    ('sat', 'day_full_sat', DateTime.saturday),
    ('sun', 'day_full_sun', DateTime.sunday),
  ];

  /// The zones zip-timezone.ts can assign, by name instead of IANA id.
  static const Map<String, String> _zoneKeys = {
    'America/New_York': 'instructor_tz_eastern',
    'America/Detroit': 'instructor_tz_eastern',
    'America/Chicago': 'instructor_tz_central',
    'America/Denver': 'instructor_tz_mountain',
    'America/Boise': 'instructor_tz_mountain',
    'America/Phoenix': 'instructor_tz_mountain',
    'America/Los_Angeles': 'instructor_tz_pacific',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = instructor;
    if (i.availability.values.every((day) => day.isEmpty)) {
      return Text(l.translate('instructor_hours_none'),
          style: AppTypography.body.copyWith(color: AppColors.inkSecondary));
    }
    final today = DateTime.now().weekday;
    final zoneKey = _zoneKeys[i.timezone];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (day, nameKey, weekday) in _week)
          _row(l, l.translate(nameKey), i.availability[day] ?? const [], weekday == today),
        if (i.timezone != null) ...[
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              const Icon(SolarIcons.clockCircleLinear, size: 16, color: AppColors.inkSecondary),
              const SizedBox(width: AppSpacing.x1 + 2),
              Expanded(
                child: Text(
                  zoneKey == null ? i.timezone! : '${l.translate(zoneKey)} · ${i.city}',
                  style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// One day: the name on the left, the ranges as a right-aligned column
  /// so the times line up down the card. Every row is the same height; a
  /// day with two ranges stacks them. Only today is blue (its tinted row,
  /// white chips; no «сегодня» pill — owner, 2026-10-05: it could break a
  /// small screen) — the other chips are quiet `field`
  /// pills, so blue keeps meaning one thing on a page that also has a blue
  /// button.
  Widget _row(AppLocalizations l, String name, List<(String, String)> hours, bool isToday) {
    final open = hours.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1 + 2),
      decoration: BoxDecoration(
        color: isToday ? AppColors.signal50 : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: open ? AppColors.ink : AppColors.inkTertiary,
                fontVariations: [FontVariation('wght', open ? 600 : 500)],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          if (!open)
            Text(
              l.translate('instructor_day_off'),
              style: AppTypography.label.copyWith(color: AppColors.inkTertiary),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var n = 0; n < hours.length; n++) ...[
                  if (n > 0) const SizedBox(height: AppSpacing.x1),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 5),
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.paper : AppColors.field,
                      borderRadius: BorderRadius.circular(BentoTokens.chip),
                    ),
                    child: Text(
                      '${hours[n].$1}–${hours[n].$2}',
                      style: AppTypography.label.copyWith(
                        color: isToday ? AppColors.signal : AppColors.ink,
                        fontVariations: const [FontVariation('wght', 600)],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// The rating, the first reviews, and «Все отзывы» for the rest.
class _Reviews extends StatelessWidget {
  const _Reviews({required this.instructor, required this.reviews});

  final InstructorListing instructor;
  final Future<List<InstructorReview>> reviews;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<InstructorReview>>(
      future: reviews,
      builder: (context, snapshot) {
        final list = snapshot.data;
        return _Section(
          title: l.translate('instructor_reviews'),
          children: [
            if (snapshot.hasError)
              Text(l.translate('instructors_load_error_desc'),
                  style: AppTypography.body.copyWith(color: AppColors.inkSecondary))
            else if (list == null)
              const Center(child: CircularProgressIndicator())
            else if (list.isEmpty)
              Text(l.translate('instructor_reviews_none'),
                  style: AppTypography.body.copyWith(color: AppColors.inkSecondary))
            else ...[
              Text(
                [
                  instructorRating(l, instructor),
                  l.translate('instructor_reviews_count').replaceAll('{n}', '${instructor.ratingCount}'),
                ].join(' · '),
                style: AppTypography.label.copyWith(color: AppColors.inkSecondary),
              ),
              for (final r in list.take(_reviewsOnPage)) _ReviewTile(review: r),
              if (list.length > _reviewsOnPage) ...[
                const SizedBox(height: AppSpacing.x3),
                BentoActionButton(
                  text: l.translate('instructor_reviews_all'),
                  primary: false,
                  onCard: true,
                  onTap: () => _showAll(context, list),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  void _showAll(BuildContext context, List<InstructorReview> list) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
        ),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4),
            children: [
              Text(
                l.translate('instructor_reviews'),
                style: AppTypography.title.copyWith(
                  fontSize: 22,
                  height: 28 / 22,
                  color: AppColors.ink,
                  fontVariations: const [FontVariation('wght', 600)],
                ),
              ),
              for (final r in list) _ReviewTile(review: r),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final InstructorReview review;

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.name,
                  style: AppTypography.label.copyWith(
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 600)],
                  ),
                ),
              ),
              InstructorFactPill(star: true, text: '${review.rating}/5'),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(review.comment, style: AppTypography.body.copyWith(color: AppColors.ink)),
          ],
          if (date != null) ...[
            const SizedBox(height: 2),
            Text(
              '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
              style: AppTypography.caption.copyWith(color: AppColors.inkTertiary),
            ),
          ],
        ],
      ),
    );
  }
}
