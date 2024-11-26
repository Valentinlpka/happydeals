import 'package:cloud_firestore/cloud_firestore.dart';

// Dans classes/conversation.dart ou là où se trouve votre classe Message

class Message {
  final String id;
  final String? senderId;
  final String content;
  final DateTime timestamp;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;

  final String? type; // Ajout du champ type

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.type, // Peut être 'system' ou null pour les messages normaux
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'], // Récupération du type depuis Firestore
      isDeleted: data['isDeleted'] ?? false,
      isEdited: data['isEdited'] ?? false,
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type, // Inclusion du type dans les données Firestore
    };
  }
}

// Dans classes/conversation.dart

class Conversation {
  final String id;
  final String? particulierId;
  final String? entrepriseId;
  final String?
      otherUserId; // Nouveau champ pour les conversations entre particuliers
  final String? adId;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final int unreadCount;
  final dynamic unreadBy;
  final bool? isAdSold;
  final String lastMessageSenderId;
  final bool sellerHasRated;
  final bool buyerHasRated;
  final String? sellerId;
  final bool isGroup;
  final String? groupName;
  final List<Map<String, dynamic>>? members;
  final String? creatorId;

  Conversation({
    required this.id,
    this.particulierId,
    this.entrepriseId,
    this.otherUserId, // Ajout du nouveau champ
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.unreadCount,
    required this.unreadBy,
    this.adId,
    this.isAdSold,
    required this.lastMessageSenderId,
    required this.sellerHasRated,
    required this.buyerHasRated,
    this.sellerId,
    this.isGroup = false,
    this.groupName,
    this.members,
    this.creatorId,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    DateTime timestamp;
    try {
      timestamp = data['lastMessageTimestamp'] != null
          ? (data['lastMessageTimestamp'] as Timestamp).toDate()
          : DateTime.now();
    } catch (e) {
      timestamp = DateTime.now();
    }

    return Conversation(
      id: doc.id,
      particulierId: data['particulierId'],
      entrepriseId: data['entrepriseId'],
      otherUserId: data['otherUserId'], // Ajout du nouveau champ
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTimestamp: timestamp,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      unreadBy: data['unreadBy'],
      adId: data['adId'],
      isAdSold: data['isAdSold'],
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      sellerHasRated: data['sellerHasRated'] ?? false,
      buyerHasRated: data['buyerHasRated'] ?? false,
      sellerId: data['sellerId'],
      isGroup: data['isGroup'] ?? false,
      groupName: data['groupName'],
      members: data['members'] != null
          ? List<Map<String, dynamic>>.from(data['members'])
          : null,
      creatorId: data['creatorId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'particulierId': particulierId,
      'entrepriseId': entrepriseId,
      'otherUserId': otherUserId, // Ajout du nouveau champ
      'lastMessage': lastMessage,
      'lastMessageTimestamp': Timestamp.fromDate(lastMessageTimestamp),
      'unreadCount': unreadCount,
      'unreadBy': unreadBy,
      'adId': adId,
      'isAdSold': isAdSold,
      'lastMessageSenderId': lastMessageSenderId,
      'sellerHasRated': sellerHasRated,
      'buyerHasRated': buyerHasRated,
      'sellerId': sellerId,
      'isGroup': isGroup,
      'groupName': groupName,
      'members': members,
      'creatorId': creatorId,
    };
  }
}
