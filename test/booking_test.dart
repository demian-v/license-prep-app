import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/models/booking.dart';
import 'package:license_prep_app/models/instructor_listing.dart';
import 'package:license_prep_app/screens/booking_screen.dart';
import 'package:license_prep_app/screens/instructor_calendar_screen.dart';
import 'package:license_prep_app/screens/instructor_detail_screen.dart';
import 'package:license_prep_app/services/booking_service.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/widgets/bento_question_parts.dart';
import 'package:license_prep_app/widgets/booking_tile.dart';

/// Instructors P7 — bookings, no money (plan v2 §9). The server half (slot
/// locks, fees, cancellation rules, sweeps) is tested in
/// functions/src/__tests__/bookings.test.ts; here: what the app decides —
/// which starts fit a length, the price lines, the booking page, the lists
/// on Календарь, «Забронировать» by stage, and where the code routes.

const _hour = 3600 * 1000;
final _t0 = DateTime.utc(2026, 10, 7, 15).millisecondsSinceEpoch; // 10:00 Chicago

BookingOptions _options() => BookingOptions.fromMap({
      'timezone': 'America/Chicago',
      'days': [
        {
          'date': '2026-10-07',
          'slots': [
            {'time': '10:00', 'startAtMs': _t0},
            {'time': '10:30', 'startAtMs': _t0 + _hour ~/ 2},
            {'time': '11:00', 'startAtMs': _t0 + _hour},
            // 11:30 is booked: a gap.
            {'time': '12:00', 'startAtMs': _t0 + 2 * _hour},
          ],
        },
        {
          'date': '2026-10-08',
          'slots': [
            {'time': '09:00', 'startAtMs': _t0 + 23 * _hour},
          ],
        },
      ],
      'quotes': [
        {'durationMinutes': 60, 'lessonCents': 6500, 'platformFeeCents': 1625, 'totalCents': 8125, 'feeKind': 'first'},
        {'durationMinutes': 90, 'lessonCents': 9750, 'platformFeeCents': 2438, 'totalCents': 12188, 'feeKind': 'first'},
      ],
    });

Booking _booking({
  String id = 'b1',
  String status = 'confirmed',
  DateTime? startAt,
  String localDate = '2026-10-07',
  String localTime = '10:00',
  String? cancelledBy,
}) =>
    Booking(
      id: id,
      studentUid: 's1',
      instructorUid: 'i1',
      studentDisplayName: 'Anna K.',
      instructorName: 'Lakeview Driving School',
      startAt: startAt ?? DateTime.now().add(const Duration(days: 2)),
      durationMinutes: 60,
      localDate: localDate,
      localTime: localTime,
      lessonCents: 6500,
      platformFeeCents: 325,
      totalCents: 6825,
      feeKind: 'later',
      status: status,
      timezone: 'America/Chicago',
      cancelledBy: cancelledBy,
    );

InstructorListing _school({int stage = 2}) => InstructorListing.fromMap({
      'id': 'i1', 'kind': 'school', 'name': 'Lakeview Driving School', 'city': 'Chicago', 'state': 'IL',
      'languages': ['en'], 'stage': stage, 'ratingAvg': 0, 'ratingCount': 0, 'lessonDurations': [60, 90],
      'hourlyRateCents': 6500, 'priceHidden': false, 'payoutsEnabled': stage == 2,
      'schoolAddress': '100 Main St, Chicago, IL',
    });

class _FakeBookings extends BookingService {
  _FakeBookings({this.list = const [], this.error});

  final List<Booking> list;
  final FirebaseFunctionsException? error;
  final created = <(String, int, int)>[];

  @override
  Future<BookingOptions> options(String instructorUid) async => _options();

  @override
  Future<({String id, String status})> create(String instructorUid, int startAtMs, int durationMinutes) async {
    if (error != null) throw error!;
    created.add((instructorUid, startAtMs, durationMinutes));
    return (id: 'new', status: 'confirmed');
  }

  @override
  Stream<List<Booking>> bookings(String uid, {required bool asInstructor}) => Stream.value(list);

  @override
  Stream<Booking?> booking(String id) => Stream.value(_booking(id: id));
}

class _Profile extends InstructorService {
  _Profile(this.stage);

  final int stage;

  @override
  Future<InstructorListing> detail(String id) async => _school(stage: stage);

  @override
  Future<List<InstructorReview>> reviews(String id) async => const [];

  @override
  Stream<Set<String>> favorites(String uid) => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> ownProfile(String uid) =>
      Stream.value({'status': 'active', 'timezone': 'America/Chicago', 'availability': {}});
}

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

Map<String, dynamic> _locale(String lang) =>
    jsonDecode(File('lib/localization/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('which starts fit a lesson', () {
    test('a start needs as many free half hours in a row as the lesson is long', () {
      final o = _options();
      expect(o.startsFor('2026-10-07', 60).map((s) => s.time), ['10:00', '10:30']);
      expect(o.startsFor('2026-10-07', 90).map((s) => s.time), ['10:00']);
      expect(o.startsFor('2026-10-07', 120), isEmpty);
      expect(o.startsFor('2026-10-09', 60), isEmpty);
    });

    test('only dates where the length fits at least once', () {
      final o = _options();
      expect(o.datesFor(60), ['2026-10-07']);
      expect(o.datesFor(90), ['2026-10-07']);
    });

    test('money is whole dollars or two decimals', () {
      expect(formatUsd(7500), r'$75');
      expect(formatUsd(6350), r'$63.50');
      expect(formatUsd(150), r'$1.50');
    });
  });

  group('a lesson, in time', () {
    test('upcoming until it ends; past once held; cancelled on its own; holds are none', () {
      final now = DateTime.now();
      expect(_booking().upcoming(now), isTrue);
      final ended = _booking(startAt: now.subtract(const Duration(hours: 2)));
      expect(ended.upcoming(now), isFalse);
      expect(ended.past(now), isTrue);
      expect(_booking(status: 'completed').past(now), isTrue);
      // A cancelled future lesson is not «past» (owner, 2026-10-05).
      for (final s in ['late_cancelled', 'refunded']) {
        final b = _booking(status: s);
        expect(b.cancelled && !b.past(now) && !b.upcoming(now), isTrue, reason: s);
      }
      for (final s in ['pending_payment', 'expired']) {
        final b = _booking(status: s);
        expect(b.upcoming(now) || b.past(now) || b.cancelled, isFalse, reason: s);
      }
    });

    test('free cancellation is 24 hours or more ahead', () {
      final now = DateTime.now();
      expect(_booking(startAt: now.add(const Duration(hours: 25))).freeCancel(now), isTrue);
      expect(_booking(startAt: now.add(const Duration(hours: 23))).freeCancel(now), isFalse);
    });

    test('the local start comes from the server-written wall clock, not the phone zone', () {
      final b = _booking(startAt: DateTime.utc(2026, 10, 7, 15), localDate: '2026-10-07', localTime: '10:00');
      expect(b.localStart, DateTime(2026, 10, 7, 10));
    });
  });

  group('the booking page', () {
    testWidgets('length, date, start, then the price; «Book» sends the chosen start', (tester) async {
      final svc = _FakeBookings();
      await _pump(tester, BookingScreen(instructor: _school(), service: svc));
      BentoActionButton book() => tester.widget<BentoActionButton>(
          find.ancestor(of: find.text('Book'), matching: find.byType(BentoActionButton)));

      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('90 min'), findsOneWidget);
      expect(find.text('Central Time · Chicago'), findsOneWidget);
      // The first-lesson price, lesson + service fee + total.
      expect(find.text('Lesson, 60 min'), findsOneWidget);
      expect(find.text(r'$65'), findsOneWidget);
      expect(find.text('Service fee'), findsOneWidget);
      expect(find.text(r'$16.25'), findsOneWidget);
      expect(find.text(r'$81.25'), findsOneWidget);
      expect(find.text('First lesson with this school'), findsOneWidget);
      expect(book().onTap, isNull);

      await tester.tap(find.text('10:30'));
      await tester.pump();
      await tester.tap(find.text('Book'));
      await tester.pumpAndSettle();
      expect(svc.created, [('i1', _t0 + _hour ~/ 2, 60)]);
    });

    testWidgets('a longer lesson drops the starts it no longer fits', (tester) async {
      await _pump(tester, BookingScreen(instructor: _school(), service: _FakeBookings()));
      await tester.tap(find.text('90 min'));
      await tester.pumpAndSettle();
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('10:30'), findsNothing);
      expect(find.text(r'$121.88'), findsOneWidget);
    });

    testWidgets('a time taken meanwhile says so', (tester) async {
      final svc = _FakeBookings(error: FirebaseFunctionsException(code: 'already-exists', message: 'slot-taken'));
      await _pump(tester, BookingScreen(instructor: _school(), service: svc));
      await tester.tap(find.text('10:00'));
      await tester.pump();
      await tester.tap(find.text('Book'));
      await tester.pump();
      expect(find.text('Someone just booked this time. Pick another.'), findsOneWidget);
    });
  });

  group('«Book» on the detail page', () {
    BentoActionButton book(WidgetTester tester) => tester.widget<BentoActionButton>(
        find.ancestor(of: find.text('Book'), matching: find.byType(BentoActionButton)));

    testWidgets('opens for a stage-2 school, with no reason under it', (tester) async {
      await _pump(tester, InstructorDetailScreen(instructor: _school(), uid: 's1', service: _Profile(2)));
      expect(book(tester).onTap, isNotNull);
      expect(find.text('Booking opens once the licence is checked.'), findsNothing);
    });

    testWidgets('stays disabled below stage 2, with the licence reason', (tester) async {
      await _pump(tester, InstructorDetailScreen(instructor: _school(stage: 1), uid: 's1', service: _Profile(1)));
      expect(book(tester).onTap, isNull);
      expect(find.text(_locale('en')['instructor_book_after_check'] as String), findsOneWidget);
    });
  });

  group('the lists', () {
    testWidgets('Календарь lists upcoming, past and cancelled lessons under the grid', (tester) async {
      final now = DateTime.now();
      final svc = _FakeBookings(list: [
        _booking(id: 'a', status: 'completed', startAt: now.subtract(const Duration(days: 3))),
        _booking(id: 'b', startAt: now.add(const Duration(days: 2))),
        _booking(id: 'c', status: 'refunded', cancelledBy: 'instructor', startAt: now.add(const Duration(days: 4))),
        _booking(id: 'd', status: 'expired'),
      ]);
      await _pump(tester, InstructorCalendarScreen(service: _Profile(2), bookings: svc, uid: 'i1'));
      expect(find.text('Upcoming lessons'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      // The instructor sees the student; an expired hold is not a lesson.
      expect(find.text('Anna K.'), findsNWidgets(3));
      expect(find.text('Completed'), findsOneWidget);
      // In English the group header and the pill read the same.
      expect(find.text('Cancelled'), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Past')).dy < tester.getTopLeft(find.text('Cancelled').first).dy,
        isTrue,
      );
    });

    testWidgets('no lessons yet says so', (tester) async {
      await _pump(tester, InstructorCalendarScreen(service: _Profile(2), bookings: _FakeBookings(), uid: 'i1'));
      expect(find.text('No lessons booked yet.'), findsOneWidget);
      expect(find.text('Past'), findsNothing);
    });

    for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
      testWidgets('a lesson row is translated in $lang', (tester) async {
        await _pump(
          tester,
          Scaffold(body: BookingTile(booking: _booking(status: 'late_cancelled'), asInstructor: false, onTap: () {})),
          locale: lang,
        );
        expect(find.text(_locale(lang)['booking_status_late_cancelled'] as String), findsOneWidget);
        expect(find.text('Lakeview Driving School'), findsOneWidget);
      });
    }
  });

  group('where the code routes', () {
    String code(String path) => File(path).readAsStringSync();

    test('a booking push opens the lesson instead of being dropped', () {
      final home = code('lib/screens/home_screen.dart');
      expect(home, contains("route.name != 'booking'"));
      expect(home, contains('BookingDetailScreen(bookingId: route.id!'));
    });

    test('the status keys chosen at runtime exist in every language', () {
      for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
        for (final s in ['confirmed', 'completed', 'late_cancelled', 'refunded', 'pending_payment', 'expired']) {
          expect(_locale(lang)['booking_status_$s'], isA<String>(), reason: '$lang $s');
        }
      }
    });

    test('a refused deletion keeps the user signed in (rethrown before the local sign-out)', () {
      final provider = code('lib/providers/auth_provider.dart');
      final refusal = provider.indexOf('_deletionRefused.contains(e.code)');
      final signOut = provider.indexOf("debugPrint('🗑️ AuthProvider: User account deleted locally due to API error')");
      expect(refusal, greaterThan(0));
      expect(refusal, lessThan(signOut));
      expect(code('lib/screens/personal_info_screen.dart'), contains("refusal?.message == 'upcoming-bookings'"));
    });

    test('a booking-created thread with no message reads «Урок забронирован»', () {
      expect(code('lib/screens/chat_list_screen.dart'), contains("l.translate('chat_lesson_booked')"));
      expect(_locale('ru')['chat_lesson_booked'], 'Урок забронирован');
    });

    test('a school thread has a black «Забронировать урок» pill under the header, and contacts copy', () {
      final thread = code('lib/screens/chat_thread_screen.dart');
      expect(thread, contains("l.translate('chat_book_lesson')"));
      expect(thread, contains('Clipboard.setData(ClipboardData(text: value))'));
      expect(thread, contains("l.translate('chat_copied')"));
    });

    test('account deletion checks upcoming lessons before the dialog', () {
      final screen = code('lib/screens/personal_info_screen.dart');
      expect(screen, contains('_deleteIfNoLessons(context, languageProvider)'));
      expect(screen, contains("'delete_upcoming_bookings'"));
    });

    test('the orphaned «coming in an update» reason is gone', () {
      for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
        expect(_locale(lang).containsKey('instructor_book_soon'), isFalse);
      }
      expect(code('lib/screens/instructor_detail_screen.dart'), isNot(contains('instructor_book_soon')));
    });
  });
}
