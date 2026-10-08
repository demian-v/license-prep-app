import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/instructor_listing.dart';
import '../services/analytics_service.dart';
import '../services/review_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';
import '../theme/solar_icons.dart';
import 'bento_auth_parts.dart';
import 'bento_question_parts.dart';
import 'destructive_dialog.dart';
import 'instructor_card.dart' show InstructorFactPill;

/// Reviews (instructors plan v2 §11): one review in a list, the stars, the
/// «Все отзывы» sheet and the sheet a student writes one in. Shared by the
/// instructor's page, the lesson page and the instructor's «Мои отзывы».

/// One review: the name and the stars as a pill, the comment, the date.
/// [onLongPress] opens the report sheet where a review can be reported.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.onLongPress});

  final InstructorReview review;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final date = review.createdAt;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Padding(
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
      ),
    );
  }
}

/// Five stars: amber up to [rating], grey after. With [onTap] each star is
/// a 48pt target that picks its number.
class ReviewStars extends StatelessWidget {
  const ReviewStars({super.key, required this.rating, this.size = 20, this.onTap});

  final int rating;
  final double size;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var n = 1; n <= 5; n++)
          onTap == null
              ? Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: AppIcons.icon(AppIcons.rating, size: size, color: n <= rating ? AppColors.warn : AppColors.border),
                )
              : Semantics(
                  button: true,
                  selected: n == rating,
                  label: l.translate('review_stars').replaceAll('{n}', '$n'),
                  child: InkResponse(
                    key: ValueKey('review_star_$n'),
                    onTap: () => onTap!(n),
                    radius: 28,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AppIcons.icon(AppIcons.rating,
                            size: size, color: n <= rating ? AppColors.warn : AppColors.border),
                      ),
                    ),
                  ),
                ),
      ],
    );
  }
}

/// «Все отзывы»: every review in a white sheet. [reportable] picks the
/// reviews [onLongPress] applies to (not the reader's own).
void showAllReviews(
  BuildContext context,
  List<InstructorReview> list, {
  void Function(InstructorReview)? onLongPress,
  bool Function(InstructorReview)? reportable,
}) {
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
            for (final r in list)
              ReviewTile(
                review: r,
                onLongPress: onLongPress == null || !(reportable?.call(r) ?? true) ? null : () => onLongPress(r),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Opens the sheet where a student rates the school of a completed lesson
/// (plan v2 §11) — [rating] preselected from the star they tapped — or
/// edits / deletes their [existing] review.
Future<void> showReviewSheet(
  BuildContext context, {
  required ReviewService service,
  required String bookingId,
  required String instructorUid,
  required String instructorName,
  InstructorReview? existing,
  int rating = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.field,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(BentoTokens.card)),
    ),
    builder: (_) => ReviewSheet(
      service: service,
      bookingId: bookingId,
      instructorUid: instructorUid,
      instructorName: instructorName,
      existing: existing,
      rating: existing?.rating ?? rating,
    ),
  );
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.service,
    required this.bookingId,
    required this.instructorUid,
    required this.instructorName,
    required this.rating,
    this.existing,
  });

  final ReviewService service;
  final String bookingId;
  final String instructorUid;
  final String instructorName;
  final int rating;
  final InstructorReview? existing;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late int _rating = widget.rating;
  late final TextEditingController _comment = TextEditingController(text: widget.existing?.comment ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final edited = await widget.service.submit(widget.bookingId, _rating, _comment.text.trim());
      analyticsService.logReviewSubmitted(rating: _rating, edited: edited);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.translate('review_sent')), backgroundColor: AppColors.guide));
    } catch (e) {
      debugPrint('ReviewSheet: submit failed: $e');
      if (mounted) setState(() => _error = l.translate('review_error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => DestructiveDialog(
        title: l.translate('review_delete_title'),
        body: l.translate('review_delete_body'),
        confirm: l.translate('review_delete'),
        keep: l.translate('booking_keep'),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.delete(widget.instructorUid);
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.translate('review_deleted'))));
    } catch (e) {
      debugPrint('ReviewSheet: delete failed: $e');
      if (mounted) setState(() => _error = l.translate('review_error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final editing = widget.existing != null;
    final send = _rating == 0 ? null : _send;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.x4 + AppSpacing.x1, AppSpacing.x6,
          AppSpacing.x4 + AppSpacing.x1, AppSpacing.x4 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BentoAuthCard(
                title: l.translate(editing ? 'review_yours' : 'review_rate_title'),
                children: [
                  Text(widget.instructorName, style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
                  const SizedBox(height: AppSpacing.x2),
                  if (_error != null) ...[BentoAuthError(_error!), const SizedBox(height: AppSpacing.x3)],
                  Center(child: ReviewStars(rating: _rating, size: 36, onTap: (n) => setState(() => _rating = n))),
                  const SizedBox(height: AppSpacing.x3),
                  // InputDecorator centres prefixIcon vertically; in a tall
                  // field the icon belongs on the first line, so the slot
                  // stays empty and the icon is drawn over it (as on the
                  // Профиль description editor).
                  Stack(
                    children: [
                      TextField(
                        controller: _comment,
                        keyboardType: TextInputType.multiline,
                        maxLines: 5,
                        minLines: 3,
                        maxLength: 500,
                        style: AppTypography.body.copyWith(color: AppColors.ink),
                        decoration: bentoFieldDecoration(
                                label: l.translate('review_comment'), icon: SolarIcons.chatRoundLineLinear)
                            .copyWith(prefixIcon: const SizedBox(width: 48), alignLabelWithHint: true),
                      ),
                      const Positioned(
                        left: 13,
                        top: AppSpacing.x4 + 1,
                        child: IgnorePointer(
                            child: Icon(SolarIcons.chatRoundLineLinear, color: AppColors.inkSecondary, size: 22)),
                      ),
                    ],
                  ),
                  Text(l.translate('review_masked_note'),
                      style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              if (_busy)
                const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
              else if (editing)
                // Two actions: white + black (owner rule 16).
                Row(
                  children: [
                    Expanded(child: BentoActionButton(text: l.translate('review_delete'), primary: false, onTap: _delete)),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(child: BentoActionButton(text: l.translate('save'), ink: true, onTap: send)),
                  ],
                )
              else
                // The sheet's own lone action: the dark ink pill (rule 16).
                BentoActionButton(text: l.translate('review_send'), ink: true, onTap: send),
            ],
          ),
        ),
      ),
    );
  }
}
