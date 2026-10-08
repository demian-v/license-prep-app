import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/models/booking.dart';
import 'package:license_prep_app/models/instructor_listing.dart';
import 'package:license_prep_app/screens/booking_detail_screen.dart';
import 'package:license_prep_app/screens/instructor_detail_screen.dart';
import 'package:license_prep_app/services/booking_service.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/services/review_service.dart';
import 'package:license_prep_app/widgets/instructor_profile_section.dart';
import 'package:license_prep_app/widgets/review_parts.dart';

/// Instructors P8 — reviews (plan v2 §11). The server half (who may review,
/// the rating maths, masking, reports, the push, deletion) is tested in
/// functions/src/__tests__/reviews.test.ts; here: where the app offers a
/// review, the sheet, «Мои отзывы», and the strings in every language.

Booking _booking({String status = 'completed', bool instructorDeleted = false}) => Booking(
      id: 'b1',
      studentUid: 's1',
      instructorUid: 'i1',
      studentDisplayName: 'Anna K.',
      instructorName: 'Lakeview Driving School',
      startAt: DateTime.now().subtract(const Duration(days: 2)),
      durationMinutes: 60,
      localDate: '2026-10-05',
      localTime: '10:00',
      lessonCents: 6500,
      platformFeeCents: 325,
      totalCents: 6825,
      feeKind: 'later',
      status: status,
      timezone: 'America/Chicago',
      instructorDeleted: instructorDeleted,
    );

class _Bookings extends BookingService {
  _Bookings(this.b);

  final Booking b;

  @override
  Stream<Booking?> booking(String id) => Stream.value(b);
}

class _Reviews extends ReviewService {
  _Reviews({this.mine, this.list = const []});

  final InstructorReview? mine;
  final List<InstructorReview> list;
  final submitted = <(String, int, String)>[];
  final deleted = <String>[];

  @override
  Stream<InstructorReview?> myReview(String instructorUid, String studentUid) => Stream.value(mine);

  @override
  Stream<List<InstructorReview>> reviewsOf(String instructorUid) => Stream.value(list);

  @override
  Future<bool> submit(String bookingId, int rating, String comment) async {
    submitted.add((bookingId, rating, comment));
    return mine != null;
  }

  @override
  Future<void> delete(String instructorUid) async => deleted.add(instructorUid);
}

class _Profile extends InstructorService {
  _Profile(this.doc);

  final Map<String, dynamic> doc;

  @override
  Stream<Map<String, dynamic>?> ownProfile(String uid) => Stream.value(doc);
}

/// The school's page as a student sees it: the student's own review first.
class _Page extends InstructorService {
  static final school = InstructorListing.fromMap({
    'id': 'i1', 'kind': 'school', 'name': 'Lakeview Driving School', 'city': 'Chicago', 'state': 'IL',
    'languages': ['en'], 'stage': 2, 'ratingAvg': 4.5, 'ratingCount': 2, 'lessonDurations': [60],
    'hourlyRateCents': 6500, 'priceHidden': false, 'payoutsEnabled': true,
  });

  @override
  Future<InstructorListing> detail(String id) async => school;

  @override
  Future<List<InstructorReview>> reviews(String id) async => const [
        InstructorReview(id: 'r-mine', name: 'Anna K.', rating: 4, comment: 'Mine', mine: true),
        InstructorReview(id: 'r-other', name: 'Jake M.', rating: 5, comment: 'Theirs'),
      ];

  @override
  Stream<Set<String>> favorites(String uid) => const Stream.empty();
}

const _mine = InstructorReview(id: 'r1', name: 'Anna K.', rating: 4, comment: 'Calm and clear.');

Future<void> _pump(WidgetTester tester, Widget home, {String locale = 'en'}) async {
  await tester.binding.setSurfaceSize(const Size(402, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale(locale)],
      home: home,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

Future<void> _lesson(WidgetTester tester, Booking b, _Reviews reviews, {bool asInstructor = false}) => _pump(
      tester,
      BookingDetailScreen(bookingId: b.id, asInstructor: asInstructor, service: _Bookings(b), reviews: reviews),
    );

Map<String, dynamic> _locale(String lang) =>
    jsonDecode(File('lib/localization/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('the model', () {
    test('a held lesson can be reviewed; anything else cannot', () {
      expect(_booking().reviewable, isTrue);
      expect(_booking(status: 'payout_released').reviewable, isTrue);
      for (final s in ['confirmed', 'pending_payment', 'refunded', 'late_cancelled', 'expired', 'disputed']) {
        expect(_booking(status: s).reviewable, isFalse, reason: s);
      }
    });

    test('a review from the callable carries the opaque id; one read directly too', () {
      final r = InstructorReview.fromMap({'id': 'abc', 'name': 'Anna K.', 'rating': 5, 'comment': 'Hi', 'createdAtMs': 0});
      expect([r.id, r.name, r.rating, r.comment], ['abc', 'Anna K.', 5, 'Hi']);
      expect(InstructorReview.fromMap({'name': 'X', 'rating': 3}).id, isNull);
      expect(InstructorReview.fromMap({'name': 'X', 'rating': 3, 'mine': true}).mine, isTrue);
      expect(r.mine, isFalse);
      final d = InstructorReview.fromDoc({
        'reviewId': 'xyz', 'studentDisplayName': 'Jake M.', 'rating': 2, 'comment': '',
        'createdAt': Timestamp.fromMillisecondsSinceEpoch(86400000),
      });
      expect([d.id, d.name, d.rating, d.createdAt], ['xyz', 'Jake M.', 2, DateTime.fromMillisecondsSinceEpoch(86400000)]);
    });
  });

  group('the lesson page', () {
    testWidgets('a held lesson asks for a review; the tapped star opens the sheet with it', (tester) async {
      final reviews = _Reviews();
      await _lesson(tester, _booking(), reviews);
      expect(find.text('Rate your lesson'), findsOneWidget);
      expect(find.text('Other students will see your review.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('review_star_4')));
      await tester.pumpAndSettle();
      expect(find.byType(ReviewSheet), findsOneWidget);
      expect(find.text('Phone numbers, emails and links are hidden.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Good teacher  ');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(reviews.submitted, [('b1', 4, 'Good teacher')]);
      expect(find.byType(ReviewSheet), findsNothing);
      expect(find.text('Thanks for your review!'), findsOneWidget);
    });

    testWidgets('a written review shows with «Edit»; the sheet edits or deletes it', (tester) async {
      final reviews = _Reviews(mine: _mine);
      await _lesson(tester, _booking(), reviews);
      expect(find.text('Your review'), findsOneWidget);
      expect(find.text('Calm and clear.'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review_star_2')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(reviews.submitted, [('b1', 2, 'Calm and clear.')]);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete review'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your review?'), findsOneWidget);
      // The dialog's confirm is the second «Delete review» on screen.
      await tester.tap(find.text('Delete review').last);
      await tester.pumpAndSettle();
      expect(reviews.deleted, ['i1']);
      expect(find.text('Review deleted'), findsOneWidget);
    });

    testWidgets('no stars chosen, nothing to send', (tester) async {
      final reviews = _Reviews();
      await _pump(
        tester,
        Scaffold(body: ReviewSheet(service: reviews, bookingId: 'b1', instructorUid: 'i1', instructorName: 'Lakeview', rating: 0)),
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(reviews.submitted, isEmpty);
      await tester.tap(find.byKey(const ValueKey('review_star_5')));
      await tester.pump();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(reviews.submitted, [('b1', 5, '')]);
    });

    testWidgets('no review card before the lesson, for the school, or when the school is gone', (tester) async {
      for (final (b, asInstructor) in [
        (_booking(status: 'confirmed'), false),
        (_booking(status: 'refunded'), false),
        (_booking(), true),
        (_booking(instructorDeleted: true), false),
      ]) {
        await _lesson(tester, b, _Reviews(), asInstructor: asInstructor);
        expect(find.text('Rate your lesson'), findsNothing, reason: '${b.status} instructor=$asInstructor');
      }
    });
  });

  group('reporting on the school\'s page', () {
    testWidgets('another student\'s review can be reported; your own cannot', (tester) async {
      await _pump(tester, InstructorDetailScreen(instructor: _Page.school, uid: 's1', service: _Page()));
      ReviewTile tile(String comment) =>
          tester.widget<ReviewTile>(find.ancestor(of: find.text(comment), matching: find.byType(ReviewTile)));
      expect(tile('Mine').onLongPress, isNull);
      expect(tile('Theirs').onLongPress, isNotNull);
    });
  });

  group('«My reviews» in the instructor Профиль', () {
    Future<void> profile(WidgetTester tester, List<InstructorReview> list, {double avg = 0}) => _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: InstructorProfileSection(
                uid: 'i1',
                service: _Profile({'kind': 'school', 'status': 'active', 'stage': 2, 'ratingAvg': avg, 'ratingCount': list.length}),
                reviews: _Reviews(list: list),
              ),
            ),
          ),
        );

    testWidgets('none yet says when they come', (tester) async {
      await profile(tester, const []);
      expect(find.text('My reviews'), findsOneWidget);
      expect(find.text('No reviews yet. Students leave them after their lessons.'), findsOneWidget);
    });

    testWidgets('the rating, the «New» note under 3, the newest three and «All reviews»', (tester) async {
      await profile(tester, const [_mine], avg: 4);
      expect(find.text('4.0 · Reviews: 1'), findsOneWidget);
      expect(find.text('Students see «New» until you have 3 reviews.'), findsOneWidget);
      expect(find.text('Calm and clear.'), findsOneWidget);
      expect(find.text('All reviews'), findsNothing);

      final four = [for (var i = 0; i < 4; i++) InstructorReview(id: 'r$i', name: 'S$i', rating: 5, comment: 'c$i')];
      await profile(tester, four, avg: 4.8);
      expect(find.text('4.8 · Reviews: 4'), findsOneWidget);
      expect(find.text('Students see «New» until you have 3 reviews.'), findsNothing);
      expect(find.text('c3'), findsNothing);
      await tester.tap(find.text('All reviews'));
      await tester.pumpAndSettle();
      expect(find.text('c3'), findsOneWidget);
    });
  });

  group('strings', () {
    // Chosen at run time, so the coverage scan can't see them.
    const runtimeKeys = ['report_review_title', 'review_yours', 'review_rate_title', 'review_stars'];

    for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
      test('every review string exists in $lang', () {
        final m = _locale(lang);
        final keys = m.keys.where((k) => k.startsWith('review_') || k.startsWith('iprof_reviews_')).toList();
        expect(keys.length, 17, reason: lang);
        for (final k in [...runtimeKeys, ...keys]) {
          expect((m[k] as String?)?.isNotEmpty, isTrue, reason: '$lang: $k');
        }
        expect(m['review_stars'], contains('{n}'));
      });
    }

    testWidgets('the review card is translated in ru', (tester) async {
      await _pump(
        tester,
        BookingDetailScreen(bookingId: 'b1', asInstructor: false, service: _Bookings(_booking()), reviews: _Reviews()),
        locale: 'ru',
      );
      expect(find.text('Оцените урок'), findsOneWidget);
    });
  });

  test('the review push routes through the lesson page (booking/<id>)', () {
    // functions/src/bookings.ts sends review_request with `booking/<id>`,
    // which HomeScreen already opens as BookingDetailScreen (P7).
    final bookings = File('functions/src/bookings.ts').readAsStringSync();
    expect(bookings, contains("'review_request', `booking/\${doc.id}`"));
    expect(File('lib/screens/home_screen.dart').readAsStringSync(), contains('BookingDetailScreen(bookingId: route.id!'));
  });

  test('a review report goes through the callable, never a direct write', () {
    final src = File('lib/services/report_service.dart').readAsStringSync();
    final start = src.indexOf('Future<void> submitReviewReport');
    final body = src.substring(start, src.indexOf('\n  }\n', start));
    expect(body, contains("httpsCallable('reportReview')"));
    expect(body, isNot(contains("collection('reports')")));
  });
}
