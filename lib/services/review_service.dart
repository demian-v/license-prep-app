import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/instructor_listing.dart';

/// Reviews (instructors plan v2 §11, P8). Every write goes through the
/// callables in functions/src/reviews.ts, which check the completed lesson,
/// mask the comment and keep the instructor's rating numbers exact. Reads
/// are direct only where firestore.rules allows them: a student's own review,
/// and an instructor's reviews of themselves.
class ReviewService {
  ReviewService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestoreOverride = firestore,
        _functions = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _fns => _functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> _reviews(String instructorUid) =>
      _firestore.collection('instructors').doc(instructorUid).collection('reviews');

  /// The review [studentUid] wrote about [instructorUid], live; null when none.
  Stream<InstructorReview?> myReview(String instructorUid, String studentUid) => _reviews(instructorUid)
      .doc(studentUid)
      .snapshots()
      .map((s) => s.exists ? InstructorReview.fromDoc(s.data()!) : null);

  /// An instructor's reviews of themselves, newest first («Мои отзывы»).
  Stream<List<InstructorReview>> reviewsOf(String instructorUid) => _reviews(instructorUid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => [for (final d in snap.docs) InstructorReview.fromDoc(d.data())]);

  /// Writes or edits the review of the school from [bookingId]. Returns
  /// whether it was an edit.
  Future<bool> submit(String bookingId, int rating, String comment) async {
    final result = await _fns.httpsCallable('submitReview').call({
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
    });
    return (result.data as Map)['edited'] == true;
  }

  Future<void> delete(String instructorUid) =>
      _fns.httpsCallable('deleteReview').call({'instructorUid': instructorUid});
}
