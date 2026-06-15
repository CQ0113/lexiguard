import 'package:cloud_firestore/cloud_firestore.dart';

class LexiBotRepository {
  LexiBotRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _resolvedFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> streamConversations(String userId) {
    return _resolvedFirestore
        .collection('users/$userId/lexibot_conversations')
        .orderBy('lastActiveAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String userId, String conversationId) {
    return _resolvedFirestore
        .collection('users/$userId/lexibot_conversations/$conversationId/messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> createConversation(String userId, String conversationId, String title) async {
    final docRef = _resolvedFirestore.doc('users/$userId/lexibot_conversations/$conversationId');
    await docRef.set({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveMessage(
    String userId,
    String conversationId,
    String messageId,
    Map<String, dynamic> messageData,
  ) async {
    final batch = _resolvedFirestore.batch();
    
    // Save the message document
    final msgRef = _resolvedFirestore.doc(
      'users/$userId/lexibot_conversations/$conversationId/messages/$messageId',
    );
    batch.set(msgRef, {
      ...messageData,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update the conversation's last active timestamp
    final convRef = _resolvedFirestore.doc('users/$userId/lexibot_conversations/$conversationId');
    batch.update(convRef, {
      'lastActiveAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> deleteConversation(String userId, String conversationId) async {
    final messagesSnapshot = await _resolvedFirestore
        .collection('users/$userId/lexibot_conversations/$conversationId/messages')
        .get();
    
    final batch = _resolvedFirestore.batch();
    
    for (final doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    final convRef = _resolvedFirestore.doc('users/$userId/lexibot_conversations/$conversationId');
    batch.delete(convRef);
    
    await batch.commit();
  }
}
