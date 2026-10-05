import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/chat.dart';

/// What [ChatService.send] reports back.
class SendResult {
  const SendResult(
      {required this.conversationId,
      required this.created,
      required this.masked});

  final String conversationId;

  /// The message started the thread (a student's first message).
  final bool created;

  /// The server replaced contact details with •••.
  final bool masked;
}

/// Chat (instructors plan v2 §10, P6). Reads are live Firestore listeners
/// (participants only, firestore.rules); every write goes through the
/// callables in functions/src/chat.ts, which mask contacts and enforce the
/// paywall and the new-thread limit.
class ChatService {
  ChatService({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _firestoreOverride = firestore,
        _functions = functions;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functions;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _fns => _functions ?? FirebaseFunctions.instance;

  /// The thread id the server uses: one thread per student and instructor.
  static String conversationIdFor(String studentUid, String instructorUid) =>
      '${studentUid}_$instructorUid';

  /// The user's threads, newest first. Sorted here rather than in the query,
  /// which would need a composite index (array-contains + orderBy, risk #15);
  /// a user has tens of threads at most.
  Stream<List<ChatConversation>> conversations(String uid) => _firestore
          .collection('conversations')
          .where('participantUids', arrayContains: uid)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(ChatConversation.fromDoc).toList();
        list.sort((a, b) => (b.lastMessageAt ?? DateTime(0))
            .compareTo(a.lastMessageAt ?? DateTime(0)));
        return list;
      });

  /// The tab badge: unread messages summed over the user's threads.
  Stream<int> unreadCount(String uid) => conversations(uid)
      .map((list) => list.fold(0, (total, c) => total + c.unreadFor(uid)));

  /// One thread. Only for a thread that exists: the rules check
  /// `participantUids` on the document, so a missing one is a permission
  /// error, not an empty snapshot.
  Stream<ChatConversation> conversation(String id) => _firestore
      .collection('conversations')
      .doc(id)
      .snapshots()
      .map(ChatConversation.fromDoc);

  /// Whether the thread exists yet, for a student opening «Написать». False
  /// on the permission error a missing thread gives.
  Future<bool> exists(String id) async {
    try {
      return (await _firestore.collection('conversations').doc(id).get())
          .exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// The newest [limit] messages, oldest first.
  Stream<List<ChatMessage>> messages(String conversationId, {int limit = 50}) =>
      _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) =>
              snap.docs.map(ChatMessage.fromDoc).toList().reversed.toList());

  /// A student's first message passes [instructorUid]; every later one, and
  /// every instructor reply, passes [conversationId].
  Future<SendResult> send(
      {String? conversationId,
      String? instructorUid,
      required String text}) async {
    final result = await _fns.httpsCallable('sendMessage').call({
      if (conversationId != null) 'conversationId': conversationId,
      if (conversationId == null) 'instructorUid': instructorUid,
      'text': text,
    });
    final data = result.data as Map;
    return SendResult(
      conversationId: data['conversationId'] as String,
      created: data['created'] == true,
      masked: data['masked'] == true,
    );
  }

  Future<void> markRead(String conversationId) => _fns
      .httpsCallable('markConversationRead')
      .call({'conversationId': conversationId});

  /// The instructor's phone and email, once a booking unlocked the thread.
  Future<({String phone, String email})> contactInfo(
      String conversationId) async {
    final result = await _fns
        .httpsCallable('getInstructorContactInfo')
        .call({'conversationId': conversationId});
    final data = result.data as Map;
    return (
      phone: data['phone'] as String? ?? '',
      email: data['contactEmail'] as String? ?? ''
    );
  }
}
