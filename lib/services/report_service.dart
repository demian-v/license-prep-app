import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      print('ReportService: Error generating custom ID, falling back to random ID: $e');
      
      // Fallback to original method if custom ID generation fails
      await _db.collection('reports').add(report.toMap());
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
      print('ReportService: Error generating custom ID, falling back to random ID: $e');
      
      // Fallback to original method if custom ID generation fails
      await _db.collection('reports').add(report.toMap());
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
      print('ReportService: Error generating custom ID, falling back to random ID: $e');
      await _db.collection('reports').add(report.toMap());
    }
  }
}
