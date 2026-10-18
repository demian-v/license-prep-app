import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/models/booking.dart';
import 'package:license_prep_app/models/instructor_listing.dart';
import 'package:license_prep_app/screens/booking_detail_screen.dart';
import 'package:license_prep_app/screens/booking_screen.dart';
import 'package:license_prep_app/services/booking_service.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/services/payment_sheet.dart';
import 'package:license_prep_app/services/review_service.dart';
import 'package:license_prep_app/widgets/bento_question_parts.dart';
import 'package:license_prep_app/widgets/booking_tile.dart';
import 'package:license_prep_app/widgets/instructor_profile_section.dart';

/// Instructors P9 — Stripe Connect, the app's half. The money itself
/// (PaymentIntent, webhook, refunds, transfers) is tested with a fake Stripe
/// in functions/src/__tests__/payments.test.ts; here: the PaymentSheet's
/// three endings on the booking page, the payout and refund states a lesson
/// shows, «Урок не состоялся», the income tiles and the «Выплаты» card.

const _hour = 3600 * 1000;
final _t0 = DateTime.utc(2026, 10, 7, 15).millisecondsSinceEpoch;

Booking _booking({
  String status = 'completed',
  DateTime? startAt,
  int lessonCents = 6500,
  DateTime? payoutReleaseAt,
  DateTime? payoutReleasedAt,
  DateTime? payoutCancelledAt,
  String? refundStatus,
  String? disputeStatus,
  String? cancelledBy,
}) =>
    Booking(
      id: 'b1',
      studentUid: 's1',
      instructorUid: 'i1',
      studentDisplayName: 'Anna K.',
      instructorName: 'Lakeview Driving School',
      startAt: startAt ?? DateTime.now().subtract(const Duration(hours: 3)),
      durationMinutes: 60,
      localDate: '2026-10-07',
      localTime: '10:00',
      lessonCents: lessonCents,
      platformFeeCents: 325,
      totalCents: lessonCents + 325,
      feeKind: 'later',
      status: status,
      timezone: 'America/Chicago',
      cancelledBy: cancelledBy,
      paymentProvider: 'stripe',
      refundStatus: refundStatus,
      payoutReleaseAt: payoutReleaseAt,
      payoutReleasedAt: payoutReleasedAt,
      payoutCancelledAt: payoutCancelledAt,
      disputeStatus: disputeStatus,
    );

InstructorListing _school() => InstructorListing.fromMap({
      'id': 'i1', 'kind': 'school', 'name': 'Lakeview Driving School', 'city': 'Chicago', 'state': 'IL',
      'languages': ['en'], 'stage': 2, 'ratingAvg': 0, 'ratingCount': 0, 'lessonDurations': [60],
      'hourlyRateCents': 6500, 'priceHidden': false, 'payoutsEnabled': true, 'schoolAddress': '100 Main St',
    });

class _Bookings extends BookingService {
  _Bookings({this.shown, this.error, this.releasedAs = 'expired', this.noShowError});

  final Booking? shown;
  final FirebaseFunctionsException? error;
  /// What releaseBookingHold answers (the server asks Stripe first).
  final String releasedAs;
  final FirebaseFunctionsException? noShowError;
  final released = <String>[];
  final noShows = <String>[];

  @override
  Future<BookingOptions> options(String instructorUid) async => BookingOptions.fromMap({
        'timezone': 'America/Chicago',
        'days': [
          {
            'date': '2026-10-07',
            'slots': [
              {'time': '10:00', 'startAtMs': _t0},
              {'time': '10:30', 'startAtMs': _t0 + _hour ~/ 2},
            ],
          },
        ],
        'quotes': [
          {'durationMinutes': 60, 'lessonCents': 6500, 'platformFeeCents': 1625, 'totalCents': 8125, 'feeKind': 'first'},
        ],
      });

  @override
  Future<({String id, String status, PaymentStart? payment})> create(String instructorUid, int startAtMs, int durationMinutes) async {
    if (error != null) throw error!;
    return (
      id: 'new',
      status: 'pending_payment',
      payment: const PaymentStart(clientSecret: 'pi_new_secret_test', publishableKey: 'pk_test_dummy'),
    );
  }

  @override
  Future<String> releaseHold(String bookingId) async {
    released.add(bookingId);
    return releasedAs;
  }

  @override
  Future<void> reportNoShow(String bookingId) async {
    if (noShowError != null) throw noShowError!;
    noShows.add(bookingId);
  }

  @override
  Stream<Booking?> booking(String id) => Stream.value(shown ?? _booking(status: 'pending_payment'));
}

class _Sheet implements PaymentSheetLauncher {
  _Sheet(this.result);

  final PaymentResult result;
  final seen = <PaymentStart>[];

  @override
  Future<PaymentResult> pay(PaymentStart start) async {
    seen.add(start);
    return result;
  }
}

class _NoReviews extends ReviewService {
  @override
  Stream<InstructorReview?> myReview(String instructorUid, String studentUid) => Stream.value(null);
}

class _Payouts extends InstructorService {
  _Payouts(this.state);

  final String state;
  var started = 0;

  @override
  Future<String> payoutsState() async => state;

  @override
  Future<String> startPayouts() async {
    started++;
    return 'https://connect.stripe.com/setup/e/test_link';
  }
}

Future<void> _pump(WidgetTester tester, Widget home, {String locale = 'en'}) async {
  await tester.binding.setSurfaceSize(const Size(402, 2000));
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

Future<void> _bookTen(WidgetTester tester) async {
  await tester.tap(find.text('10:00'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(find.widgetWithText(BentoActionButton, 'Book'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  group('a lesson’s money', () {
    test('the school’s payout: waiting, paid out, or held by a no-show report or an open dispute', () {
      expect(_booking(status: 'confirmed').payout, isNull);
      expect(_booking(payoutReleaseAt: DateTime(2026, 10, 9)).payout, PayoutState.pending);
      expect(_booking(status: 'payout_released').payout, PayoutState.released);
      expect(_booking(status: 'disputed').payout, PayoutState.held);
      expect(_booking(payoutReleaseAt: DateTime(2026, 10, 9), disputeStatus: 'open').payout, PayoutState.held);
      // A lost dispute stays held (the server never releases it), a won one pays out.
      expect(_booking(payoutReleaseAt: DateTime(2026, 10, 9), disputeStatus: 'lost').payout, PayoutState.held);
      expect(_booking(payoutReleaseAt: DateTime(2026, 10, 9), disputeStatus: 'won').payout, PayoutState.pending);
      // An inquiry closed without a chargeback: the money stayed, so it pays out.
      expect(_booking(payoutReleaseAt: DateTime(2026, 10, 9), disputeStatus: 'warning_closed').payout, PayoutState.pending);
      // The server cancelled the payout after a lost dispute: the school isn't paid.
      expect(_booking(disputeStatus: 'lost', payoutCancelledAt: DateTime(2026, 10, 9)).payout, PayoutState.cancelled);
      expect(_booking(status: 'refunded', cancelledBy: 'student').payout, isNull);
      // A paid-out late cancel stays a late cancel: never «held», never reviewable.
      final late = _booking(status: 'late_cancelled', payoutReleasedAt: DateTime(2026, 10, 9));
      expect(late.payout, PayoutState.released);
      expect(late.reviewable, isFalse);
      expect(late.past(DateTime.now()), isFalse);
      expect(late.cancelled, isTrue);
    });

    test('income adds paid-out and still-to-come lesson prices, never the fee', () {
      final income = incomeOf([
        _booking(status: 'payout_released', lessonCents: 6000),
        _booking(status: 'payout_released', lessonCents: 3000),
        _booking(payoutReleaseAt: DateTime(2026, 10, 9), lessonCents: 6500),
        _booking(status: 'late_cancelled', payoutReleaseAt: DateTime(2026, 10, 9), lessonCents: 1000),
        _booking(status: 'refunded', lessonCents: 9999),
        _booking(disputeStatus: 'lost', payoutCancelledAt: DateTime(2026, 10, 9), lessonCents: 8888),
      ]);
      expect(income, (releasedCents: 9000, pendingCents: 7500));
    });

    test('a no-show can be reported only on a held lesson, until 48 h after its end', () {
      final now = DateTime.now();
      expect(_booking(startAt: now.subtract(const Duration(hours: 3))).noShowReportable(now), isTrue);
      expect(_booking(startAt: now.subtract(const Duration(hours: 50))).noShowReportable(now), isFalse);
      expect(_booking(status: 'confirmed').noShowReportable(now), isFalse);
      expect(_booking(status: 'payout_released').noShowReportable(now), isFalse);
    });

    test('a paid-out or disputed lesson is still listed under past lessons', () {
      final now = DateTime.now();
      for (final s in ['completed', 'payout_released', 'disputed']) {
        expect(_booking(status: s).past(now), isTrue, reason: s);
      }
    });
  });

  group('the PaymentSheet on the booking page', () {
    testWidgets('closed without paying: the hold is released at once and the page says so', (tester) async {
      final svc = _Bookings();
      final sheet = _Sheet(const PaymentResult(PaymentOutcome.cancelled));
      await _pump(tester, BookingScreen(instructor: _school(), service: svc, payments: sheet));
      await _bookTen(tester);
      expect(sheet.seen.single.clientSecret, 'pi_new_secret_test');
      expect(sheet.seen.single.publishableKey, 'pk_test_dummy');
      expect(svc.released, ['new']);
      expect(find.text('Payment cancelled. The time is free again.'), findsOneWidget);
      expect(find.byType(BookingDetailScreen), findsNothing);
    });

    testWidgets('a declined card: Stripe’s reason is shown and the time freed', (tester) async {
      final svc = _Bookings();
      await _pump(tester, BookingScreen(instructor: _school(), service: svc, payments: _Sheet(const PaymentResult(PaymentOutcome.failed, 'Your card was declined.'))));
      await _bookTen(tester);
      expect(svc.released, ['new']);
      expect(find.text("The payment didn't go through. Your card was declined."), findsOneWidget);
    });

    testWidgets('the sheet said «failed» but Stripe says paid: the lesson page opens, no failure shown', (tester) async {
      final svc = _Bookings(releasedAs: 'confirmed');
      await _pump(tester, BookingScreen(instructor: _school(), service: svc, payments: _Sheet(const PaymentResult(PaymentOutcome.failed, 'Timed out.'))));
      await _bookTen(tester);
      expect(svc.released, ['new']);
      expect(find.textContaining("The payment didn't go through"), findsNothing);
      expect(find.byType(BookingDetailScreen), findsOneWidget);
    });

    testWidgets('paid: the lesson page opens and waits for the server to confirm', (tester) async {
      final svc = _Bookings();
      await _pump(tester, BookingScreen(instructor: _school(), service: svc, payments: _Sheet(const PaymentResult(PaymentOutcome.paid))));
      await _bookTen(tester);
      expect(svc.released, isEmpty);
      expect(find.byType(BookingDetailScreen), findsOneWidget);
      expect(find.text('Payment is being processed — the lesson is confirmed in a few seconds.'), findsOneWidget);
    });

    testWidgets('two unpaid holds already: the cap is explained', (tester) async {
      final svc = _Bookings(error: FirebaseFunctionsException(code: 'resource-exhausted', message: 'too-many-holds'));
      await _pump(tester, BookingScreen(instructor: _school(), service: svc, payments: _Sheet(const PaymentResult(PaymentOutcome.paid))));
      await _bookTen(tester);
      expect(find.text('You already have two unpaid bookings. Pay for them or wait 15 minutes.'), findsOneWidget);
    });
  });

  group('the lesson page', () {
    Future<void> open(WidgetTester tester, Booking b, {bool asInstructor = false, _Bookings? svc}) => _pump(
          tester,
          BookingDetailScreen(key: UniqueKey(), bookingId: 'b1', asInstructor: asInstructor, service: svc ?? _Bookings(shown: b), reviews: _NoReviews()),
        );

    testWidgets('a held lesson: «Lesson didn’t happen» confirms, then reports it', (tester) async {
      final svc = _Bookings(shown: _booking());
      await open(tester, _booking(), svc: svc);
      await tester.tap(find.widgetWithText(BentoActionButton, "Didn't happen"));
      await tester.pumpAndSettle();
      expect(find.text('Lesson didn’t happen?'.replaceAll('’', "'")), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Report'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(svc.noShows, ['b1']);
      expect(find.text("Thank you, we'll check."), findsOneWidget);
    });

    testWidgets('reported too late (the 48 h ran out on an open page): says so', (tester) async {
      final svc = _Bookings(shown: _booking(), noShowError: FirebaseFunctionsException(code: 'failed-precondition', message: 'not-reportable'));
      await open(tester, _booking(), svc: svc);
      await tester.tap(find.widgetWithText(BentoActionButton, "Didn't happen"));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Report'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('The 48 hours to report this lesson have passed.'), findsOneWidget);
    });

    testWidgets('no «Lesson didn’t happen» for the school, or once the 48 h are over', (tester) async {
      await open(tester, _booking(), asInstructor: true);
      expect(find.text("Didn't happen"), findsNothing);
      await open(tester, _booking(startAt: DateTime.now().subtract(const Duration(days: 3))));
      expect(find.text("Didn't happen"), findsNothing);
    });

    testWidgets('the school sees where its money stands', (tester) async {
      await open(tester, _booking(status: 'payout_released'), asInstructor: true);
      expect(find.text('Paid out'), findsOneWidget);
      await open(tester, _booking(status: 'disputed'), asInstructor: true);
      expect(find.text('Payout on hold'), findsOneWidget);
      expect(find.text("The student reported that the lesson didn't happen. The payout is on hold until we check."), findsOneWidget);
      await open(tester, _booking(payoutReleaseAt: DateTime(2026, 10, 9, 15)), asInstructor: true);
      expect(find.text('Payout after Oct 9'), findsOneWidget);
      await open(tester, _booking(disputeStatus: 'lost', payoutCancelledAt: DateTime(2026, 10, 9)), asInstructor: true);
      expect(find.text('No payout'), findsOneWidget);
      expect(find.text("The student's bank returned the payment (a card dispute), so this lesson isn't paid out."), findsOneWidget);
    });

    testWidgets('the student sees the refund; a payment that came too late explains itself', (tester) async {
      final ahead = DateTime.now().add(const Duration(days: 3));
      await open(tester, _booking(status: 'refunded', cancelledBy: 'student', refundStatus: 'succeeded', startAt: ahead));
      expect(find.text('Refund issued: the money returns to your card within 5–10 days.'), findsOneWidget);
      await open(tester, _booking(status: 'refunded', cancelledBy: 'system', refundStatus: 'failed', startAt: ahead));
      // Says nothing about the money: the refund line below says where it stands.
      expect(find.text('The time was taken while the payment went through, so the lesson was cancelled.'), findsOneWidget);
      expect(find.text('The refund is being issued.'), findsOneWidget);
    });
  });

  group('«Past lessons and income» on Календарь', () {
    testWidgets('paid out and awaiting payout above the school’s past lessons', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: bookingSections(
                context,
                [
                  _booking(status: 'payout_released', lessonCents: 6000),
                  _booking(payoutReleaseAt: DateTime(2026, 10, 9), lessonCents: 6500),
                ],
                asInstructor: true,
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Past lessons and income'), findsOneWidget);
      expect(find.byType(IncomeSummary), findsOneWidget);
      expect(find.text(r'$60'), findsOneWidget);
      expect(find.text(r'$65'), findsOneWidget);
    });

    testWidgets('the student’s «My lessons» has no income', (tester) async {
      await _pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: bookingSections(context, [_booking(status: 'payout_released')], asInstructor: false, onOpen: (_) {}),
            ),
          ),
        ),
      );
      expect(find.text('Past'), findsOneWidget);
      expect(find.byType(IncomeSummary), findsNothing);
    });
  });

  group('«Payouts» in the school’s Профиль', () {
    Future<void> card(WidgetTester tester, {required bool enabled, required _Payouts svc, List<Uri>? opened}) => _pump(
          tester,
          Scaffold(
            body: PayoutsCard(enabled: enabled, service: svc, openUrl: (u) async {
              opened?.add(u);
              return true;
            }),
          ),
        );

    testWidgets('not started: «Set up payouts» opens Stripe’s onboarding link', (tester) async {
      final svc = _Payouts('none');
      final opened = <Uri>[];
      await card(tester, enabled: false, svc: svc, opened: opened);
      expect(find.text('Connect Stripe so students can pay for lessons. Money arrives weekly.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Set up payouts'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(svc.started, 1);
      expect(opened.single.host, 'connect.stripe.com');
      expect(find.text('Continue setup'), findsOneWidget);
    });

    testWidgets('no browser could open the link: an error, and the card stays as it was', (tester) async {
      await _pump(tester, Scaffold(body: PayoutsCard(enabled: false, service: _Payouts('none'), openUrl: (u) async => false)));
      await tester.runAsync(() async {
        await tester.tap(find.text('Set up payouts'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text("Couldn't open Stripe. Try again."), findsOneWidget);
      expect(find.text('Set up payouts'), findsOneWidget);
    });

    testWidgets('Stripe turns payouts off while the page is open: the card re-reads the account', (tester) async {
      final svc = _Payouts('pending');
      final enabled = ValueNotifier(true);
      await _pump(tester, Scaffold(body: ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (_, on, __) => PayoutsCard(enabled: on, service: svc),
      )));
      expect(find.byType(BentoActionButton), findsNothing);
      await tester.runAsync(() async {
        enabled.value = false;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('Continue setup'), findsOneWidget);
    });

    testWidgets('started but not finished: «Continue setup»', (tester) async {
      await card(tester, enabled: false, svc: _Payouts('pending'));
      expect(find.text('Stripe is still checking your details or needs something more.'), findsOneWidget);
      expect(find.text('Continue setup'), findsOneWidget);
    });

    testWidgets('connected: no button', (tester) async {
      await card(tester, enabled: true, svc: _Payouts('enabled'));
      expect(find.text('Connected. Money for each lesson arrives weekly, 48 hours after the lesson.'), findsOneWidget);
      expect(find.byType(BentoActionButton), findsNothing);
    });

    for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
      testWidgets('the card is translated in $lang', (tester) async {
        await _pump(tester, Scaffold(body: PayoutsCard(enabled: false, service: _Payouts('none'))), locale: lang);
        expect(find.text(_locale(lang)['payouts_title'] as String), findsOneWidget);
        expect(find.text(_locale(lang)['payouts_start'] as String), findsOneWidget);
      });
    }

    test('only a driving school gets the card', () {
      final section = File('lib/widgets/instructor_profile_section.dart').readAsStringSync();
      expect(section, contains('if (isSchool) ...['));
      expect(section, contains('PayoutsCard(enabled: p[\'payoutsEnabled\'] == true, service: svc)'));
    });
  });

  group('where the code routes', () {
    String code(String path) => File(path).readAsStringSync();

    test('Android hosts the PaymentSheet: FlutterFragmentActivity and AppCompat themes', () {
      expect(code('android/app/src/main/kotlin/com/driveusa/app/MainActivity.kt'), contains('class MainActivity: FlutterFragmentActivity()'));
      for (final f in ['values', 'values-night']) {
        final styles = code('android/app/src/main/res/$f/styles.xml');
        expect(styles, isNot(contains('@android:style/Theme.')), reason: f);
        expect(RegExp('Theme\\.AppCompat').allMatches(styles).length, 2, reason: f);
      }
      expect(code('android/app/proguard-rules.pro'), contains('-keep class com.stripe.** { *; }'));
    });

    test('a bank page outside the sheet returns to the app: the return URL uses the app’s registered scheme', () {
      expect(StripePaymentSheet.returnUrl, startsWith('driveusa://'));
      expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('<string>driveusa</string>'));
    });

    test('no Stripe key is built into the app', () {
      final hits = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => RegExp(r'(pk|sk|rk)_(test|live)_[A-Za-z0-9]').hasMatch(f.readAsStringSync()))
          .map((f) => f.path)
          .toList();
      expect(hits, isEmpty);
    });

    test('a refused deletion explains open payments too', () {
      final screen = code('lib/screens/personal_info_screen.dart');
      expect(screen, contains("refusal?.message == 'unsettled-bookings'"));
      expect(screen, contains("'delete_unsettled_bookings'"));
    });

    test('the status and payout keys chosen at runtime exist in every language', () {
      for (final lang in ['en', 'es', 'uk', 'ru', 'pl']) {
        for (final k in [
          'booking_status_disputed', 'payout_released', 'payout_held', 'payout_pending_on', 'income_pending',
          'payouts_desc_none', 'payouts_desc_pending', 'payouts_desc_enabled', 'booking_refund_done', 'booking_refund_pending',
          'booking_note_slot_taken', 'booking_note_pending', 'booking_note_disputed_student', 'booking_note_disputed_school',
          'payout_cancelled', 'booking_note_payout_cancelled', 'noshow_too_late',
        ]) {
          expect(_locale(lang)[k], isA<String>(), reason: '$lang $k');
        }
      }
    });
  });
}
