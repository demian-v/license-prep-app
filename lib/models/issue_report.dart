import 'package:cloud_firestore/cloud_firestore.dart';

class IssueReport {
  final String reason;              // image | translation | other
  final String contentType;         // quiz_question | theory_section
  final Map<String, dynamic> entity; // context data
  final String status;              // open
  final String? message;            // required if reason==other
  final String? userId;
  final String? language;
  final String? state;
  final String? appVersion;
  final String? buildNumber;
  final String? device;
  final String? platform;

  IssueReport({
    required this.reason,
    required this.contentType,
    required this.entity,
    this.status = 'open',
    this.message,
    this.userId,
    this.language,
    this.state,
    this.appVersion,
    this.buildNumber,
    this.device,
    this.platform,
  });

  Map<String, dynamic> toMap() => {
    'reason': reason,
    'contentType': contentType,
    'entity': entity,
    'status': status,
    'message': message,
    'userId': userId,
    'language': language,
    'state': state,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'device': device,
    'platform': platform,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
