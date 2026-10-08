import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/issue_report.dart';
import 'counter_service.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CounterService _counterService;

  ReportService({CounterService? counterService}) 
    : _counterService = counterService ?? CounterService();

  Future<void> submitQuizReport({
    required String questionId,
    required String reason,
    String? message,
    required String language,
    required String state,
    String? topicId,
    String? ruleReference,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated to submit a report');
    }

    final report = IssueReport(
      reason: reason,
      contentType: 'quiz_question',
      entity: {
        'questionId': questionId,
        'topicId': topicId,
        'ruleReference': ruleReference,
        'path': 'quizQuestions/$questionId',
      },
      message: message,
      userId: user.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    try {
      // Generate custom user-specific report ID
      final reportId = await _counterService.getNextReportId();
      
      // Use custom ID with .doc().set() instead of .add()
      await _db.collection('reports').doc(reportId).set(report.toMap());
    } catch (e) {
      // Risk #45 — this used to be `.add()`, which mints a Firestore auto-ID.
      // No security rule pattern matches an auto-ID, so the write was denied
      // and the report vanished. Use an ID the rules accept instead.
      print('ReportService: Counter unavailable, using fallback report ID: $e');
      await _db.collection('reports')
          .doc(_counterService.generateFallbackReportId(user.uid))
          .set(report.toMap());
    }
  }

  Future<void> submitTheoryReport({
    required String topicDocId,
    required int sectionIndex,
    required String sectionTitle,
    required String reason,
    String? message,
    required String language,
    required String state,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated to submit a report');
    }

    final report = IssueReport(
      reason: reason,
      contentType: 'theory_section',
      entity: {
        'topicDocId': topicDocId,
        'sectionIndex': sectionIndex,
        'sectionTitle': sectionTitle,
        'path': 'trafficRuleTopics/$topicDocId#sections[$sectionIndex]',
      },
      message: message,
      userId: user.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    try {
      // Generate custom user-specific report ID
      final reportId = await _counterService.getNextReportId();
      
      // Use custom ID with .doc().set() instead of .add()
      await _db.collection('reports').doc(reportId).set(report.toMap());
    } catch (e) {
      // Risk #45 — this used to be `.add()`, which mints a Firestore auto-ID.
      // No security rule pattern matches an auto-ID, so the write was denied
      // and the report vanished. Use an ID the rules accept instead.
      print('ReportService: Counter unavailable, using fallback report ID: $e');
      await _db.collection('reports')
          .doc(_counterService.generateFallbackReportId(user.uid))
          .set(report.toMap());
    }
  }

  /// Get all reports for the current authenticated user
  Future<List<QueryDocumentSnapshot>> getCurrentUserReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to fetch reports');
    }
    
    return await _counterService.getUserReports(user.uid);
  }

  /// Get current report counter for the authenticated user
  Future<int> getCurrentUserReportCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 0;
    }
    
    return await _counterService.getCurrentCounterValue(user.uid);
  }

  Future<void> submitSupportReport({
    required String message,
    required String language,
    required String state,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated to submit a support request');
    }

    final report = IssueReport(
      reason: 'other',
      contentType: 'profile_section',
      entity: {
        'source': 'support_page',
        'path': 'profile/support',
      },
      message: message,
      userId: user.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    try {
      final reportId = await _counterService.getNextReportId();
      await _db.collection('reports').doc(reportId).set(report.toMap());
    } catch (e) {
      // Risk #45 — see the note above: an auto-ID is denied by the rules.
      print('ReportService: Counter unavailable, using fallback report ID: $e');
      await _db.collection('reports')
          .doc(_counterService.generateFallbackReportId(user.uid))
          .set(report.toMap());
    }
  }

  /// A student reports an instructor profile from its detail page (plan v2
  /// §7). Reasons: fake_profile, harassment, inappropriate, spam, other.
  Future<void> submitInstructorReport({
    required String instructorUid,
    required String reason,
    String? message,
    required String language,
    required String state,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated to submit a report');
    }

    final report = IssueReport(
      reason: reason,
      contentType: 'instructor',
      // Only the uid: firestore.rules allows no other entity key here.
      entity: {'instructorUid': instructorUid},
      message: message,
      userId: user.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    try {
      final reportId = await _counterService.getNextReportId();
      await _db.collection('reports').doc(reportId).set(report.toMap());
    } catch (e) {
      // Risk #45 — see the note above: an auto-ID is denied by the rules.
      debugPrint('ReportService: Counter unavailable, using fallback report ID: $e');
      await _db.collection('reports')
          .doc(_counterService.generateFallbackReportId(user.uid))
          .set(report.toMap());
    }
  }

  /// A participant reports the other side's chat message (plan v2 §10).
  /// firestore.rules checks the reporter is in the conversation and the
  /// message is not their own. Reasons: harassment, inappropriate, spam, other.
  Future<void> submitMessageReport({
    required String conversationId,
    required String messageId,
    required String reason,
    String? message,
    required String language,
    required String state,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated to submit a report');
    }

    final report = IssueReport(
      reason: reason,
      contentType: 'message',
      // Only these two keys: firestore.rules allows no other entity key here.
      entity: {'conversationId': conversationId, 'messageId': messageId},
      message: message,
      userId: user.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    try {
      final reportId = await _counterService.getNextReportId();
      await _db.collection('reports').doc(reportId).set(report.toMap());
    } catch (e) {
      // Risk #45: an auto-ID is denied by the rules.
      debugPrint('ReportService: Counter unavailable, using fallback report ID: $e');
      await _db.collection('reports')
          .doc(_counterService.generateFallbackReportId(user.uid))
          .set(report.toMap());
    }
  }

  /// A paid student, or the instructor it is about, reports a review (plan
  /// v2 §7, P8). Not a direct write: the review is named by its opaque id,
  /// which only the reportReview callable can resolve — the doc id is the
  /// author's uid, and it never reaches other users. Reasons: harassment,
  /// inappropriate, spam, other.
  Future<void> submitReviewReport({
    required String instructorUid,
    required String reviewId,
    required String reason,
    String? message,
    required String language,
    required String state,
  }) async {
    final pkg = await PackageInfo.fromPlatform();
    await FirebaseFunctions.instance.httpsCallable('reportReview').call({
      'instructorUid': instructorUid,
      'reviewId': reviewId,
      'reason': reason,
      if (message != null) 'message': message,
      'language': language,
      'state': state,
      'appVersion': pkg.version,
      'buildNumber': pkg.buildNumber,
      'platform': Platform.isAndroid ? 'android' : 'ios',
    });
  }
}
