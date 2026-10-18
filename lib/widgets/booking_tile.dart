import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../localization/app_localizations.dart';
import '../models/booking.dart';
import '../theme/app_theme.dart';
import '../theme/bento_tokens.dart';

/// «Ср, 7 окт. · 10:00» — a lesson's local start, in the app's language.
String bookingWhen(BuildContext context, Booking b) {
  final locale = Localizations.localeOf(context).toString();
  final at = b.localStart;
  return '${DateFormat.MMMEd(locale).format(at)} · ${b.localTime}';
}

/// The status as a short pill text (plan v2 §9.3). Literal keys, so
/// localization_coverage_test sees each one.
String bookingStatusText(AppLocalizations l, Booking b) => l.translate(switch (b.status) {
      'confirmed' => 'booking_status_confirmed',
      'completed' || 'payout_released' => 'booking_status_completed',
      'disputed' => 'booking_status_disputed',
      'late_cancelled' => 'booking_status_late_cancelled',
      'refunded' => 'booking_status_refunded',
      'pending_payment' => 'booking_status_pending_payment',
      _ => 'booking_status_expired',
    });

/// One lesson in a list (instructor Календарь, the student's «Мои уроки»): a
/// date block, who it's with, when and how long, and — once it's over or
/// cancelled — its status under them. The whole card is the button (owner rule 7).
class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking, required this.asInstructor, required this.onTap});

  final Booking booking;

  /// The instructor sees the student's name, the student the school's.
  final bool asInstructor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = booking;
    final locale = Localizations.localeOf(context).toString();
    final name = asInstructor
        ? (b.studentDeleted || b.studentDisplayName.isEmpty ? l.translate('chat_deleted_user') : b.studentDisplayName)
        : (b.instructorDeleted || b.instructorName.isEmpty ? l.translate('chat_deleted_user') : b.instructorName);
    final over = b.status != 'confirmed';
    final cancelled = b.status == 'refunded' || b.status == 'late_cancelled';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(BentoTokens.card),
        boxShadow: AppColors.shadowCard,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(BentoTokens.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x3),
            child: Row(
              children: [
                // The day as a block: a list of lessons reads by date first.
                Container(
                  width: 52,
                  height: 56,
                  decoration: BoxDecoration(
                    color: over ? AppColors.field : AppColors.signal50,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${b.localStart.day}',
                        style: AppTypography.title.copyWith(
                          fontSize: 20,
                          height: 24 / 20,
                          color: over ? AppColors.inkSecondary : AppColors.signal,
                          fontVariations: const [FontVariation('wght', 700)],
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        DateFormat.MMM(locale).format(b.localStart),
                        style: AppTypography.caption.copyWith(
                          color: over ? AppColors.inkSecondary : AppColors.signal,
                          fontVariations: const [FontVariation('wght', 600)],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          fontSize: 17,
                          color: cancelled ? AppColors.inkSecondary : AppColors.ink,
                          fontVariations: const [FontVariation('wght', 600)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat.E(locale).format(b.localStart)} · ${b.localTime} · '
                        '${l.translate('ireg_minutes').replaceAll('{n}', '${b.durationMinutes}')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.inkSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      // Under the time, not beside the name: «Отменён
                      // поздно» beside it cut a school's name to a stub.
                      if (over) ...[
                        const SizedBox(height: AppSpacing.x2),
                        BookingStatusPill(booking: b),
                      ],
                    ],
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

/// The status as a pill: blue while booked, grey once held, red-tinted when
/// cancelled (colour keeps its meaning — red = something went wrong).
class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (bg, fg) = switch (booking.status) {
      'confirmed' => (AppColors.signal50, AppColors.signal),
      'refunded' || 'late_cancelled' || 'expired' => (AppColors.stopSurface, AppColors.stop),
      'disputed' => (AppColors.warnSurface, AppColors.warn),
      _ => (AppColors.field, AppColors.inkSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BentoTokens.chip)),
      child: Text(
        bookingStatusText(l, booking),
        maxLines: 1,
        style: AppTypography.caption.copyWith(color: fg, fontVariations: const [FontVariation('wght', 600)]),
      ),
    );
  }
}

/// Where the school's money for a lesson stands (P9), on the lesson page:
/// green once paid out, amber while held, grey while it waits its 48 h.
class PayoutPill extends StatelessWidget {
  const PayoutPill({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final at = booking.payoutReleaseAt;
    final (bg, fg, text) = switch (booking.payout) {
      PayoutState.released => (AppColors.guideSurface, AppColors.guide, l.translate('payout_released')),
      PayoutState.held => (AppColors.warnSurface, AppColors.warn, l.translate('payout_held')),
      _ => (
          AppColors.field,
          AppColors.inkSecondary,
          at == null ? l.translate('income_pending') : l.translate('payout_pending_on').replaceAll('{date}', DateFormat.MMMd(locale).format(at)),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BentoTokens.chip)),
      child: Text(
        text,
        maxLines: 1,
        style: AppTypography.caption.copyWith(color: fg, fontVariations: const [FontVariation('wght', 600)]),
      ),
    );
  }
}

/// «Прошедшие и доход» (instructor, P9): paid out so far and still to come,
/// as two tiles above the past lessons.
class IncomeSummary extends StatelessWidget {
  const IncomeSummary({super.key, required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final income = incomeOf(bookings);
    Widget tile(String label, int cents) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(BentoTokens.card),
              boxShadow: AppColors.shadowCard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption.copyWith(color: AppColors.inkSecondary)),
                const SizedBox(height: 2),
                Text(
                  formatUsd(cents),
                  style: AppTypography.title.copyWith(
                    fontSize: 20,
                    height: 26 / 20,
                    color: AppColors.ink,
                    fontVariations: const [FontVariation('wght', 700)],
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Row(children: [
        tile(l.translate('income_released'), income.releasedCents),
        const SizedBox(width: AppSpacing.x2),
        tile(l.translate('income_pending'), income.pendingCents),
      ]),
    );
  }
}

/// «Предстоящие уроки» (soonest first), «Прошедшие» and «Отменённые» (both
/// latest first), for the instructor's Календарь and the student's «Мои
/// уроки». Holds and expired holds are not lessons, so they are left out.
List<Widget> bookingSections(
  BuildContext context,
  List<Booking> all, {
  required bool asInstructor,
  required void Function(Booking) onOpen,
}) {
  final l = AppLocalizations.of(context);
  final now = DateTime.now();
  final upcoming = all.where((b) => b.upcoming(now)).toList();
  final past = all.where((b) => b.past(now)).toList().reversed.toList();
  final cancelled = all.where((b) => b.cancelled).toList().reversed.toList();
  Widget header(String key) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Text(
          l.translate(key),
          style: AppTypography.label.copyWith(
            fontSize: 15,
            color: AppColors.ink,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      );
  List<Widget> tiles(List<Booking> list) => [
        for (final b in list) ...[
          BookingTile(booking: b, asInstructor: asInstructor, onTap: () => onOpen(b)),
          const SizedBox(height: AppSpacing.x2),
        ],
      ];
  return [
    header('lessons_upcoming'),
    if (upcoming.isEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x3),
        child: Text(l.translate('lessons_upcoming_none'), style: AppTypography.body.copyWith(color: AppColors.inkSecondary)),
      )
    else
      ...tiles(upcoming),
    // The school's income sits with its past lessons (plan v2 §14.2, P9); a
    // late cancel still pays, so it counts too.
    if (past.isNotEmpty || (asInstructor && all.any((b) => b.payout != null))) ...[
      const SizedBox(height: AppSpacing.x3),
      header(asInstructor ? 'lessons_past_income' : 'lessons_past'),
      if (asInstructor) IncomeSummary(bookings: all),
      ...tiles(past),
    ],
    if (cancelled.isNotEmpty) ...[
      const SizedBox(height: AppSpacing.x3),
      header('lessons_cancelled'),
      ...tiles(cancelled),
    ],
  ];
}
