import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:license_prep_app/localization/app_localizations.dart';
import 'package:license_prep_app/services/instructor_service.dart';
import 'package:license_prep_app/widgets/instructor_profile_section.dart';

/// Instructors P3b — «Фото профиля» (plan v2 §8): the photo goes to the
/// private pending path, and what the card says follows the server's
/// `photoStatus`. The instructor keeps seeing what they picked while it waits.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

class _FakeService extends InstructorService {
  _FakeService(Map<String, dynamic> doc) {
    docs.add(doc);
  }

  final docs = StreamController<Map<String, dynamic>?>.broadcast();
  late Map<String, dynamic> last;
  XFile? picked = XFile.fromData(_png, mimeType: 'image/jpeg');
  Completer<void>? uploadGate;
  bool failUpload = false;
  final uploads = <String>[];
  int picks = 0;
  int urlLookups = 0;

  @override
  Stream<Map<String, dynamic>?> ownProfile(String uid) async* {
    yield last;
    yield* docs.stream;
  }

  void push(Map<String, dynamic> doc) {
    last = doc;
    docs.add(doc);
  }

  @override
  Future<XFile?> pickPhoto() async {
    picks++;
    return picked;
  }

  @override
  Future<void> uploadPhoto(String uid, XFile photo) async {
    uploads.add(uid);
    if (uploadGate != null) await uploadGate!.future;
    if (failUpload) throw Exception('network');
  }

  // Never resolves: the card shows the placeholder, and no network is used.
  @override
  Future<String> photoUrl(String path) {
    urlLookups++;
    return Completer<String>().future;
  }
}

Map<String, dynamic> _doc({String photoStatus = 'none', String? photoPath, String status = 'active'}) => {
      'kind': 'school',
      'status': status,
      'stage': 0,
      'licenseCheck': 'none',
      'idCheck': 'none',
      'photoStatus': photoStatus,
      'photoPath': photoPath,
      'hourlyRateCents': 6000,
      'lessonDurations': [60],
    };

_FakeService _svc(Map<String, dynamic> doc) => _FakeService(doc)..last = doc;

Future<void> _pump(WidgetTester tester, _FakeService svc) async {
  await tester.binding.setSurfaceSize(const Size(402, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: InstructorProfileSection(uid: 'u1', service: svc))),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no photo yet: the card asks for one', (tester) async {
    await _pump(tester, _svc(_doc()));
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Add a photo so students recognise you.'), findsOneWidget);
    expect(find.text('Add'), findsWidgets);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a picked photo uploads, shows at once, and waits for review', (tester) async {
    final svc = _svc(_doc())..uploadGate = Completer<void>();
    await _pump(tester, svc);
    await tester.tap(find.text('Profile photo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(svc.uploads, ['u1']);
    expect(find.text('Uploading…'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    svc.uploadGate!.complete();
    // The server marks it pending (production, before moderation exists).
    await tester.runAsync(() async {
      svc.push(_doc(photoStatus: 'pending'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.text("Under review. Students see it once it's checked."), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
  });

  testWidgets('an approved photo is looked up once, not on every rebuild', (tester) async {
    final svc = _svc(_doc(photoStatus: 'approved', photoPath: 'instructorPhotos/u1/a.jpg'));
    await _pump(tester, svc);
    expect(find.text('Students see this photo.'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await tester.runAsync(() async {
      svc.push(_doc(photoStatus: 'approved', photoPath: 'instructorPhotos/u1/a.jpg'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(svc.urlLookups, 1);
  });

  testWidgets('a failed upload says so', (tester) async {
    final svc = _svc(_doc())..failUpload = true;
    await _pump(tester, svc);
    await tester.tap(find.text('Profile photo'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't upload the photo. Please try again."), findsOneWidget);
  });

  testWidgets('a cancelled pick uploads nothing', (tester) async {
    final svc = _svc(_doc())..picked = null;
    await _pump(tester, svc);
    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    expect(svc.picks, 1);
    expect(svc.uploads, isEmpty);
  });

  testWidgets('a rejected photo asks for another', (tester) async {
    await _pump(tester, _svc(_doc(photoStatus: 'rejected')));
    expect(find.text("This photo wasn't accepted. Please choose another."), findsOneWidget);
  });

  testWidgets('a suspended profile cannot change its photo', (tester) async {
    final svc = _svc(_doc(status: 'suspended'));
    await _pump(tester, svc);
    await tester.tap(find.text('Profile photo'));
    await tester.pumpAndSettle();
    expect(svc.picks, 0);
  });
}
