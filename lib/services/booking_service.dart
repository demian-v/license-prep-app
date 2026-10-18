import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/booking.dart';

/// Bookings (instructors plan v2 §9, P7). Reads are live Firestore listeners
/// (the two sides only, firestore.rules); every write goes through the
/// callables in functions/src/bookings.ts, which lock the half hours, work
/// out the fees and apply the cancellation rules.
class BookingService {
  BookingService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestoreOverride = firestore,
        _functions = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _fns => _functions ?? FirebaseFunctions.instance;

  /// The user's bookings on one side ('studentUid' or 'instructorUid'),
  /// sorted by start here: a query orderBy would need a composite index
  /// (risk #15), and a user has tens of bookings, not thousands.
  Stream<List<Booking>> bookings(String uid, {required bool asInstructor}) => _firestore
          .collection('bookings')
          .where(asInstructor ? 'instructorUid' : 'studentUid', isEqualTo: uid)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(Booking.fromDoc).toList();
        list.sort((a, b) => a.startAt.compareTo(b.startAt));
        return list;
      });

  /// Lessons whose money is still open (P9, plan v2 §9.4): a no-show report
  /// or a card dispute on either side, or — for the school — a held lesson
  /// not paid out yet. Account deletion waits for them; the server checks
  /// the same (`unsettled-bookings`).
  Future<int> unsettledCount(String uid) async {
    final sides = await Future.wait([
      for (final field in ['studentUid', 'instructorUid'])
        _firestore.collection('bookings').where(field, isEqualTo: uid).get(),
    ]);
    bool disputed(Booking b) => b.status == 'disputed' || b.disputeStatus == 'open';
    return sides[0].docs.map(Booking.fromDoc).where(disputed).length +
        sides[1].docs.map(Booking.fromDoc).where((b) => disputed(b) || b.payoutReleaseAt != null).length;
  }

  /// Upcoming confirmed lessons on either side — account deletion waits for
  /// them to be cancelled (plan v2 §9.4).
  Future<int> upcomingCount(String uid) async {
    final now = DateTime.now();
    final sides = await Future.wait([
      for (final field in ['studentUid', 'instructorUid'])
        _firestore.collection('bookings').where(field, isEqualTo: uid).get(),
    ]);
    return sides
        .expand((s) => s.docs)
        .map(Booking.fromDoc)
        .where((b) => b.status == 'confirmed' && b.startAt.isAfter(now))
        .length;
  }

  Stream<Booking?> booking(String id) => _firestore
      .collection('bookings')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Booking.fromDoc(s) : null);

  Future<BookingOptions> options(String instructorUid) async {
    final result = await _fns.httpsCallable('getBookingOptions').call({'instructorUid': instructorUid});
    return BookingOptions.fromMap(result.data as Map);
  }

  /// Returns the new booking's id and status: `confirmed` from the
  /// emulator's instant gateway, or `pending_payment` with what Stripe's
  /// PaymentSheet needs (P9).
  Future<({String id, String status, PaymentStart? payment})> create(String instructorUid, int startAtMs, int durationMinutes) async {
    final result = await _fns.httpsCallable('createBooking').call({
      'instructorUid': instructorUid,
      'startAtMs': startAtMs,
      'durationMinutes': durationMinutes,
    });
    final data = result.data as Map;
    final payment = data['payment'];
    return (
      id: data['bookingId'] as String,
      status: data['status'] as String,
      payment: payment is Map
          ? PaymentStart(clientSecret: payment['clientSecret'] as String, publishableKey: payment['publishableKey'] as String)
          : null,
    );
  }

  /// The PaymentSheet was closed without paying: the time is freed at once.
  Future<void> releaseHold(String bookingId) =>
      _fns.httpsCallable('releaseBookingHold').call({'bookingId': bookingId});

  /// «Урок не состоялся» (P9): holds the school's payout until the admin
  /// looks at it.
  Future<void> reportNoShow(String bookingId) =>
      _fns.httpsCallable('reportNoShow').call({'bookingId': bookingId, 'reason': 'instructor_no_show'});

  /// The status it ended in: `refunded` or `late_cancelled`.
  Future<String> cancel(String bookingId) async {
    final result = await _fns.httpsCallable('cancelBooking').call({'bookingId': bookingId});
    return (result.data as Map)['status'] as String;
  }
}
