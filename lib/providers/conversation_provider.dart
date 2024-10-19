import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/conversation.dart';

class ConversationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    final conversationData = conversationDoc.data() as Map<String, dynamic>;

    // Déterminer le destinataire
    final recipientId = conversationData['particulierId'] == senderId
        ? conversationData['entrepriseId']
        : conversationData['particulierId'];

    // Mettre à jour la conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
      'lastMessageSenderId': senderId,
      'unreadCount': FieldValue.increment(1),
      'unreadBy':
          recipientId, // Ajouter ce champ pour suivre qui n'a pas lu le message
    });

    // Ajouter le message à la sous-collection
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toFirestore());

    notifyListeners();
  }

  Future<void> markMessageAsRead(String conversationId, String userId) async {
    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    final conversationData = conversationDoc.data() as Map<String, dynamic>;

    if (conversationData['unreadBy'] == userId) {
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': 0,
        'unreadBy': null,
      });
      notifyListeners();
    }
  }

  Stream<List<Conversation>> getUserConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where(Filter.or(
          Filter('particulierId', isEqualTo: userId),
          Filter('entrepriseId', isEqualTo: userId),
        ))
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final conversation = Conversation.fromFirestore(doc);
              // Ne réinitialisez pas unreadCount à 0, utilisez la valeur de Firestore
              return conversation;
            }).toList());
  }

  Stream<int> getTotalUnreadCount(String userId) {
    return _firestore
        .collection('conversations')
        .where(Filter.or(
          Filter('particulierId', isEqualTo: userId),
          Filter('entrepriseId', isEqualTo: userId),
        ))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.fold<int>(0, (sum, doc) {
        final unreadCount = doc.data()['unreadCount'];
        return sum + (unreadCount is int ? unreadCount : 0);
      });
    });
  }

  Future<String> getOrCreateConversation(
      String particulierId, String entrepriseId) async {
    final querySnapshot = await _firestore
        .collection('conversations')
        .where('particulierId', isEqualTo: particulierId)
        .where('entrepriseId', isEqualTo: entrepriseId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    } else {
      final conversation = Conversation(
          id: '',
          particulierId: particulierId,
          entrepriseId: entrepriseId,
          lastMessage: '',
          lastMessageTimestamp: DateTime.now(),
          unreadCount: 0,
          unreadBy: '');
      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toFirestore());
      return docRef.id;
    }
  }
}
