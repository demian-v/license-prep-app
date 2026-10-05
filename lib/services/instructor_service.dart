import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/instructor_listing.dart';

/// What the Инструкторы tab needs before it can show anything: whether the
/// student's state has launched (`config/instructors.launchStates`, set from
/// the console — plan v2 §14.4) and how many listings it holds
/// (`instructorStats/{state}`, public so the locked preview can show a real
/// number without exposing instructor data).
class InstructorTabInfo {
  const InstructorTabInfo({required this.launched, required this.listedCount});

  final bool launched;
  final int listedCount;
}

class InstructorService {
  InstructorService({FirebaseFirestore? firestore, FirebaseFunctions? functions, FirebaseStorage? storage})
      : _firestoreOverride = firestore,
        _functions = functions,
        _storageOverride = storage;

  // Resolved on first use, so a test fake that overrides the calls never
  // touches Firebase.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functions;
  final FirebaseStorage? _storageOverride;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _fns => _functions ?? FirebaseFunctions.instance;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Who is signing up, after the email code (functions/src/instructors.ts).
  /// Set once on the server; the same answer again is accepted.
  Future<void> setSignupRole(String role, String? kind) async {
    await _fns.httpsCallable('setSignupRole').call({
      'signupRole': role,
      if (kind != null) 'signupKind': kind,
    });
  }

  /// The end of the instructor wizard (functions/src/instructors.ts). The
  /// server validates every field again and grants the role; returns the
  /// teaching state it saved.
  Future<String> register(Map<String, dynamic> profile) async {
    final result = await _fns.httpsCallable('registerAsInstructor').call(profile);
    return (result.data as Map)['state'] as String;
  }

  /// Adds or changes the licence numbers from Профиль (verification can come
  /// after signup — owner, 2026-09-30).
  Future<void> submitLicenseNumber({required String school, String? instructor}) async {
    await _fns.httpsCallable('submitLicenseNumber').call({
      'schoolLicenseNumber': school,
      if (instructor != null && instructor.isNotEmpty) 'instructorLicenseNumber': instructor,
    });
  }

  /// One Профиль section — `bio`, `school`, `price`, `car` or `contacts` —
  /// through updateInstructorProfile, which checks it the way
  /// registerAsInstructor does (functions/src/instructors.ts).
  Future<void> updateProfile(String section, Map<String, dynamic> fields) async {
    await _fns.httpsCallable('updateInstructorProfile').call({'section': section, ...fields});
  }

  /// The owner's phone and contact email: they live in instructorPrivate,
  /// which no client reads, so they come from a callable.
  Future<({String phone, String email})> contacts() async {
    final result = await _fns.httpsCallable('getInstructorContacts').call();
    final data = result.data as Map;
    return (phone: data['phone'] as String? ?? '', email: data['contactEmail'] as String? ?? '');
  }

  /// A profile photo from the gallery, resized on the device to about
  /// 1024 px, JPEG 85 (plan v2 §8). Null when the instructor cancels.
  Future<XFile?> pickPhoto() => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );

  /// Uploads to the private pending path under a new name; onInstructorUpload
  /// (functions/src/instructors.ts) checks it and sets `photoPath` itself.
  Future<void> uploadPhoto(String uid, XFile photo) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32).toRadixString(16)}';
    await _storage
        .ref('instructorUploads/$uid/photo/$id.jpg')
        .putData(await photo.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
  }

  /// A download URL for an approved photo's Storage path (storage.rules).
  Future<String> photoUrl(String path) => _storage.ref(path).getDownloadURL();

  /// The instructor's own public profile (owner-readable in firestore.rules).
  Stream<Map<String, dynamic>?> ownProfile(String uid) =>
      _firestore.collection('instructors').doc(uid).snapshots().map((s) => s.data());

  /// «Показывать в поиске»: the owner may flip active <-> deactivated
  /// (firestore.rules); the server recomputes `listed`.
  Future<void> setVisible(String uid, bool visible) => _firestore
      .collection('instructors')
      .doc(uid)
      .update({'status': visible ? 'active' : 'deactivated', 'updatedAt': FieldValue.serverTimestamp()});

  /// One fetch of the state's listing per app session (plan v2 §13): the
  /// student tabs are rebuilt on every switch, so the answer is kept here,
  /// not in the screen. Pull-to-refresh passes [refresh]; a failure is not
  /// kept.
  static final Map<String, Future<List<InstructorListing>>> _listings = {};

  Future<List<InstructorListing>> listings(String state, {bool refresh = false}) {
    if (refresh) _listings.remove(state);
    return _listings.putIfAbsent(state, () async {
      try {
        final result = await _fns.httpsCallable('listInstructors').call({'state': state});
        final list = (result.data as Map)['instructors'] as List? ?? const [];
        return [for (final m in list) InstructorListing.fromMap(m as Map)];
      } catch (_) {
        _listings.remove(state);
        rethrow;
      }
    });
  }

  /// The detail page: the listing plus the weekly hours. `not-found` when
  /// the profile was unlisted or deleted since the list was loaded.
  Future<InstructorListing> detail(String id) async {
    final result = await _fns.httpsCallable('getInstructorProfile').call({'id': id});
    return InstructorListing.fromMap(result.data as Map);
  }

  /// The newest reviews (up to 50), with no reviewer uid.
  Future<List<InstructorReview>> reviews(String id) async {
    final result = await _fns.httpsCallable('getInstructorReviews').call({'id': id});
    final list = (result.data as Map)['reviews'] as List? ?? const [];
    return [for (final m in list) InstructorReview.fromMap(m as Map)];
  }

  /// The student's saved instructors, `favorites/{uid}` (owner-only in
  /// firestore.rules, at most 200). Missing doc = none saved yet.
  Stream<Set<String>> favorites(String uid) => _firestore.collection('favorites').doc(uid).snapshots().map(
      (s) => {for (final id in (s.data()?['instructorUids'] as List? ?? const [])) '$id'});

  /// Saves or removes one; the doc is created on the first save.
  Future<void> setFavorite(String uid, String instructorId, bool saved) =>
      _firestore.collection('favorites').doc(uid).set({
        'instructorUids': saved ? FieldValue.arrayUnion([instructorId]) : FieldValue.arrayRemove([instructorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<InstructorTabInfo> tabInfo(String state) async {
    final results = await Future.wait([
      _firestore.collection('config').doc('instructors').get(),
      _firestore.collection('instructorStats').doc(state).get(),
    ]);
    final launchStates = results[0].data()?['launchStates'];
    final count = results[1].data()?['listedCount'];
    return InstructorTabInfo(
      launched: launchStates is List && launchStates.contains(state),
      listedCount: count is int ? count : 0,
    );
  }
}
