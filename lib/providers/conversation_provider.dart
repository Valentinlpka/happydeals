import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/conversation.dart';

class ConversationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Conversation>> getUserConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where(Filter.or(
          Filter('particulierId', isEqualTo: userId),
          Filter('entrepriseId', isEqualTo: userId),
        ))
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromFirestore(doc))
            .toList());
  }

  Stream<List<Message>> getConversationMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList());
  }

  Future<void> sendMessage(
      String conversationId, String senderId, String content) async {
    final message = Message(
      id: '',
      senderId: senderId,
      content: content,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
    });

    notifyListeners();
  }

  Future<String> getOrCreateConversation(
      String particulierId, String entrepriseId) async {
    // Vérifier si une conversation existe déjà
    final querySnapshot = await _firestore
        .collection('conversations')
        .where('particulierId', isEqualTo: particulierId)
        .where('entrepriseId', isEqualTo: entrepriseId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      // Une conversation existe déjà, retourner son ID
      return querySnapshot.docs.first.id;
    } else {
      // Aucune conversation n'existe, en créer une nouvelle
      final conversation = Conversation(
        id: '',
        particulierId: particulierId,
        entrepriseId: entrepriseId,
        lastMessage: '',
        lastMessageTimestamp: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toFirestore());
      return docRef.id;
    }
  }
}
