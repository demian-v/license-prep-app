import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  InstructorService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestoreOverride = firestore,
        _functions = functions;

  // Resolved on first use, so a test fake that overrides the calls never
  // touches Firebase.
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _fns => _functions ?? FirebaseFunctions.instance;

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

  /// The instructor's own public profile (owner-readable in firestore.rules).
  Stream<Map<String, dynamic>?> ownProfile(String uid) =>
      _firestore.collection('instructors').doc(uid).snapshots().map((s) => s.data());

  /// «Показывать в поиске»: the owner may flip active <-> deactivated
  /// (firestore.rules); the server recomputes `listed`.
  Future<void> setVisible(String uid, bool visible) => _firestore
      .collection('instructors')
      .doc(uid)
      .update({'status': visible ? 'active' : 'deactivated', 'updatedAt': FieldValue.serverTimestamp()});

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
