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
  final Map<String, dynamic>? postData;
  final String type;
  final Map<String, dynamic>? metadata;
  final List<String>? mediaUrls;
  final List<String>? seenBy;
  final String? emoji;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.postData,
    required this.type,
    this.metadata,
    this.mediaUrls,
    this.seenBy,
    this.emoji,
    this.isRead = false,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'text',
      isDeleted: data['isDeleted'] ?? false,
      isEdited: data['isEdited'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
      postData: data['postData'] as Map<String, dynamic>?,
      editedAt: data['editedAt'] != null
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      seenBy: List<String>.from(data['seenBy'] ?? []),
      emoji: data['emoji'],
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'postData': postData,
      'metadata': metadata,
      'mediaUrls': mediaUrls,
      'seenBy': seenBy,
      'emoji': emoji,
      'isRead': isRead,
    };
  }
}

enum MessageType {
  text,
  system,
  sharedPost,
  image,
  video,
  file,
  emoji,
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
  final String? groupType; // 'private', 'business', 'mixed'
  final String? groupDescription;
  final String? groupImage;
  final String? creatorId;
  final List<String>? adminIds;
  final bool isMuted;
  final Map<String, dynamic>? lastMessageData;
  final bool isArchived;
  final bool isPinned;

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
    this.groupType,
    this.groupDescription,
    this.groupImage,
    this.creatorId,
    this.adminIds,
    this.isMuted = false,
    this.lastMessageData,
    this.isArchived = false,
    this.isPinned = false,
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
      groupType: data['groupType'],
      groupDescription: data['groupDescription'],
      groupImage: data['groupImage'],
      creatorId: data['creatorId'],
      adminIds:
          data['adminIds'] != null ? List<String>.from(data['adminIds']) : null,
      isMuted: data['isMuted'] ?? false,
      lastMessageData: data['lastMessageData'],
      isArchived: data['isArchived'] ?? false,
      isPinned: data['isPinned'] ?? false,
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
      'isMuted': isMuted,
      'lastMessageData': lastMessageData,
      'isArchived': isArchived,
      'isPinned': isPinned,
    };

    if (adId != null) {
      data['sellerId'] = sellerId;
      data['isAdSold'] = isAdSold;
    }

    if (isGroup) {
      data['groupName'] = groupName;
      data['members'] = members;
      data['groupType'] = groupType;
      data['groupDescription'] = groupDescription;
      data['groupImage'] = groupImage;
      data['creatorId'] = creatorId;
      data['adminIds'] = adminIds;
    }

    data.removeWhere((key, value) => value == null);

    return data;
  }
}

enum ConversationType {
  private,
  business,
  group,
  ad,
}
