import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/models/instructor_listing.dart';
import 'package:license_prep_app/screens/instructor_detail_screen.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/widgets/instructor_card.dart';
import 'package:license_prep_app/widgets/report_sheet.dart';

/// Instructors P4 — what a paid student sees: the listing's filters and
/// order (plan v2 §13), the card, and the detail page.

InstructorListing _listing({
  String id = 'i1',
  String kind = 'school',
  int stage = 2,
  double ratingAvg = 4.5,
  int ratingCount = 4,
  bool payouts = true,
  bool priceHidden = false,
  int? cents = 6500,
  List<String> languages = const ['en', 'pl'],
  String city = 'Chicago',
  bool dual = true,
}) =>
    InstructorListing.fromMap({
      'id': id,
      'kind': kind,
      'name': 'Name $id',
      'city': city,
      'state': 'IL',
      'languages': languages,
      'stage': stage,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
      'payoutsEnabled': payouts,
      'priceHidden': priceHidden,
      if (cents != null) 'hourlyRateCents': cents,
      'lessonDurations': [60, 90],
      'hasDualControls': dual,
      'schoolName': kind == 'school' ? 'Name $id' : null,
      'schoolLicenseNumber': 'IL-DS-1000',
      'carModel': 'Toyota Corolla',
      'carYear': 2021,
      'photoPath': null,
    });

class _FakeService extends InstructorService {
  _FakeService({this.detailError, this.kind = 'school', List<InstructorReview>? reviews})
      : _reviews = reviews ?? const [];

  final Object? detailError;
  final String kind;
  final List<InstructorReview> _reviews;
  final favorites$ = StreamController<Set<String>>.broadcast();
  final saves = <(String, bool)>[];

  @override
  Future<InstructorListing> detail(String id) async {
    if (detailError != null) throw detailError!;
    return InstructorListing.fromMap({
      'id': id, 'kind': kind, 'name': 'Lakeview', 'city': 'Chicago', 'state': 'IL',
      'languages': ['en'], 'stage': 0, 'ratingAvg': 0, 'ratingCount': 0, 'lessonDurations': [60],
      'hourlyRateCents': 6500, 'schoolName': 'Lakeview',
      'availability': {'mon': [{'start': '09:00', 'end': '12:00'}, {'start': '14:00', 'end': '18:00'}]},
      'timezone': 'America/Chicago',
    });
  }

  @override
  Future<List<InstructorReview>> reviews(String id) async => _reviews;

  @override
  Stream<Set<String>> favorites(String uid) => favorites$.stream;

  @override
  Future<void> setFavorite(String uid, String instructorId, bool saved) async => saves.add((instructorId, saved));
}

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale(locale)],
      home: child,
    );

Future<void> _pump(WidgetTester tester, Widget child, {String locale = 'en'}) async {
  await tester.binding.setSurfaceSize(const Size(402, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    await tester.pumpWidget(_app(child, locale: locale));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  group('filters', () {
    final school = _listing(id: 's', kind: 'school', cents: 8000, languages: ['en']);
    final private = _listing(id: 'p', kind: 'schoolInstructor', stage: 1, priceHidden: true, cents: null, languages: ['uk']);
    final newOne = _listing(id: 'n', ratingAvg: 5, ratingCount: 1, cents: 5000, city: 'Evanston', dual: false);

    test('empty filters match everyone', () {
      expect([school, private, newOne].where(const InstructorFilters().matches), hasLength(3));
      expect(const InstructorFilters().activeCount, 0);
    });

    test('driving schools / private instructors by kind', () {
      expect(const InstructorFilters(kind: 'schoolInstructor').matches(private), isTrue);
      expect(const InstructorFilters(kind: 'schoolInstructor').matches(school), isFalse);
    });

    test('a price cap drops profiles whose price is hidden', () {
      const f = InstructorFilters(maxPriceUsd: 70);
      expect([school, private, newOne].where(f.matches).map((i) => i.id), ['n']);
    });

    test('language is any-of, city exact', () {
      expect(const InstructorFilters(languages: {'uk', 'de'}).matches(private), isTrue);
      expect(const InstructorFilters(languages: {'de'}).matches(private), isFalse);
      expect(const InstructorFilters(city: 'Evanston').matches(newOne), isTrue);
      expect(const InstructorFilters(city: 'Evanston').matches(school), isFalse);
    });

    test('rating 4+ needs three reviews; bookable means a stage-2 school', () {
      expect(const InstructorFilters(rating4: true).matches(newOne), isFalse);
      expect(const InstructorFilters(rating4: true).matches(school), isTrue);
      expect(const InstructorFilters(bookableOnly: true).matches(school), isTrue);
      expect(const InstructorFilters(bookableOnly: true).matches(_listing(kind: 'schoolInstructor')), isFalse);
      expect(const InstructorFilters(dualControls: true).matches(newOne), isFalse);
    });
  });

  group('order', () {
    test('stage first, then rating, a new profile ranked at 4.0, then payouts', () {
      final list = [
        _listing(id: 'stage0', stage: 0, ratingAvg: 5),
        _listing(id: 'low', ratingAvg: 3.5),
        _listing(id: 'new', ratingAvg: 5, ratingCount: 1),
        _listing(id: 'high', ratingAvg: 4.8),
        _listing(id: 'stage1', stage: 1),
      ];
      expect(orderInstructors(list, 7).map((i) => i.id), ['high', 'new', 'low', 'stage1', 'stage0']);
    });

    test('ties are shuffled by the session seed, the same way every time', () {
      final ties = [for (var n = 0; n < 12; n++) _listing(id: 'id$n', ratingCount: 0)];
      final a = orderInstructors(ties, 1).map((i) => i.id).toList();
      expect(orderInstructors(ties.reversed, 1).map((i) => i.id).toList(), a);
      final seeds = {for (var s = 0; s < 5; s++) orderInstructors(ties, s).map((i) => i.id).join()};
      expect(seeds.length, greaterThan(1));
    });
  });

  group('card', () {
    testWidgets('shows price, rating, two languages + N, and saves with the heart', (tester) async {
      var saved = false;
      await _pump(
        tester,
        Scaffold(
          body: InstructorCard(
            instructor: _listing(languages: ['en', 'pl', 'uk']),
            saved: false,
            onTap: () {},
            onToggleSaved: () => saved = true,
          ),
        ),
      );
      expect(find.text('\$65/h'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('English · Polski · +1'), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      expect(saved, isTrue);
    });

    for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
      testWidgets('a hidden price and a new profile read as text ($locale)', (tester) async {
        await _pump(
          tester,
          Scaffold(
            body: InstructorCard(
              instructor: _listing(kind: 'schoolInstructor', priceHidden: true, cents: null, ratingCount: 1),
              saved: true,
              onTap: () {},
              onToggleSaved: () {},
            ),
          ),
          locale: locale,
        );
        final l = (await tester.runAsync(() => AppLocalizations.delegate.load(Locale(locale))))!;
        expect(find.text(l.translate('instructor_price_hidden_short')), findsOneWidget);
        expect(find.text(l.translate('instructor_new')), findsOneWidget);
        expect(find.textContaining('\$'), findsNothing);
      });
    }
  });

  group('detail page', () {
    testWidgets('stage 0 school: amber notice, disabled actions with reasons, hours, reviews', (tester) async {
      final svc = _FakeService(reviews: [
        for (var n = 1; n <= 4; n++) InstructorReview(name: 'Student $n', rating: 5, comment: 'Comment $n'),
      ]);
      await _pump(tester, InstructorDetailScreen(instructor: _listing(stage: 0), uid: 'u1', service: svc));

      expect(find.text('Licence and identity not checked yet'), findsOneWidget);
      expect(find.text('Booking opens once the licence is checked.'), findsOneWidget);
      expect(find.text('Messages open once the ID is checked.'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('09:00–12:00'), findsOneWidget);
      expect(find.text('14:00–18:00'), findsOneWidget);
      expect(find.text('Day off'), findsNWidgets(6));
      expect(find.text('Central Time · Chicago'), findsOneWidget);
      expect(find.text('Comment 3'), findsOneWidget);
      expect(find.text('Comment 4'), findsNothing);
      await tester.tap(find.text('All reviews'));
      await tester.pumpAndSettle();
      expect(find.text('Comment 4'), findsOneWidget);
    });

    testWidgets('a private instructor gets no booking button', (tester) async {
      await _pump(
        tester,
        InstructorDetailScreen(instructor: _listing(kind: 'schoolInstructor', stage: 1), uid: 'u1', service: _FakeService(kind: 'schoolInstructor')),
      );
      expect(find.text('Book'), findsNothing);
      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('the heart saves to favourites', (tester) async {
      final svc = _FakeService();
      await _pump(tester, InstructorDetailScreen(instructor: _listing(), uid: 'u1', service: svc));
      // The app bar: back, report, heart — the heart is the last disc.
      await tester.tap(find.byType(IconButton).last);
      expect(svc.saves, [('i1', true)]);
    });

    testWidgets('an instructor unlisted since the list loaded shows «not available»', (tester) async {
      await _pump(
        tester,
        InstructorDetailScreen(
          instructor: _listing(),
          uid: 'u1',
          service: _FakeService(detailError: FirebaseFunctionsException(message: 'gone', code: 'not-found')),
        ),
      );
      expect(find.text('Profile not available'), findsOneWidget);
      expect(find.text('Book'), findsNothing);
    });
  });

  testWidgets('the report sheet offers the profile reasons', (tester) async {
    await _pump(
      tester,
      const Scaffold(
        body: ReportSheet(contentType: 'instructor', contextData: {'instructorUid': 'i1', 'language': 'en', 'state': 'IL'}),
      ),
    );
    for (final label in ['Report this profile', 'Fake profile', 'Harassment', 'Inappropriate content', 'Spam or scam']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Issue with image'), findsNothing);
  });
}
