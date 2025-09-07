import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/issue_report.dart';

class ReportService {
  final _db = FirebaseFirestore.instance;

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
      userId: user?.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    await _db.collection('reports').add(report.toMap());
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
      userId: user?.uid,
      language: language,
      state: state,
      appVersion: pkg.version,
      buildNumber: pkg.buildNumber,
      device: Platform.isAndroid ? 'android' : 'ios',
      platform: Platform.isAndroid ? 'android' : 'ios',
    );

    await _db.collection('reports').add(report.toMap());
  }
}
