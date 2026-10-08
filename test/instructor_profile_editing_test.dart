import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/models/instructor_listing.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/services/review_service.dart';
import 'package:license_prep_app/widgets/instructor_profile_section.dart';

/// Instructors P3b — editing the profile from Профиль: one row per section,
/// each opens a sheet that checks its fields and saves only that section
/// through updateInstructorProfile. A school has no School row (its name is
/// the profile name); a suspended profile is frozen.
class _FakeService extends InstructorService {
  _FakeService(this.profile);

  final Map<String, dynamic> profile;
  final saved = <(String, Map<String, dynamic>)>[];

  @override
  Stream<Map<String, dynamic>?> ownProfile(String uid) => Stream.value(profile);

  @override
  Future<void> updateProfile(String section, Map<String, dynamic> fields) async => saved.add((section, fields));

  @override
  Future<({String phone, String email})> contacts() async => (phone: '+1 312 555 0100', email: 'me@example.com');

  // The photo card is tapped by the all-rows test; cancel the picker.
  @override
  Future<XFile?> pickPhoto() async => null;
}

Map<String, dynamic> _doc({String kind = 'school', String status = 'active', String bio = '', String? schoolName}) => {
      'kind': kind,
      'status': status,
      'stage': 0,
      'licenseCheck': 'none',
      'idCheck': 'none',
      'bio': bio,
      'schoolName': schoolName ?? (kind == 'school' ? 'Lakeview Driving School' : null),
      'hourlyRateCents': 4500,
      'lessonDurations': [90, 60],
      'carModel': 'Toyota Corolla',
      'carYear': 2022,
      'hasDualControls': true,
    };

Future<void> _pump(WidgetTester tester, _FakeService svc, {String locale = 'en'}) async {
  await tester.binding.setSurfaceSize(const Size(402, 1600));
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
      home: Scaffold(body: SingleChildScrollView(child: InstructorProfileSection(uid: 'u1', service: svc, reviews: _NoReviews()))),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

/// The one saved call as [section, fields], for deep equality.
List<Object> _last(_FakeService svc) => [svc.saved.single.$1, svc.saved.single.$2];

Future<void> _openRow(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a school edits description, price, car and contacts — no School row', (tester) async {
    await _pump(tester, _FakeService(_doc()));
    expect(find.text('Profile for students'), findsOneWidget);
    for (final row in ['Description', 'Price', 'Car', 'Contacts']) {
      expect(find.text(row), findsOneWidget);
    }
    expect(find.text('Driving school'), findsNothing);
    expect(find.text('\$45 per hour · 60, 90 min'), findsOneWidget);
    expect(find.text('Toyota Corolla, 2022'), findsOneWidget);
  });

  testWidgets('a private instructor also names their school (optional)', (tester) async {
    final svc = _FakeService(_doc(kind: 'schoolInstructor'));
    await _pump(tester, svc);
    await _openRow(tester, 'Driving school');
    expect(find.text('Optional. Leave it empty if you teach on your own.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Northside Driving School');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_last(svc), ['school', {'schoolName': 'Northside Driving School'}]);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the description stops at 600 characters and saves trimmed', (tester) async {
    final svc = _FakeService(_doc());
    await _pump(tester, svc);
    await _openRow(tester, 'Description');
    await tester.enterText(find.byType(TextField), '  ${'x' * 700}');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final (section, fields) = svc.saved.single;
    expect(section, 'bio');
    expect((fields['bio'] as String).length, lessThanOrEqualTo(600));
  });

  testWidgets('the price sheet refuses a rate out of range and saves cents', (tester) async {
    final svc = _FakeService(_doc());
    await _pump(tester, svc);
    await _openRow(tester, 'Price');
    await tester.enterText(find.byType(TextField), '15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a price from \$20 to \$200.'), findsOneWidget);
    expect(svc.saved, isEmpty);

    await tester.enterText(find.byType(TextField), '80');
    await tester.tap(find.text('120 min'));
    await tester.tap(find.text('90 min'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_last(svc), ['price', {'hourlyRateCents': 8000, 'lessonDurations': [60, 120]}]);
  });

  testWidgets("a private instructor's price sheet says it is hidden until the licence check", (tester) async {
    await _pump(tester, _FakeService(_doc(kind: 'schoolInstructor')));
    await _openRow(tester, 'Price');
    expect(find.text('Students see your price once your licence is checked.'), findsWidgets);
  });

  testWidgets('the car sheet checks the year', (tester) async {
    final svc = _FakeService(_doc());
    await _pump(tester, svc);
    await _openRow(tester, 'Car');
    await tester.enterText(find.byType(TextField).at(1), '1990');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a year from 1995.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '2021');
    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_last(svc), ['car', {'carModel': 'Toyota Corolla', 'carYear': 2021, 'hasDualControls': false}]);
  });

  testWidgets('the contacts sheet loads the private contacts, then saves them', (tester) async {
    final svc = _FakeService(_doc());
    await _pump(tester, svc);
    await _openRow(tester, 'Contacts');
    expect(find.text('+1 312 555 0100'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'school@example.com');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_last(svc), ['contacts', {'phone': '+1 312 555 0100', 'contactEmail': 'school@example.com'}]);
  });

  testWidgets('a suspended profile opens no edit sheet', (tester) async {
    final svc = _FakeService(_doc(status: 'suspended'));
    await _pump(tester, svc);
    await tester.tap(find.text('Description'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
    testWidgets('every row and sheet is translated in $locale', (tester) async {
      await _pump(tester, _FakeService(_doc(kind: 'schoolInstructor', bio: 'Hi')), locale: locale);
      bool raw(String t) => t.contains('{') || RegExp(r'^(iprof|ireg|status)_').hasMatch(t);
      List<String> texts() => tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      expect(texts().where(raw), isEmpty);
      // Every row opens a sheet with no raw key either.
      final rows = find.descendant(of: find.byType(InstructorProfileSection), matching: find.byType(InkWell));
      final count = rows.evaluate().length;
      for (var i = 0; i < count; i++) {
        await tester.tap(rows.at(i));
        await tester.pumpAndSettle();
        expect(texts().where(raw), isEmpty);
        if (find.byType(BottomSheet).evaluate().isNotEmpty) {
          Navigator.of(tester.element(find.byType(BottomSheet))).pop();
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}

/// «Мои отзывы» (P8) sits in the same section; no reviews here.
class _NoReviews extends ReviewService {
  @override
  Stream<List<InstructorReview>> reviewsOf(String instructorUid) => Stream.value(const []);
}
