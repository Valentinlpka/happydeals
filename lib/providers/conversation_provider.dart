import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/classes/post.dart';
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
    try {
      // Vérifier d'abord si c'est une entreprise
      final companyDoc =
          await _firestore.collection('companys').doc(userId).get();
      if (companyDoc.exists) {
        return 'company';
      }

      // Si ce n'est pas une entreprise, c'est un utilisateur normal
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return 'user';
      }

      throw Exception('Utilisateur non trouvé');
    } catch (e) {
      print('Erreur dans _getUserType: $e');
      rethrow;
    }
  }

  Future<void> sharePostInConversation({
    required String senderId,
    required String receiverId,
    required Post post,
    String? comment,
  }) async {
    try {
      // Chercher une conversation existante
      final existingConversationId = await checkExistingConversation(
        userId1: senderId,
        userId2: receiverId,
      );

      final conversationId = existingConversationId ??
          await _firestore.collection('conversations').add({
            'particulierId': senderId,
            'otherUserId': receiverId,
            'lastMessage': 'A partagé une publication',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'lastMessageSenderId': senderId,
            'unreadCount': 1,
            'unreadBy': receiverId,
            'isGroup': false,
          }).then((doc) => doc.id);

      // Créer le message de partage
      final systemMessage = {
        'content': 'A partagé une publication',
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'shared_post',
        'postData': {
          'postId': post.id,
          'postType': post.runtimeType.toString(),
          'comment': comment,
        },
      };

      // Ajouter le message dans la conversation
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(systemMessage);

      // Mettre à jour la conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': 'A partagé une publication',
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': FieldValue.increment(1),
        'unreadBy': receiverId,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _determineUnreadBy(
      String conversationId, String senderId) async {
    final conversationDoc =
        await _firestore.collection('conversations').doc(conversationId).get();
    final data = conversationDoc.data()!;

    if (data['isGroup'] == true) {
      final members = List<Map<String, dynamic>>.from(data['members'] ?? []);
      return members
          .where((m) => m['id'] != senderId)
          .map((m) => m['id'])
          .toList();
    } else {
      return data['particulierId'] == senderId
          ? data['entrepriseId'] ?? data['otherUserId']
          : data['particulierId'];
    }
  }

  Future<String> createAdConversation({
    required String buyerId,
    required String sellerId,
    required String adId,
    required String messageContent,
  }) async {
    // Vérifier d'abord si l'annonce existe et est toujours disponible
    final adDoc = await _firestore.collection('ads').doc(adId).get();
    if (!adDoc.exists) {
      throw Exception('Annonce introuvable');
    }

    final adData = adDoc.data() as Map<String, dynamic>;
    if (adData['status'] != 'available') {
      throw Exception('Cette annonce n\'est plus disponible');
    }

    // Créer la nouvelle conversation spécifique à l'annonce
    final conversationData = {
      'particulierId': buyerId,
      'sellerId': sellerId,
      'adId': adId,
      'isAdSold': false,
      'lastMessage': messageContent,
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'lastMessageSenderId': buyerId,
      'unreadCount': 1,
      'unreadBy': sellerId,
      'type': 'ad_conversation',
      'sellerHasRated': false,
      'buyerHasRated': false,
      'createdAt': FieldValue.serverTimestamp(),
    };

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
      'senderId': buyerId,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'text',
    });

    return docRef.id;
  }

  Future<String?> checkExistingConversation({
    required String userId1,
    required String userId2,
    String? adId,
  }) async {
    print('Début de check');
    if (adId != null) {
      final adQuery = await _firestore
          .collection('conversations')
          .where('adId', isEqualTo: adId)
          .where('particulierId', isEqualTo: userId1)
          .where('sellerId', isEqualTo: userId2)
          .limit(1)
          .get();

      if (adQuery.docs.isNotEmpty) {
        return adQuery.docs.first.id;
      }
      return null;
    }

    // Pour une conversation normale entre particuliers
    final conversationsQuery = await _firestore
        .collection('conversations')
        .where('adId', isEqualTo: null)
        .where('isGroup', isEqualTo: false)
        .get();

    // Vérifier manuellement les conversations pour trouver une correspondance
    for (var doc in conversationsQuery.docs) {
      final data = doc.data();
      final bool isMatch = ((data['particulierId'] == userId1 &&
              data['otherUserId'] == userId2) ||
          (data['particulierId'] == userId2 && data['otherUserId'] == userId1));

      if (isMatch) {
        print('Ca marche on a trouvé une conversation');
        return doc.id;
      }
    }

    return null;
  }

  // Méthode principale pour envoyer un message (premier ou suivant)
  Future<String> sendFirstMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? adId,
  }) async {
    try {
      // Vérifier d'abord le type de chaque utilisateur
      final senderType = await _getUserType(senderId);
      final receiverType = await _getUserType(receiverId);

      // Déterminer le type de conversation
      final isBusinessConversation =
          senderType == 'company' || receiverType == 'company';

      // Chercher une conversation existante avec les bons paramètres
      String? existingConversationId;

      if (isBusinessConversation) {
        // Pour les conversations professionnelles
        final querySnapshot = await _firestore
            .collection('conversations')
            .where('entrepriseId',
                isEqualTo: receiverType == 'company' ? receiverId : senderId)
            .where('particulierId',
                isEqualTo: receiverType == 'company' ? senderId : receiverId)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          existingConversationId = querySnapshot.docs.first.id;
        }
      } else {
        // Pour les conversations normales
        existingConversationId = await checkExistingConversation(
          userId1: senderId,
          userId2: receiverId,
          adId: adId,
        );
      }

      if (existingConversationId != null) {
        await sendMessage(existingConversationId, senderId, content);
        return existingConversationId;
      }

      // Si pas de conversation existante, créer une nouvelle
      return createNewConversation(
        senderId: senderId,
        receiverId: receiverId,
        messageContent: content,
        adId: adId,
        isBusinessConversation: isBusinessConversation,
        senderType: senderType,
        receiverType: receiverType,
      );
    } catch (e) {
      print('Erreur dans sendFirstMessage: $e');
      rethrow;
    }
  }

  Future<String> createNewConversation({
    required String senderId,
    required String receiverId,
    required String messageContent,
    String? adId,
    bool isBusinessConversation = false,
    String? senderType,
    String? receiverType,
  }) async {
    final Map<String, dynamic> conversationData;

    if (isBusinessConversation) {
      // Déterminer qui est l'entreprise et qui est le particulier
      final isReceiverCompany = receiverType == 'company';

      conversationData = {
        'particulierId': isReceiverCompany ? senderId : receiverId,
        'entrepriseId': isReceiverCompany ? receiverId : senderId,
        'lastMessage': messageContent,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': 1,
        'unreadBy': receiverId,
        'isGroup': false,
        'type':
            'business', // Marquer explicitement comme conversation professionnelle
      };
    } else if (adId != null) {
      // Pour les conversations d'annonces
      final adDoc = await _firestore.collection('ads').doc(adId).get();
      if (!adDoc.exists) {
        throw Exception('Annonce introuvable');
      }
      final adData = adDoc.data()!;

      conversationData = {
        'particulierId': senderId,
        'sellerId': receiverId,
        'adId': adId,
        'isAdSold': false,
        'lastMessage': messageContent,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': 1,
        'unreadBy': receiverId,
        'type': 'ad',
        'sellerHasRated': false,
        'buyerHasRated': false,
        'isGroup': false,
      };
    } else {
      // Pour les conversations entre particuliers
      conversationData = {
        'particulierId': senderId,
        'otherUserId': receiverId,
        'lastMessage': messageContent,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': 1,
        'unreadBy': receiverId,
        'isGroup': false,
        'type': 'normal',
      };
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
        'type': 'normal'
      });

      return docRef.id;
    } catch (e) {
      print('Erreur dans createNewConversation: $e');
      rethrow;
    }
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
      } else if (data['entrepriseId'] != null) {
        // Conversation professionnelle
        unreadBy = data['entrepriseId'] == senderId
            ? data[
                'particulierId'] // Si l'entreprise envoie, le particulier doit lire
            : data[
                'entrepriseId']; // Si le particulier envoie, l'entreprise doit lire
        // Pour les conversations normales et annonces
      } else if (data['adId'] != null) {
        // Pour les annonces
        unreadBy = data['particulierId'] == senderId
            ? data['sellerId']
            : data['particulierId'];
      } else {
        // Conversation normale entre particuliers
        unreadBy = data['particulierId'] == senderId
            ? data['otherUserId']
            : data['particulierId'];
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
    if (_currentUserId == userId) return;

    await cleanUp();
    _currentUserId = userId;
    _conversationsController = BehaviorSubject<List<Conversation>>();

    try {
      // Query combinée pour tous les types de conversations
      final query = _firestore
          .collection('conversations')
          .where(Filter.or(
            // Pour les conversations normales où l'utilisateur est particulierId
            Filter('particulierId', isEqualTo: userId),
            // Pour les conversations où l'utilisateur est otherUserId
            Filter('otherUserId', isEqualTo: userId),
            // Pour les conversations business
            Filter('entrepriseId', isEqualTo: userId),
            // Pour les groupes
            Filter('memberIds', arrayContains: userId),
          ))
          .orderBy('lastMessageTimestamp', descending: true);

      final conversationsSubscription = query.snapshots().listen(
        (snapshot) {
          if (_currentUserId == userId) {
            final conversations = snapshot.docs
                .map((doc) {
                  try {
                    return Conversation.fromFirestore(doc);
                  } catch (e) {
                    print(
                        'Erreur lors de la conversion de la conversation: $e');
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
          print('Erreur dans le stream des conversations: $error');
        },
      );

      _subscriptions.add(conversationsSubscription);
      notifyListeners();
    } catch (e) {
      await cleanUp();
      rethrow;
    }
  }

  // Méthode pour nettoyer les ressources
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

  // Getter pour le stream des conversations
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
        .map((snapshot) {
      print('Messages récupérés pour $conversationId: ${snapshot.docs.length}');
      return snapshot.docs.map((doc) => Message.fromFirestore(doc)).toList();
    });
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
    try {
      // Récupérer d'abord les données de la conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      if (!conversationDoc.exists) throw Exception('Conversation introuvable');

      final conversationData = conversationDoc.data() as Map<String, dynamic>;

      // Vérifier si l'annonce est déjà marquée comme vendue dans la conversation
      if (conversationData['isAdSold'] == true) {
        throw Exception('Cette annonce a déjà été marquée comme vendue');
      }

      final adId = conversationData['adId'] as String?;
      if (adId == null) throw Exception('ID de l\'annonce manquant');

      // Vérifier le status de l'annonce
      final adDoc = await _firestore.collection('ads').doc(adId).get();
      if (!adDoc.exists) throw Exception('Annonce introuvable');

      final adData = adDoc.data() as Map<String, dynamic>;
      if (adData['status'] == 'sold') {
        throw Exception('Cette annonce a déjà été marquée comme vendue');
      }

      final buyerId = conversationData['particulierId'] as String?;
      if (buyerId == null) throw Exception('ID de l\'acheteur manquant');

      // Utiliser une transaction pour assurer la cohérence des données
      await _firestore.runTransaction((transaction) async {
        // Vérifier une dernière fois le status pendant la transaction
        final freshAdDoc =
            await transaction.get(_firestore.collection('ads').doc(adId));
        if (freshAdDoc.data()?['status'] == 'sold') {
          throw Exception('Cette annonce a déjà été marquée comme vendue');
        }

        // Mettre à jour l'annonce
        transaction.update(_firestore.collection('ads').doc(adId), {
          'status': 'sold',
          'buyerId': buyerId,
          'soldDate': FieldValue.serverTimestamp(),
          'buyerHasRated': false,
          'sellerHasRated': false,
        });

        // Mettre à jour la conversation
        transaction.update(
            _firestore.collection('conversations').doc(conversationId), {
          'isAdSold': true,
          'soldDate': FieldValue.serverTimestamp(),
          'buyerHasRated': false,
          'sellerHasRated': false,
        });
      });

      notifyListeners();
    } catch (e) {
      print('Erreur lors du marquage de l\'annonce comme vendue: $e');
      rethrow;
    }
  }

  Future<void> updateRating(Rating rating) async {
    try {
      await _firestore
          .collection('ratings')
          .doc(rating.id)
          .update(rating.toFirestore());
      await _updateUserRating(rating.toUserId);
      notifyListeners();
    } catch (e) {
      print('Erreur lors de la mise à jour de l\'évaluation: $e');
      rethrow;
    }
  }

  Future<void> deleteRating(String ratingId) async {
    try {
      final ratingDoc =
          await _firestore.collection('ratings').doc(ratingId).get();
      final ratingData = ratingDoc.data() as Map<String, dynamic>;
      final toUserId = ratingData['toUserId'] as String;

      await _firestore.collection('ratings').doc(ratingId).delete();
      await _updateUserRating(toUserId);
      notifyListeners();
    } catch (e) {
      print('Erreur lors de la suppression de l\'évaluation: $e');
      rethrow;
    }
  }

  // Système d'évaluation
  Future<void> submitRating(Rating rating) async {
    if (_currentUserId == null) return;

    try {
      // Vérifier si une évaluation existe déjà
      final existingRatings = await _firestore
          .collection('ratings')
          .where('conversationId', isEqualTo: rating.conversationId)
          .where('fromUserId', isEqualTo: rating.fromUserId)
          .get();

      if (existingRatings.docs.isNotEmpty) {
        throw Exception('Vous avez déjà évalué cette transaction');
      }

      // Ajouter la nouvelle évaluation
      final docRef =
          await _firestore.collection('ratings').add(rating.toFirestore());

      // Mettre à jour le statut dans la conversation
      await _firestore
          .collection('conversations')
          .doc(rating.conversationId)
          .update({
        rating.isSellerRating ? 'sellerHasRated' : 'buyerHasRated': true,
      });

      await _updateUserRating(rating.toUserId);
      notifyListeners();
    } catch (e) {
      print('Erreur lors de la soumission de l\'évaluation: $e');
      rethrow;
    }
  }

  Stream<List<Rating>> getConversationRatings(String conversationId) {
    return _firestore
        .collection('ratings')
        .where('conversationId', isEqualTo: conversationId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Rating.fromFirestore(doc)).toList());
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
      rethrow;
    }
  }

  Future<String> getOrCreatePrivateConversation(
      String userId1, String userId2) async {
    // D'abord, chercher une conversation existante
    final existingConversationId = await checkExistingConversation(
      userId1: userId1,
      userId2: userId2,
    );

    if (existingConversationId != null) {
      return existingConversationId;
    }

    // Si aucune conversation n'existe, en créer une nouvelle
    return await createNewConversation(
      senderId: userId1,
      receiverId: userId2,
      messageContent: '', // Message vide car on va partager un post
    );
  }
}
