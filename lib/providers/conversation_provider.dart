import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/classes/rating.dart';

class ConversationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Messages

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
        unreadBy: '',
        lastMessageSenderId: '',
        sellerHasRated: false,
        buyerHasRated: false,
        sellerId: entrepriseId, // Par défaut, l'entreprise est le vendeur
      );

      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toFirestore());
      return docRef.id;
    }
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

    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    final conversationData = conversationDoc.data() as Map<String, dynamic>;

    // Déterminer le destinataire
    final recipientId = conversationData['particulierId'] == senderId
        ? conversationData['entrepriseId']
        : conversationData['particulierId'];

    // Mise à jour de la conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
      'lastMessageSenderId': senderId,
      'unreadCount': 1,
      'unreadBy': recipientId,
    });

    // Ajouter le message
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

  // Conversations
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

  Future<String> getOrCreateConversationForAd(
      String buyerId, String sellerId, String adId) async {
    final querySnapshot = await _firestore
        .collection('conversations')
        .where('particulierId', isEqualTo: buyerId)
        .where('entrepriseId', isEqualTo: sellerId)
        .where('adId', isEqualTo: adId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }

    // Récupérer l'annonce pour vérifier le vendeur
    final adDoc = await _firestore.collection('ads').doc(adId).get();
    if (!adDoc.exists) throw Exception('Annonce non trouvée');

    final adData = adDoc.data() as Map<String, dynamic>;
    if (adData['userId'] != sellerId) throw Exception('ID vendeur incorrect');

    final conversation = Conversation(
      id: '',
      particulierId: buyerId,
      entrepriseId: sellerId,
      lastMessage: '',
      lastMessageTimestamp: DateTime.now(),
      unreadCount: 0,
      unreadBy: '',
      adId: adId,
      isAdSold: false,
      lastMessageSenderId: '',
      sellerHasRated: false,
      buyerHasRated: false,
      sellerId: sellerId, // Définir le sellerId lors de la création
    );

    final docRef = await _firestore
        .collection('conversations')
        .add(conversation.toFirestore());

    return docRef.id;
  }

  // Notifications
  Stream<Map<String, int>> getDetailedUnreadCount(String userId) {
    return _firestore
        .collection('conversations')
        .where(Filter.or(
          Filter('particulierId', isEqualTo: userId),
          Filter('entrepriseId', isEqualTo: userId),
        ))
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      int adMessagesUnread = 0;
      int businessMessagesUnread = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        final isUnreadByCurrentUser = data['unreadBy'] == userId;
        final lastMessageSenderId = data['lastMessageSenderId'] ?? '';

        if (isUnreadByCurrentUser && lastMessageSenderId != userId) {
          if (data['adId'] != null) {
            adMessagesUnread += unreadCount;
          } else {
            businessMessagesUnread += unreadCount;
          }
          totalUnread += unreadCount;
        }
      }

      return {
        'total': totalUnread,
        'ads': adMessagesUnread,
        'business': businessMessagesUnread,
      };
    });
  }

  Stream<int> getTotalUnreadCount(String userId) {
    return getDetailedUnreadCount(userId).map((counts) => counts['total'] ?? 0);
  }

  Stream<int> getAdUnreadCount(String userId) {
    return getDetailedUnreadCount(userId).map((counts) => counts['ads'] ?? 0);
  }

  Stream<int> getBusinessUnreadCount(String userId) {
    return getDetailedUnreadCount(userId)
        .map((counts) => counts['business'] ?? 0);
  }

  // Gestion des annonces
  Future<void> markAdAsSold(String conversationId) async {
    // Récupérer d'abord la conversation pour avoir l'ID de l'annonce
    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    if (!conversationDoc.exists) return;

    final conversationData = conversationDoc.data() as Map<String, dynamic>;
    final adId = conversationData['adId'] as String?;
    if (adId == null) return;

    // Récupérer l'annonce pour avoir l'ID du vendeur
    final adDoc = await _firestore.collection('ads').doc(adId).get();
    if (!adDoc.exists) return;

    final adData = adDoc.data() as Map<String, dynamic>;
    final sellerId =
        adData['userId'] as String; // L'ID du vendeur est l'userId de l'annonce

    // Mettre à jour la conversation
    await _firestore.collection('conversations').doc(conversationId).update({
      'isAdSold': true,
      'soldDate': Timestamp.fromDate(DateTime.now()),
      'sellerId': sellerId, // Définir le sellerId correctement
      'sellerHasRated': false,
      'buyerHasRated': false,
    });

    // Mettre à jour l'annonce
    await _firestore.collection('ads').doc(adId).update({
      'status': 'sold',
      'buyerId': conversationData['particulierId'],
      'soldDate': Timestamp.fromDate(DateTime.now()),
    });

    notifyListeners();
  }

  // Système d'évaluation
  Future<void> submitRating(Rating rating) async {
    // Ajouter l'évaluation
    await _firestore.collection('ratings').add(rating.toFirestore());

    // Mettre à jour le statut de la conversation
    await _firestore
        .collection('conversations')
        .doc(rating.conversationId)
        .update({
      rating.isSellerRating ? 'sellerHasRated' : 'buyerHasRated': true,
    });

    // Mettre à jour la moyenne des évaluations de l'utilisateur
    await _updateUserRating(rating.toUserId);

    notifyListeners();
  }

  Future<void> _updateUserRating(String userId) async {
    final ratingsSnapshot = await _firestore
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .get();

    if (ratingsSnapshot.docs.isNotEmpty) {
      double totalRating = 0;
      for (var doc in ratingsSnapshot.docs) {
        totalRating += (doc.data()['rating'] as num).toDouble();
      }
      double averageRating = totalRating / ratingsSnapshot.docs.length;

      await _firestore.collection('users').doc(userId).update({
        'averageRating': averageRating,
        'totalRatings': ratingsSnapshot.docs.length,
      });
    }
  }

  Stream<List<Rating>> getUserRatings(String userId) {
    return _firestore
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Rating.fromFirestore(doc)).toList());
  }

  Stream<List<Conversation>> getAdConversations(String adId) {
    return _firestore
        .collection('conversations')
        .where('adId', isEqualTo: adId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromFirestore(doc))
            .toList());
  }
}
