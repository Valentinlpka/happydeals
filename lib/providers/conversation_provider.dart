import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/classes/rating.dart';
import 'package:rxdart/rxdart.dart';

class ConversationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  BehaviorSubject<List<Conversation>>? _conversationsController;
  final List<StreamSubscription> _subscriptions = [];

  // Getters
  String? get currentUserId => _currentUserId;
  bool get isInitialized => _currentUserId != null;

  // Initialize service for user
// Dans ConversationService, modifiez la méthode initializeForUser :

  Future<void> initializeForUser(String userId) async {
    print('Initializing ConversationService for user: $userId');
    if (_currentUserId == userId) {
      print('Service already initialized for this user');
      return;
    }

    await cleanUp();
    _currentUserId = userId;
    _conversationsController = BehaviorSubject<List<Conversation>>();

    try {
      // Subscribe to user conversations
      final query = _firestore
          .collection('conversations')
          .where(Filter.or(
            Filter('particulierId', isEqualTo: userId),
            Filter('entrepriseId', isEqualTo: userId),
          ))
          .orderBy('lastMessageTimestamp', descending: true);

      print('Creating Firestore query: ${query.parameters}');

      final conversationsSubscription = query.snapshots().listen(
        (snapshot) {
          print(
              'Received Firestore snapshot with ${snapshot.docs.length} documents');
          if (_currentUserId == userId) {
            final conversations = snapshot.docs
                .map((doc) => Conversation.fromFirestore(doc))
                .toList();
            print('Parsed ${conversations.length} conversations');
            _conversationsController?.add(conversations);
          }
        },
        onError: (error) {
          print('Error in Firestore subscription: $error');
          // Si c'est une erreur d'index manquant, elle apparaîtra ici
          if (error.toString().contains('indexes?create_composite=')) {
            print('Index missing. Create the following index:');
            print(error.toString());
          }
        },
      );

      _subscriptions.add(conversationsSubscription);
      notifyListeners();
      print('ConversationService initialized successfully');
    } catch (e) {
      print('Error during initialization: $e');
      // Réinitialiser en cas d'erreur
      await cleanUp();
      rethrow;
    }
  }

// Et dans ConversationsListScreen, modifiez le StreamBuilder :

  Future<void> cleanUp() async {
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _conversationsController?.close();
    _conversationsController = null;
    _currentUserId = null;
    notifyListeners();
  }

  // Conversations streams
  Stream<List<Conversation>> getUserConversationsStream() {
    if (_conversationsController == null || _currentUserId == null) {
      return Stream.value([]);
    }
    return _conversationsController!.stream;
  }

  // Messages
  Future<String> getOrCreateConversation(
      String particulierId, String entrepriseId) async {
    if (_currentUserId == null) throw Exception('Service not initialized');

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
        sellerId: entrepriseId,
      );

      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toFirestore());
      return docRef.id;
    }
  }

  Stream<List<Message>> getConversationMessages(String conversationId) {
    if (_currentUserId == null) return Stream.value([]);

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
    if (_currentUserId != senderId) return;

    final message = Message(
      id: '',
      senderId: senderId,
      content: content,
      timestamp: DateTime.now(),
    );

    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    final conversationData = conversationDoc.data() as Map<String, dynamic>;

    final recipientId = conversationData['particulierId'] == senderId
        ? conversationData['entrepriseId']
        : conversationData['particulierId'];

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTimestamp': Timestamp.fromDate(message.timestamp),
      'lastMessageSenderId': senderId,
      'unreadCount': 1,
      'unreadBy': recipientId,
    });

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message.toFirestore());

    notifyListeners();
  }

  Future<void> markMessageAsRead(String conversationId, String userId) async {
    if (_currentUserId != userId) return;

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

  Future<String> getOrCreateConversationForAd(
      String buyerId, String sellerId, String adId) async {
    if (_currentUserId == null) throw Exception('Service not initialized');

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
      sellerId: sellerId,
    );

    final docRef = await _firestore
        .collection('conversations')
        .add(conversation.toFirestore());

    return docRef.id;
  }

  // Notifications
  Stream<Map<String, int>> getDetailedUnreadCount(String userId) {
    if (_currentUserId != userId)
      return Stream.value({'total': 0, 'ads': 0, 'business': 0});

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
    if (_currentUserId != userId) return Stream.value(0);
    return getDetailedUnreadCount(userId).map((counts) => counts['total'] ?? 0);
  }

  Stream<int> getAdUnreadCount(String userId) {
    if (_currentUserId != userId) return Stream.value(0);
    return getDetailedUnreadCount(userId).map((counts) => counts['ads'] ?? 0);
  }

  Stream<int> getBusinessUnreadCount(String userId) {
    if (_currentUserId != userId) return Stream.value(0);
    return getDetailedUnreadCount(userId)
        .map((counts) => counts['business'] ?? 0);
  }

  // Gestion des annonces
  Future<void> markAdAsSold(String conversationId) async {
    if (_currentUserId == null) return;

    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    if (!conversationDoc.exists) return;

    final conversationData = conversationDoc.data() as Map<String, dynamic>;
    final adId = conversationData['adId'] as String?;
    if (adId == null) return;

    final adDoc = await _firestore.collection('ads').doc(adId).get();
    if (!adDoc.exists) return;

    final adData = adDoc.data() as Map<String, dynamic>;
    final sellerId = adData['userId'] as String;

    await _firestore.collection('conversations').doc(conversationId).update({
      'isAdSold': true,
      'soldDate': Timestamp.fromDate(DateTime.now()),
      'sellerId': sellerId,
      'sellerHasRated': false,
      'buyerHasRated': false,
    });

    await _firestore.collection('ads').doc(adId).update({
      'status': 'sold',
      'buyerId': conversationData['particulierId'],
      'soldDate': Timestamp.fromDate(DateTime.now()),
    });

    notifyListeners();
  }

  // Système d'évaluation
  Future<void> submitRating(Rating rating) async {
    if (_currentUserId == null) return;

    await _firestore.collection('ratings').add(rating.toFirestore());

    await _firestore
        .collection('conversations')
        .doc(rating.conversationId)
        .update({
      rating.isSellerRating ? 'sellerHasRated' : 'buyerHasRated': true,
    });

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
    if (_currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('ratings')
        .where('toUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Rating.fromFirestore(doc)).toList());
  }

  Stream<List<Conversation>> getAdConversations(String adId) {
    if (_currentUserId == null) return Stream.value([]);

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
