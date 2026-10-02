import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/screens/instructor_calendar_screen.dart';
import 'package:license_prep_app/services/instructor_service.dart';

/// Instructors P3b — the weekly hours on Календарь (plan v2 §14.2): half
/// hours from 06:00 to 22:00, tap to open one, hold-and-drag to mark a range,
/// saved as merged intervals through updateInstructorProfile.
class _FakeService extends InstructorService {
  _FakeService(this.doc);

  Map<String, dynamic> doc;
  final saved = <Map<String, dynamic>>[];
  bool fail = false;

  @override
  Stream<Map<String, dynamic>?> ownProfile(String uid) => Stream.value(doc);

  @override
  Future<void> updateProfile(String section, Map<String, dynamic> fields) async {
    expect(section, 'availability');
    if (fail) throw Exception('network');
    saved.add(fields['availability'] as Map<String, dynamic>);
  }
}

Map<String, dynamic> _doc({Map<String, dynamic>? availability, String status = 'active'}) => {
      'status': status,
      'timezone': 'America/Chicago',
      'availability': availability ?? {},
    };

Future<void> _pump(WidgetTester tester, _FakeService svc, {String locale = 'en'}) async {
  await tester.binding.setSurfaceSize(const Size(402, 1400));
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
      home: InstructorCalendarScreen(service: svc, uid: 'u1'),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

Finder _cell(String label) => find.bySemanticsLabel(label);

void main() {
  group('cells ⇄ intervals', () {
    test('round-trips and merges touching half hours', () {
      final cells = InstructorCalendarScreen.cellsFrom({
        'mon': [
          {'start': '09:00', 'end': '10:00'},
          {'start': '10:00', 'end': '11:30'},
        ],
        'sat': [
          {'start': '06:00', 'end': '07:00'},
          {'start': '21:30', 'end': '22:00'},
        ],
      });
      expect(InstructorCalendarScreen.availabilityFrom(cells), {
        'mon': [
          {'start': '09:00', 'end': '11:30'},
        ],
        'sat': [
          {'start': '06:00', 'end': '07:00'},
          {'start': '21:30', 'end': '22:00'},
        ],
      });
    });

    test('ignores hours outside 06:00–22:00 and malformed entries', () {
      final cells = InstructorCalendarScreen.cellsFrom({
        'mon': [
          {'start': '05:00', 'end': '06:30'},
          {'start': 'x', 'end': '10:00'},
        ],
        'holiday': [
          {'start': '09:00', 'end': '10:00'},
        ],
        'tue': 'nope',
      });
      expect(InstructorCalendarScreen.availabilityFrom(cells), {
        'mon': [
          {'start': '06:00', 'end': '06:30'},
        ],
      });
    });
  });

  testWidgets('shows the saved hours and the time zone', (tester) async {
    await _pump(
        tester,
        _FakeService(_doc(availability: {
          'mon': [
            {'start': '09:00', 'end': '10:00'},
          ],
        })));
    expect(find.text('Working hours'), findsOneWidget);
    expect(find.text('Times are in your time zone: America/Chicago'), findsOneWidget);
    expect(tester.getSemantics(_cell('Mon 09:00')).flagsCollection.isToggled, Tristate.isTrue);
    expect(tester.getSemantics(_cell('Mon 10:00')).flagsCollection.isToggled, Tristate.isFalse);
  });

  testWidgets('a tap opens a half hour; Save sends merged intervals', (tester) async {
    final svc = _FakeService(_doc(availability: {
      'mon': [
        {'start': '09:00', 'end': '10:00'},
      ],
    }));
    await _pump(tester, svc);
    // Nothing changed yet: Save does nothing.
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(svc.saved, isEmpty);

    await tester.tap(_cell('Mon 10:00'));
    await tester.tap(_cell('Wed 18:00'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(svc.saved.single, {
      'mon': [
        {'start': '09:00', 'end': '10:30'},
      ],
      'wed': [
        {'start': '18:00', 'end': '18:30'},
      ],
    });
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('a second tap closes it again', (tester) async {
    final svc = _FakeService(_doc());
    await _pump(tester, svc);
    await tester.tap(_cell('Tue 12:00'));
    await tester.pump();
    await tester.tap(_cell('Tue 12:00'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(svc.saved, isEmpty);
  });

  testWidgets('hold, then drag down a column, opens the whole range', (tester) async {
    final svc = _FakeService(_doc());
    await _pump(tester, svc);
    final start = tester.getCenter(_cell('Thu 08:00'));
    final end = tester.getCenter(_cell('Thu 11:30'));
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(start.dx, (start.dy + end.dy) / 2));
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(svc.saved.single, {
      'thu': [
        {'start': '08:00', 'end': '12:00'},
      ],
    });
  });

  testWidgets('a drag that starts on an open half hour closes the range', (tester) async {
    final svc = _FakeService(_doc(availability: {
      'fri': [
        {'start': '09:00', 'end': '12:00'},
      ],
    }));
    await _pump(tester, svc);
    final start = tester.getCenter(_cell('Fri 10:00'));
    final end = tester.getCenter(_cell('Fri 11:30'));
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(svc.saved.single, {
      'fri': [
        {'start': '09:00', 'end': '10:00'},
      ],
    });
  });

  testWidgets('a failed save says so and keeps the edits', (tester) async {
    final svc = _FakeService(_doc())..fail = true;
    await _pump(tester, svc);
    await tester.tap(_cell('Sun 10:00'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save. Please try again."), findsOneWidget);
    expect(tester.getSemantics(_cell('Sun 10:00')).flagsCollection.isToggled, Tristate.isTrue);
  });

  testWidgets('a suspended profile is read-only', (tester) async {
    final svc = _FakeService(_doc(status: 'suspended'));
    await _pump(tester, svc);
    expect(find.text('Your profile is suspended. Please contact support.'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.tap(_cell('Mon 09:00'));
    await tester.pump();
    expect(tester.getSemantics(_cell('Mon 09:00')).flagsCollection.isToggled, Tristate.isFalse);
  });

  for (final locale in ['en', 'es', 'pl', 'ru', 'uk']) {
    testWidgets('is translated in $locale', (tester) async {
      await _pump(tester, _FakeService(_doc()), locale: locale);
      final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      expect(texts.where((t) => t.contains('{') || RegExp(r'^(ical|day_short|instructor)_').hasMatch(t)), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
