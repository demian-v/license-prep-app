import 'package:cloud_firestore/cloud_firestore.dart';

/// One lesson, `bookings/{id}` (instructors plan v2 §5, §9). Written only by
/// the server (functions/src/bookings.ts); the student and the instructor
/// read it live. Times are shown in the instructor's timezone (owner,
/// 2026-10-05), from `localDate` / `localTime` the server wrote, so the app
/// needs no timezone database.
class Booking {
  const Booking({
    required this.id,
    required this.studentUid,
    required this.instructorUid,
    required this.studentDisplayName,
    required this.instructorName,
    required this.startAt,
    required this.durationMinutes,
    required this.localDate,
    required this.localTime,
    required this.lessonCents,
    required this.platformFeeCents,
    required this.totalCents,
    required this.feeKind,
    required this.status,
    this.timezone,
    this.schoolAddress,
    this.cancelledBy,
    this.studentDeleted = false,
    this.instructorDeleted = false,
    this.paymentProvider,
    this.refundStatus,
    this.payoutReleaseAt,
    this.payoutReleasedAt,
    this.payoutCancelledAt,
    this.disputeStatus,
    this.noShowResolution,
  });

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    int cents(String key) => (d[key] as num?)?.toInt() ?? 0;
    return Booking(
      id: doc.id,
      studentUid: d['studentUid'] as String? ?? '',
      instructorUid: d['instructorUid'] as String? ?? '',
      studentDisplayName: d['studentDisplayName'] as String? ?? '',
      instructorName: d['instructorName'] as String? ?? '',
      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime(0),
      durationMinutes: (d['durationMinutes'] as num?)?.toInt() ?? 0,
      localDate: d['localDate'] as String? ?? '',
      localTime: d['localTime'] as String? ?? '',
      lessonCents: cents('lessonCents'),
      platformFeeCents: cents('platformFeeCents'),
      totalCents: cents('totalCents'),
      feeKind: d['feeKind'] as String? ?? 'later',
      status: d['status'] as String? ?? '',
      timezone: d['timezone'] as String?,
      schoolAddress: d['schoolAddress'] as String?,
      cancelledBy: d['cancelledBy'] as String?,
      studentDeleted: d['studentDeleted'] == true,
      instructorDeleted: d['instructorDeleted'] == true,
      paymentProvider: d['paymentProvider'] as String?,
      refundStatus: d['refundStatus'] as String?,
      payoutReleaseAt: (d['payoutReleaseAt'] as Timestamp?)?.toDate(),
      payoutReleasedAt: (d['payoutReleasedAt'] as Timestamp?)?.toDate(),
      payoutCancelledAt: (d['payoutCancelledAt'] as Timestamp?)?.toDate(),
      disputeStatus: d['disputeStatus'] as String?,
      noShowResolution: d['noShowResolution'] as String?,
    );
  }

  final String id;
  final String studentUid;
  final String instructorUid;

  /// «Anna K.» — what the instructor sees of the student.
  final String studentDisplayName;

  /// The school's name, for the student.
  final String instructorName;
  final DateTime startAt;
  final int durationMinutes;

  /// 'YYYY-MM-DD' and 'HH:MM' where the lesson happens.
  final String localDate;
  final String localTime;
  final int lessonCents;
  final int platformFeeCents;
  final int totalCents;

  /// 'first' (25%) or 'later' (5%, min $1.50) — plan v2 §9.1.
  final String feeKind;

  /// §9.3: pending_payment, confirmed, completed, late_cancelled, refunded,
  /// expired; P9 adds disputed (a no-show report) and payout_released.
  final String status;
  final String? timezone;
  final String? schoolAddress;

  /// 'student' or 'instructor', once cancelled; 'system' when a payment
  /// arrived after the hold ran out and the time was taken (P9); 'admin'
  /// when a no-show report was resolved with a refund (P10a).
  final String? cancelledBy;
  final bool studentDeleted;
  final bool instructorDeleted;

  /// 'stripe' (real money, P9) or 'emulator' (the instant local gateway).
  final String? paymentProvider;

  /// A Stripe refund: 'pending', 'failed' (retried hourly), 'succeeded'.
  final String? refundStatus;

  /// When the school's money is released (48 h after the end; after the
  /// start for a late cancel). Set only while it waits.
  final DateTime? payoutReleaseAt;

  /// When it was paid out. A late cancel keeps its status and carries only
  /// this (it was never held, so it doesn't become `payout_released`).
  final DateTime? payoutReleasedAt;

  /// The payout was cancelled: the student's bank took the money back (a
  /// lost card dispute, payments.ts recordDispute).
  final DateTime? payoutCancelledAt;

  /// A card dispute: 'open' while Stripe runs it, then Stripe's result.
  final String? disputeStatus;

  /// The admin's answer to a no-show report (adminResolveNoShow, P10a):
  /// 'refund' or 'release'. Once set, the lesson can't be reported again.
  final String? noShowResolution;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  /// A confirmed lesson that hasn't ended: both lists' «Предстоящие».
  bool upcoming(DateTime now) => status == 'confirmed' && endAt.isAfter(now);

  /// Shown under «Прошедшие»: held (paid out or not, or under a no-show
  /// report), or a confirmed lesson the completion sweep hasn't reached yet.
  /// Holds and expired holds are not lessons.
  bool past(DateTime now) =>
      const {'completed', 'payout_released', 'disputed'}.contains(status) || (status == 'confirmed' && !endAt.isAfter(now));

  /// Shown under «Отменённые» (owner, 2026-10-05: a cancelled future lesson
  /// read wrong under «Прошедшие»): either side, early or late.
  bool get cancelled => status == 'refunded' || status == 'late_cancelled';

  /// The student may review the school once the lesson is held (plan v2
  /// §11; `payout_released` arrives with P9). submitReview checks it again.
  bool get reviewable => status == 'completed' || status == 'payout_released';

  /// The lesson's local start as a date with no zone, for formatting only.
  DateTime get localStart {
    final d = localDate.split('-').map(int.tryParse).toList();
    final t = localTime.split(':').map(int.tryParse).toList();
    if (d.length != 3 || t.length != 2 || d.contains(null) || t.contains(null)) return startAt;
    return DateTime(d[0]!, d[1]!, d[2]!, t[0]!, t[1]!);
  }

  /// The student may cancel with a refund until 24 h before (plan v2 §9.3).
  bool freeCancel(DateTime now) => startAt.difference(now) >= const Duration(hours: 24);

  /// The student can say a held lesson didn't happen until 48 h after its
  /// end, before the school is paid (reportNoShow, P9).
  bool noShowReportable(DateTime now) =>
      status == 'completed' && noShowResolution == null && now.isBefore(endAt.add(const Duration(hours: 48)));

  /// Where the school's money stands (instructor side, P9): null when there
  /// is none to come (cancelled with a refund, an expired hold, upcoming).
  PayoutState? get payout {
    if (status == 'payout_released' || payoutReleasedAt != null) return PayoutState.released;
    // A card dispute the student won: the school isn't paid (owner, 2026-10-17).
    if (payoutCancelledAt != null) return PayoutState.cancelled;
    // A card dispute holds the money until it ends with the money kept
    // (`won`, or an inquiry closed without a chargeback), as on the server.
    if (status == 'disputed' || (disputeStatus != null && !const ['won', 'warning_closed'].contains(disputeStatus))) {
      return PayoutState.held;
    }
    if (payoutReleaseAt != null) return PayoutState.pending;
    return null;
  }
}

/// The school's money for one lesson: waiting the 48 h, paid out, held
/// while a no-show report or a card dispute is open, or cancelled because
/// the student's bank took the money back.
enum PayoutState { pending, released, held, cancelled }

/// «Прошедшие и доход» (plan v2 §14.2): what has been paid out and what is
/// still to come, in cents, over the instructor's bookings.
({int releasedCents, int pendingCents}) incomeOf(Iterable<Booking> bookings) {
  var released = 0;
  var pending = 0;
  for (final b in bookings) {
    switch (b.payout) {
      case PayoutState.released:
        released += b.lessonCents;
      case PayoutState.pending || PayoutState.held:
        pending += b.lessonCents;
      case PayoutState.cancelled || null:
        break;
    }
  }
  return (releasedCents: released, pendingCents: pending);
}

/// What createBooking returns for a Stripe payment (P9): the PaymentIntent's
/// client secret and the publishable key, so the app has no key built in.
class PaymentStart {
  const PaymentStart({required this.clientSecret, required this.publishableKey});

  final String clientSecret;
  final String publishableKey;
}

/// The price of one lesson length for this student (getBookingOptions).
class BookingQuote {
  const BookingQuote({
    required this.durationMinutes,
    required this.lessonCents,
    required this.platformFeeCents,
    required this.totalCents,
    required this.feeKind,
  });

  factory BookingQuote.fromMap(Map m) => BookingQuote(
        durationMinutes: (m['durationMinutes'] as num).toInt(),
        lessonCents: (m['lessonCents'] as num).toInt(),
        platformFeeCents: (m['platformFeeCents'] as num).toInt(),
        totalCents: (m['totalCents'] as num).toInt(),
        feeKind: m['feeKind'] as String? ?? 'later',
      );

  final int durationMinutes;
  final int lessonCents;
  final int platformFeeCents;
  final int totalCents;
  final String feeKind;
}

/// One free half hour: its local time and its UTC instant.
class BookingSlot {
  const BookingSlot(this.time, this.startAtMs);

  final String time;
  final int startAtMs;
}

/// What the booking page offers: free half hours per local date, 12 h to
/// 60 days ahead, and a quote per lesson length.
class BookingOptions {
  const BookingOptions({required this.timezone, required this.days, required this.quotes});

  factory BookingOptions.fromMap(Map m) => BookingOptions(
        timezone: m['timezone'] as String?,
        days: {
          for (final d in (m['days'] as List? ?? const []))
            (d as Map)['date'] as String: [
              for (final s in (d['slots'] as List? ?? const []))
                BookingSlot((s as Map)['time'] as String, (s['startAtMs'] as num).toInt()),
            ],
        },
        quotes: [for (final q in (m['quotes'] as List? ?? const [])) BookingQuote.fromMap(q as Map)],
      );

  final String? timezone;

  /// 'YYYY-MM-DD' → that day's free half hours, in order.
  final Map<String, List<BookingSlot>> days;
  final List<BookingQuote> quotes;

  static const int slotMinutes = 30;

  /// The starts on [date] where a [minutes]-long lesson fits: that many
  /// consecutive free half hours.
  List<BookingSlot> startsFor(String date, int minutes) {
    final slots = days[date] ?? const <BookingSlot>[];
    final need = minutes ~/ slotMinutes;
    const step = slotMinutes * 60 * 1000;
    return [
      for (var i = 0; i + need <= slots.length; i++)
        if (List.generate(need, (k) => slots[i + k].startAtMs == slots[i].startAtMs + k * step).every((ok) => ok))
          slots[i],
    ];
  }

  /// Dates on which a [minutes]-long lesson fits at least once.
  List<String> datesFor(int minutes) =>
      [for (final date in days.keys) if (startsFor(date, minutes).isNotEmpty) date];
}

/// «$75», «$63.50».
String formatUsd(int cents) =>
    '\$${cents % 100 == 0 ? '${cents ~/ 100}' : (cents / 100).toStringAsFixed(2)}';
