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
  /// expired.
  final String status;
  final String? timezone;
  final String? schoolAddress;

  /// 'student' or 'instructor', once cancelled.
  final String? cancelledBy;
  final bool studentDeleted;
  final bool instructorDeleted;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));

  /// A confirmed lesson that hasn't ended: both lists' «Предстоящие».
  bool upcoming(DateTime now) => status == 'confirmed' && endAt.isAfter(now);

  /// Shown under «Прошедшие»: held, or a confirmed lesson the completion
  /// sweep hasn't reached yet. Holds and expired holds are not lessons.
  bool past(DateTime now) => status == 'completed' || (status == 'confirmed' && !endAt.isAfter(now));

  /// Shown under «Отменённые» (owner, 2026-10-05: a cancelled future lesson
  /// read wrong under «Прошедшие»): either side, early or late.
  bool get cancelled => status == 'refunded' || status == 'late_cancelled';

  /// The lesson's local start as a date with no zone, for formatting only.
  DateTime get localStart {
    final d = localDate.split('-').map(int.tryParse).toList();
    final t = localTime.split(':').map(int.tryParse).toList();
    if (d.length != 3 || t.length != 2 || d.contains(null) || t.contains(null)) return startAt;
    return DateTime(d[0]!, d[1]!, d[2]!, t[0]!, t[1]!);
  }

  /// The student may cancel with a refund until 24 h before (plan v2 §9.3).
  bool freeCancel(DateTime now) => startAt.difference(now) >= const Duration(hours: 24);
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
