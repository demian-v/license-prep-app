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

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'reason': reason,
      'contentType': contentType,
      'entity': entity,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    // Only add non-null optional fields
    if (message != null) map['message'] = message;
    if (userId != null) map['userId'] = userId;
    if (language != null) map['language'] = language;
    if (state != null) map['state'] = state;
    if (appVersion != null) map['appVersion'] = appVersion;
    if (buildNumber != null) map['buildNumber'] = buildNumber;
    if (device != null) map['device'] = device;
    if (platform != null) map['platform'] = platform;
    
    return map;
  }
}
