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
  final Map<String, dynamic>? postData; // Ajout du champ postData

  final String type;
  final Map<String, dynamic>? metadata; // Pour les données spécifiques au type

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.postData, // Ajout du paramètre dans le constructeur

    required this.type,
    this.metadata,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'],
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'],
      isDeleted: data['isDeleted'] ?? false,
      isEdited: data['isEdited'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,

      postData:
          data['postData'] as Map<String, dynamic>?, // Conversion du postData

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
      'postData': postData, // Inclusion du postData
      'metadata': metadata,
    };
  }

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'system':
        return MessageType.system;
      case 'shared_post':
        return MessageType.sharedPost;
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
}

enum MessageType {
  text,
  system,
  sharedPost,
  image,
  file,
}

// Dans classes/conversation.dart
class Conversation {
  final String id;
  final String? particulierId;
  final String? entrepriseId;
  final String? otherUserId;
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

  Conversation({
    required this.id,
    this.particulierId,
    this.entrepriseId,
    this.otherUserId,
    this.adId,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.unreadCount,
    required this.unreadBy,
    this.isAdSold,
    required this.lastMessageSenderId,
    required this.sellerHasRated,
    required this.buyerHasRated,
    this.sellerId,
    this.isGroup = false,
    this.groupName,
    this.members,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Conversation(
      id: doc.id,
      particulierId: data['particulierId'],
      entrepriseId: data['entrepriseId'],
      otherUserId: data['otherUserId'],
      adId: data['adId'],
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTimestamp:
          (data['lastMessageTimestamp'] as Timestamp?)?.toDate() ??
              DateTime.now(),
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      unreadBy: data['unreadBy'],
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
    );
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'particulierId': particulierId,
      'entrepriseId': entrepriseId,
      'otherUserId': otherUserId,
      'adId': adId,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': Timestamp.fromDate(lastMessageTimestamp),
      'unreadCount': unreadCount,
      'unreadBy': unreadBy,
      'lastMessageSenderId': lastMessageSenderId,
      'sellerHasRated': sellerHasRated,
      'buyerHasRated': buyerHasRated,
      'isGroup': isGroup,
    };

    // Ajouter les champs conditionnels
    if (adId != null) {
      data['sellerId'] = sellerId;
      data['isAdSold'] = isAdSold;
    }

    if (isGroup) {
      data['groupName'] = groupName;
      data['members'] = members;
    }

    // Supprimer les valeurs nulles
    data.removeWhere((key, value) => value == null);

    return data;
  }
}
