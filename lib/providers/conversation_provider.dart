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

  // Méthode pour vérifier le type d'utilisateur
  Future<String> _getUserType(String userId) async {
    // Vérifier d'abord si c'est une entreprise
    final companyDoc =
        await _firestore.collection('companys').doc(userId).get();
    if (companyDoc.exists) {
      return 'company';
    }
    return 'user';
  }

  Future<String?> checkExistingConversation({
    required String userId1,
    required String userId2,
    String? adId,
  }) async {
    Query query = _firestore
        .collection('conversations')
        .where('isGroup', isEqualTo: false);

    if (adId != null) {
      query = query.where('adId', isEqualTo: adId);
    }

    // Chercher dans les deux sens possibles
    final querySnapshot = await query
        .where(Filter.or(
          Filter.and(
            Filter('particulierId', isEqualTo: userId1),
            Filter('entrepriseId', isEqualTo: userId2),
          ),
          Filter.and(
            Filter('particulierId', isEqualTo: userId2),
            Filter('entrepriseId', isEqualTo: userId1),
          ),
        ))
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<String> createConversationWithFirstMessage({
    required String senderId,
    required String receiverId,
    required String messageContent,
    String? adId,
  }) async {
    // Préparer les données de base de la conversation
    Map<String, dynamic> conversationData = {
      'lastMessage': messageContent,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'unreadCount': 1,
      'unreadBy': receiverId,
      'isGroup': false,
      'sellerHasRated': false,
      'buyerHasRated': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Déterminer les types d'utilisateurs
    final senderType = await _getUserType(senderId);
    final receiverType = await _getUserType(receiverId);

    if (adId != null) {
      // Logique pour les conversations liées aux annonces
      // ... code existant pour les annonces
    } else if (senderType == 'company' || receiverType == 'company') {
      // Logique pour les conversations avec une entreprise
      conversationData['particulierId'] =
          senderType == 'company' ? receiverId : senderId;
      conversationData['entrepriseId'] =
          senderType == 'company' ? senderId : receiverId;
    } else {
      // Conversation entre particuliers
      conversationData['particulierId'] = senderId;
      conversationData['otherUserId'] = receiverId;
      conversationData['type'] =
          'private'; // Ajouter un type pour identifier facilement
    }

    try {
      // Créer la conversation
      final docRef =
          await _firestore.collection('conversations').add(conversationData);

      // Ajouter le premier message
      await _firestore
          .collection('conversations')
          .doc(docRef.id)
          .collection('messages')
          .add({
        'content': messageContent,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'normal',
      });

      return docRef.id;
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  // Méthode principale pour envoyer un message (premier ou suivant)
  Future<String> sendFirstMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? adId,
  }) async {
    // Vérifier si une conversation existe déjà
    final existingConversationId = await checkExistingConversation(
      userId1: senderId,
      userId2: receiverId,
      adId: adId,
    );

    if (existingConversationId != null) {
      // Si la conversation existe, envoyer simplement le message
      await sendMessage(existingConversationId, senderId, content);
      return existingConversationId;
    }

    // Si la conversation n'existe pas, la créer avec le premier message
    return await createConversationWithFirstMessage(
      senderId: senderId,
      receiverId: receiverId,
      messageContent: content,
      adId: adId,
    );
  }

  Future<String> createNewConversation({
    required String senderId,
    required String receiverId,
    required String messageContent,
    String? adId,
    bool isBusinessConversation = false,
  }) async {
    // Déterminer qui est le particulier et qui est l'entreprise si nécessaire
    String? particulierId;
    String? entrepriseId;

    if (isBusinessConversation) {
      particulierId = senderId;
      entrepriseId = receiverId;
    } else {
      // Pour une conversation entre particuliers
      particulierId = senderId;
    }

    final Map<String, dynamic> conversationData = {
      'particulierId': particulierId,
      'entrepriseId': entrepriseId,
      'lastMessage': messageContent,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'unreadCount': 1,
      'unreadBy': receiverId,
      'adId': adId,
      'lastMessageSenderId': senderId,
      'isGroup': false,
      'sellerHasRated': false,
      'buyerHasRated': false,
    };

    // Ajouter des champs spécifiques si c'est une conversation liée à une annonce
    if (adId != null) {
      final adDoc = await _firestore.collection('ads').doc(adId).get();
      if (adDoc.exists) {
        final adData = adDoc.data() as Map<String, dynamic>;
        conversationData['sellerId'] = adData['userId'];
        conversationData['isAdSold'] = false;
      }
    }

    // Créer la conversation
    final docRef =
        await _firestore.collection('conversations').add(conversationData);

    // Créer le premier message
    await _firestore
        .collection('conversations')
        .doc(docRef.id)
        .collection('messages')
        .add({
      'content': messageContent,
      'senderId': senderId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'normal'
    });

    return docRef.id;
  }

  Future<String> createGroupConversation(
    String creatorId,
    List<Map<String, dynamic>> members,
    String groupName,
  ) async {
    if (_currentUserId == null) throw Exception('Service not initialized');

    // Créer la liste des membres avec leurs types
    final List<Map<String, dynamic>> allMembers = [
      {
        'id': creatorId,
        'type': 'user', // Le créateur est toujours un utilisateur
        'name': await _getUserName(creatorId),
      },
      ...members,
    ];

    // Créer le document de conversation de groupe
    final groupConversation = {
      'isGroup': true,
      'groupName': groupName,
      'creatorId': creatorId,
      'members': allMembers,
      'memberIds': allMembers.map((m) => m['id']).toList(),
      'lastMessage': '',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': '',
      'unreadCount': 0,
      'unreadBy': [],
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'group', // Pour différencier des conversations normales
    };

    // Créer la conversation
    final docRef =
        await _firestore.collection('conversations').add(groupConversation);

    // Envoyer le message système de création
    await sendSystemMessage(
      docRef.id,
      'Groupe "$groupName" créé par ${await _getUserName(creatorId)}',
    );

    return docRef.id;
  }

// Modifiez la méthode sendMessage pour gérer les groupes
// Méthode mise à jour pour envoyer un message dans une conversation existante
  Future<void> sendMessage(
    String conversationId,
    String senderId,
    String content,
  ) async {
    if (conversationId.isEmpty) return;

    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!conversationDoc.exists) throw Exception('Conversation introuvable');

      final data = conversationDoc.data()!;

      // Ajouter d'abord le message dans la sous-collection messages
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'content': content,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'normal',
      });

      // Déterminer qui doit être marqué comme n'ayant pas lu
      dynamic unreadBy;
      if (data['isGroup'] == true) {
        // Pour les groupes, tous les membres sauf l'expéditeur
        final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        unreadBy = members
            .where((m) => m['id'] != senderId)
            .map((m) => m['id'])
            .toList();
      } else {
        // Pour les conversations normales et annonces
        if (data['adId'] != null) {
          // Pour les annonces, mettre unreadBy sur le destinataire
          unreadBy = data['particulierId'] == senderId
              ? data['entrepriseId']
              : data['particulierId'];
        } else if (data['particulierId'] == senderId) {
          unreadBy = data['entrepriseId'] ?? data['otherUserId'];
        } else {
          unreadBy = data['particulierId'];
        }
      }

      // Mettre à jour le document principal de la conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': 1,
        'unreadBy': unreadBy,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

// Modifiez la méthode markMessageAsRead pour gérer les groupes
  Future<void> markMessageAsRead(String conversationId, String userId) async {
    if (_currentUserId != userId) return;

    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    final conversationData = conversationDoc.data() as Map<String, dynamic>;

    if (conversationData['isGroup'] == true) {
      // Pour les groupes, retirer l'utilisateur de la liste unreadBy
      final List<dynamic> unreadBy =
          List.from(conversationData['unreadBy'] ?? []);
      if (unreadBy.contains(userId)) {
        unreadBy.remove(userId);
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update({
          'unreadBy': unreadBy,
          'unreadCount': unreadBy.isEmpty ? 0 : conversationData['unreadCount'],
        });
      }
    } else {
      // Logique existante pour les conversations individuelles
      if (conversationData['unreadBy'] == userId) {
        await _firestore
            .collection('conversations')
            .doc(conversationId)
            .update({
          'unreadCount': 0,
          'unreadBy': null,
        });
      }
    }

    notifyListeners();
  }

  Future<void> sendSystemMessage(String conversationId, String content) async {
    final message = {
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'system',
      'senderId': null,
    };

    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add(message);

    await _firestore.collection('conversations').doc(conversationId).update({
      'lastMessage': content,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': null,
    });
  }

  Future<String> _getUserName(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return 'Utilisateur inconnu';

    final userData = userDoc.data()!;
    return '${userData['firstName']} ${userData['lastName']}';
  }

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
      // Créer une requête qui combine tous les types de conversations possibles
      final query = _firestore
          .collection('conversations')
          .where(Filter.or(
            // Pour les conversations où l'utilisateur est le particulier
            Filter('particulierId', isEqualTo: userId),
            // Pour les conversations où l'utilisateur est l'entreprise
            Filter('entrepriseId', isEqualTo: userId),
            // Pour les conversations entre particuliers où l'utilisateur est l'autre utilisateur
            Filter('otherUserId', isEqualTo: userId),
            // Pour les conversations de groupe
            Filter('memberIds', arrayContains: userId),
          ))
          .orderBy('lastMessageTimestamp', descending: true);

      print('Creating Firestore query for user: $userId');

      final conversationsSubscription = query.snapshots().listen(
        (snapshot) {
          print('Received ${snapshot.docs.length} conversations');
          if (_currentUserId == userId) {
            final conversations = snapshot.docs
                .map((doc) {
                  try {
                    final conversation = Conversation.fromFirestore(doc);
                    print('Processed conversation: ${conversation.id}');
                    return conversation;
                  } catch (e) {
                    print('Error processing conversation ${doc.id}: $e');
                    return null;
                  }
                })
                .where((conv) => conv != null)
                .cast<Conversation>()
                .toList();

            _conversationsController?.add(conversations);
          }
        },
        onError: (error) {
          print('Error in conversation subscription: $error');
          if (error.toString().contains('indexes?create_composite=')) {
            print('Missing index. Create the following composite index:');
            print(error.toString());
          }
        },
      );

      _subscriptions.add(conversationsSubscription);
      notifyListeners();
      print('ConversationService initialized successfully');
    } catch (e) {
      print('Error during ConversationService initialization: $e');
      await cleanUp();
      rethrow;
    }
  }

  // Méthode pour nettoyer les ressources
  Future<void> cleanUp() async {
    print('Cleaning up ConversationService');
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _conversationsController?.close();
    _conversationsController = null;
    _currentUserId = null;
    notifyListeners();
  }

  // Getter pour le stream des conversations
  Stream<List<Conversation>> getUserConversationsStream() {
    if (_conversationsController == null || _currentUserId == null) {
      print('Returning empty conversation stream');
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
    if (_currentUserId != userId) {
      return Stream.value({'total': 0, 'ads': 0, 'business': 0});
    }

    return _firestore
        .collection('conversations')
        .where(Filter.or(
          Filter('particulierId', isEqualTo: userId),
          Filter('entrepriseId', isEqualTo: userId),
          Filter('memberIds', arrayContains: userId),
        ))
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      int adMessagesUnread = 0;
      int businessMessagesUnread = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;

        // Pour les groupes
        if (data['isGroup'] == true) {
          final List<dynamic> unreadBy = List.from(data['unreadBy'] ?? []);
          if (unreadBy.contains(userId)) {
            businessMessagesUnread += 1;
            totalUnread += 1;
          }
        } else {
          final isUnreadByCurrentUser = data['unreadBy'] == userId;
          final lastMessageSenderId = data['lastMessageSenderId'] ?? '';

          if (isUnreadByCurrentUser && lastMessageSenderId != userId) {
            // Vérifie si c'est une conversation d'annonce
            if (data['adId'] != null && data['particulierId'] == userId) {
              adMessagesUnread += unreadCount;
            } else {
              businessMessagesUnread += unreadCount;
            }
            totalUnread += unreadCount;
          }
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

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeleted': true,
        'content': 'Message supprimé',
      });
    } catch (e) {
      print('Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> editMessage(
      String conversationId, String messageId, String newContent) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
        'content': newContent,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error editing message: $e');
      rethrow;
    }
  }
}
