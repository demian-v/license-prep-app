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

/// Weekdays with their label keys, as literals (localization_coverage_test).
const List<(String, String)> _days = [
  ('mon', 'day_short_mon'),
  ('tue', 'day_short_tue'),
  ('wed', 'day_short_wed'),
  ('thu', 'day_short_thu'),
  ('fri', 'day_short_fri'),
  ('sat', 'day_short_sat'),
  ('sun', 'day_short_sun'),
];

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
                  _Section(title: l.translate('instructor_lessons'), children: _lessonFacts(l, i)),
                  if (i.schoolName != null) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Section(title: l.translate('ireg_school_title'), children: _schoolFacts(l, i)),
                  ],
                  if (snapshot.hasData) ...[
                    const SizedBox(height: AppSpacing.x3),
                    _Section(title: l.translate('instructor_hours'), children: _hours(l, i)),
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

  List<Widget> _lessonFacts(AppLocalizations l, InstructorListing i) => [
        _Fact(l.translate('instructor_languages'), i.languages.map(teachingLanguageName).join(', ')),
        if (i.lessonDurations.isNotEmpty)
          _Fact(l.translate('ireg_durations'),
              l.translate('ireg_minutes').replaceAll('{n}', i.lessonDurations.join(' · '))),
        if (i.carModel != null)
          _Fact(l.translate('ireg_car_title'), [i.carModel!, if (i.carYear != null) '${i.carYear}'].join(', ')),
        if (i.hasDualControls) _Fact(l.translate('ireg_dual_controls'), '✓'),
      ];

  List<Widget> _schoolFacts(AppLocalizations l, InstructorListing i) => [
        _Fact(l.translate('ireg_school_name'), i.schoolName!),
        // Public on purpose: a student can check it with the state (plan v2 §5).
        if (i.schoolLicenseNumber != null) _Fact(l.translate('ireg_school_license'), i.schoolLicenseNumber!),
        if (i.schoolAddress != null) _Fact(l.translate('ireg_school_address'), i.schoolAddress!),
        if (i.fleetSize != null) _Fact(l.translate('ireg_fleet_size'), '${i.fleetSize}'),
        if (i.instructorCount != null) _Fact(l.translate('ireg_instructor_count'), '${i.instructorCount}'),
      ];

  List<Widget> _hours(AppLocalizations l, InstructorListing i) {
    if (i.availability.values.every((day) => day.isEmpty)) {
      return [Text(l.translate('instructor_hours_none'), style: AppTypography.body.copyWith(color: AppColors.inkSecondary))];
    }
    return [
      for (final (day, label) in _days)
        _Fact(
          l.translate(label),
          (i.availability[day] ?? const []).map((h) => '${h.$1}–${h.$2}').join('\n').ifEmpty('—'),
        ),
      if (i.timezone != null) ...[
        const SizedBox(height: AppSpacing.x2),
        Text(
          l.translate('instructor_hours_tz').replaceAll('{tz}', i.timezone!),
          style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
        ),
      ],
    ];
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
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
                icon: i.isNew ? null : SolarIcons.medalRibbonsStarBold,
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

/// A label on the left, its value on the right.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: AppTypography.label.copyWith(color: AppColors.inkSecondary)),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.label.copyWith(
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
              InstructorFactPill(icon: SolarIcons.medalRibbonsStarBold, text: '${review.rating}/5'),
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
