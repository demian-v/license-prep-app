import 'package:cloud_firestore/cloud_firestore.dart';

/// One thread, `conversations/{studentUid_instructorUid}` (instructors plan
/// v2 §5, §10). Written only by the server (functions/src/chat.ts); both
/// participants read it live.
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.studentUid,
    required this.instructorUid,
    required this.instructorName,
    required this.studentDisplayName,
    required this.contactUnlocked,
    required this.lastMessageText,
    required this.studentUnread,
    required this.instructorUnread,
    this.instructorPhotoPath,
    this.instructorKind,
    this.lastMessageAt,
    this.lastMessageSender,
    this.studentDeleted = false,
    this.instructorDeleted = false,
  });

  factory ChatConversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ChatConversation(
      id: doc.id,
      studentUid: d['studentUid'] as String? ?? '',
      instructorUid: d['instructorUid'] as String? ?? '',
      instructorName: d['instructorName'] as String? ?? '',
      instructorPhotoPath: d['instructorPhotoPath'] as String?,
      instructorKind: d['instructorKind'] as String?,
      studentDisplayName: d['studentDisplayName'] as String? ?? '',
      contactUnlocked: d['contactUnlocked'] == true,
      lastMessageText: d['lastMessageText'] as String? ?? '',
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSender: d['lastMessageSender'] as String?,
      studentUnread: (d['studentUnread'] as num?)?.toInt() ?? 0,
      instructorUnread: (d['instructorUnread'] as num?)?.toInt() ?? 0,
      studentDeleted: d['studentDeleted'] == true,
      instructorDeleted: d['instructorDeleted'] == true,
    );
  }

  final String id;
  final String studentUid;
  final String instructorUid;
  final String instructorName;

  /// A Storage path (not a URL — P3b), resolved under storage.rules.
  final String? instructorPhotoPath;
  final String? instructorKind;

  /// "Anna K." — what an instructor sees of a student.
  final String studentDisplayName;

  /// True after the first confirmed booking (P7): masking stops and the
  /// student's header shows the instructor's contacts.
  final bool contactUnlocked;
  final String lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSender;
  final int studentUnread;
  final int instructorUnread;

  /// Set when that side deleted their account (plan v2 §17): the thread
  /// stays for the other side, read-only, as «Удалённый пользователь».
  final bool studentDeleted;
  final bool instructorDeleted;

  bool isStudent(String uid) => uid == studentUid;
  int unreadFor(String uid) =>
      isStudent(uid) ? studentUnread : instructorUnread;

  /// The other side was deleted, so nothing can be sent.
  bool get closed => studentDeleted || instructorDeleted;

  /// Whether the other side is the deleted one, from [uid]'s point of view.
  bool otherDeleted(String uid) =>
      isStudent(uid) ? instructorDeleted : studentDeleted;
}

/// One message, `conversations/{id}/messages/{messageId}`: text only, no
/// edits or deletes (plan v2 §10).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.text,
    required this.masked,
    this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return ChatMessage(
      id: doc.id,
      senderUid: d['senderUid'] as String? ?? '',
      text: d['text'] as String? ?? '',
      masked: d['masked'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  final String id;
  final String senderUid;
  final String text;

  /// The server replaced contact details with •••.
  final bool masked;
  final DateTime? createdAt;
}
