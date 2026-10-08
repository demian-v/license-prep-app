import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/booking.dart';
import '../models/instructor_listing.dart';
import '../services/booking_service.dart';
import '../services/chat_service.dart';
import '../services/review_service.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import '../widgets/bento_empty_card.dart';
import '../widgets/bento_question_parts.dart';
import '../widgets/bento_result_parts.dart' show bentoHeadingAppBar;
import '../widgets/booking_tile.dart';
import '../widgets/destructive_dialog.dart';
import '../widgets/instructor_card.dart' show timezoneLabel;
import '../widgets/review_parts.dart';
import 'booking_screen.dart' show PriceLines;
import 'chat_thread_screen.dart';

/// One lesson, for either side (instructors plan v2 §9.3): who, when, how
/// long, where, the price, and — while it's ahead — «Написать» and
/// «Отменить урок». Live, so a cancel by the other side shows at once. Opened
/// from the lists, after booking, and from a `booking/<id>` push (the review
/// push lands here too). Once the lesson is held, the student rates the
/// school here (plan v2 §11, P8).
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId, required this.asInstructor, this.service, this.reviews});

  final String bookingId;
  final bool asInstructor;
  final BookingService? service;
  final ReviewService? reviews;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late final BookingService _service = widget.service ?? BookingService();
  late final ReviewService _reviews = widget.reviews ?? ReviewService();
  late final Stream<Booking?> _booking = _service.booking(widget.bookingId);
  bool _busy = false;

  Future<void> _cancel(Booking b) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final body = widget.asInstructor
        ? 'booking_cancel_instructor'
        : b.freeCancel(DateTime.now())
            ? 'booking_cancel_free'
            : 'booking_cancel_late';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => DestructiveDialog(
        title: l.translate('booking_cancel_title'),
        body: l.translate(body),
        confirm: l.translate('booking_cancel'),
        keep: l.translate('booking_keep'),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.cancel(b.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.translate('booking_cancel_error')), backgroundColor: AppColors.stop));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.field,
      appBar: bentoHeadingAppBar(title: l.translate('booking_detail_title'), onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        top: false,
        child: StreamBuilder<Booking?>(
          stream: _booking,
          builder: (context, snap) {
            if (snap.hasError || (snap.connectionState == ConnectionState.active && snap.data == null)) {
              return ListView(padding: _padding, children: [
                BentoEmptyCard(
                  icon: SolarIcons.clockCircleLinear,
                  title: l.translate('booking_not_found'),
                  description: l.translate('booking_not_found_desc'),
                ),
              ]);
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return _page(l, snap.data!);
          },
        ),
      ),
    );
  }

  Widget _page(AppLocalizations l, Booking b) {
    final asInstructor = widget.asInstructor;
    final otherDeleted = asInstructor ? b.studentDeleted : b.instructorDeleted;
    final name = otherDeleted
        ? l.translate('chat_deleted_user')
        : asInstructor
            ? (b.studentDisplayName.isEmpty ? l.translate('chat_student_fallback') : b.studentDisplayName)
            : b.instructorName;
    final now = DateTime.now();
    final ahead = b.status == 'confirmed' && b.startAt.isAfter(now);
    final note = switch (b.status) {
      'refunded' => b.cancelledBy == 'instructor' ? 'booking_note_by_school' : 'booking_note_by_student',
      'late_cancelled' => 'booking_note_late',
      _ => null,
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: _padding,
            children: [
              _Card(
                children: [
                  Text(
                    name,
                    style: AppTypography.title.copyWith(
                      fontSize: 22,
                      height: 28 / 22,
                      color: otherDeleted ? AppColors.inkSecondary : AppColors.ink,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(bookingWhen(context, b), style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: AppSpacing.x3),
                  Align(alignment: Alignment.centerLeft, child: BookingStatusPill(booking: b)),
                  if (note != null) ...[
                    const SizedBox(height: AppSpacing.x2),
                    Text(l.translate(note), style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                  ],
                ],
              ),
              if (!asInstructor && b.reviewable && !otherDeleted) ...[
                const SizedBox(height: AppSpacing.x3),
                _ReviewCard(booking: b, service: _reviews),
              ],
              const SizedBox(height: AppSpacing.x3),
              _Card(
                children: [
                  _Fact(
                    icon: SolarIcons.clockCircleLinear,
                    label: l.translate('booking_when'),
                    value: '${bookingWhen(context, b)} · ${l.translate('ireg_minutes').replaceAll('{n}', '${b.durationMinutes}')}',
                    note: b.timezone == null ? null : timezoneLabel(l, b.timezone!),
                  ),
                  if (b.schoolAddress != null) ...[
                    const SizedBox(height: AppSpacing.x2),
                    _Fact(icon: SolarIcons.mapPointBold, label: l.translate('booking_where'), value: b.schoolAddress!),
                  ],
                ],
              ),
              // A refunded lesson pays the school nothing, so its part is
              // not shown; the student still sees what the lesson cost.
              if (!asInstructor || !const {'refunded', 'expired'}.contains(b.status)) ...[
              const SizedBox(height: AppSpacing.x3),
              _Card(
                children: [
                  Text(
                    l.translate(asInstructor ? 'booking_you_receive' : 'booking_price'),
                    style: AppTypography.body.copyWith(
                      fontSize: 17,
                      color: AppColors.ink,
                      fontVariations: const [FontVariation('wght', 600)],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  // The school gets its full price; the fee is the student's
                  // (plan v2 §9.1), so the school sees only its part.
                  if (asInstructor)
                    Text(
                      formatUsd(b.lessonCents),
                      style: AppTypography.title.copyWith(
                        fontSize: 22,
                        height: 28 / 22,
                        color: AppColors.ink,
                        fontVariations: const [FontVariation('wght', 700)],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )
                  else
                    PriceLines(
                      quote: BookingQuote(
                        durationMinutes: b.durationMinutes,
                        lessonCents: b.lessonCents,
                        platformFeeCents: b.platformFeeCents,
                        totalCents: b.totalCents,
                        feeKind: b.feeKind,
                      ),
                    ),
                ],
              ),
              ],
              if (ahead && !asInstructor) ...[
                const SizedBox(height: AppSpacing.x3),
                Text(
                  l.translate('booking_cancel_rule'),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: AppColors.inkSecondary),
                ),
              ],
            ],
          ),
        ),
        if (!otherDeleted)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4 + AppSpacing.x1, AppSpacing.x2, AppSpacing.x4 + AppSpacing.x1, AppSpacing.x3),
            child: _busy
                ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                // Two actions: white + black (owner rule 16).
                : Row(
                    children: [
                      if (ahead) ...[
                        Expanded(
                          child: BentoActionButton(
                            text: l.translate('booking_cancel'),
                            primary: false,
                            onTap: () => _cancel(b),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                      ],
                      Expanded(
                        child: BentoActionButton(
                          text: l.translate('instructor_message'),
                          ink: true,
                          onTap: () => Navigator.of(context).push(ForwardPageRoute(
                            child: ChatThreadScreen(
                              conversationId: ChatService.conversationIdFor(b.studentUid, b.instructorUid),
                            ),
                          )),
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

const EdgeInsets _padding = EdgeInsets.fromLTRB(
  AppSpacing.x4 + AppSpacing.x1,
  AppSpacing.x2,
  AppSpacing.x4 + AppSpacing.x1,
  AppSpacing.x4,
);

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x4 + AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

/// A wide fact tile, as on the instructor page: icon disc, label, value.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.note});

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3),
      decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: AppColors.paper, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: AppColors.signal),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.label.copyWith(color: AppColors.ink, fontVariations: const [FontVariation('wght', 600)]),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(note!, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The student's review of the school (plan v2 §11): before one exists,
/// «Оцените урок» with five stars — the tapped star opens the sheet with it
/// chosen; after, «Ваш отзыв» with the stars, the comment and «Изменить». One
/// review per school, so every held lesson with it shows the same one. Live
/// from the student's own review doc (firestore.rules lets the author read it).
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.booking, required this.service});

  final Booking booking;
  final ReviewService service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<InstructorReview?>(
      stream: service.myReview(booking.instructorUid, booking.studentUid),
      builder: (context, snap) {
        // Nothing until the first answer, so the card doesn't flash empty.
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        final review = snap.data;
        void open({int rating = 0}) => showReviewSheet(
              context,
              service: service,
              bookingId: booking.id,
              instructorUid: booking.instructorUid,
              instructorName: booking.instructorName,
              existing: review,
              rating: rating,
            );
        final title = AppTypography.body.copyWith(
          fontSize: 17,
          color: AppColors.ink,
          fontVariations: const [FontVariation('wght', 600)],
        );
        if (review == null) {
          return _Card(
            children: [
              Text(l.translate('review_rate_title'), style: title),
              const SizedBox(height: AppSpacing.x1),
              Text(l.translate('review_rate_desc'), style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
              const SizedBox(height: AppSpacing.x2),
              Center(child: ReviewStars(rating: 0, size: 32, onTap: (n) => open(rating: n))),
            ],
          );
        }
        return _Card(
          children: [
            Text(l.translate('review_yours'), style: title),
            const SizedBox(height: AppSpacing.x2),
            ReviewStars(rating: review.rating),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(review.comment, style: AppTypography.body.copyWith(color: AppColors.ink)),
            ],
            const SizedBox(height: AppSpacing.x3),
            BentoActionButton(text: l.translate('review_edit'), primary: false, onCard: true, onTap: open),
          ],
        );
      },
    );
  }
}
