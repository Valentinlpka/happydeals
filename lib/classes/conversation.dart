import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class Conversation {
  final String id;
  final String particulierId;
  final String entrepriseId;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  int unreadCount;
  final String unreadBy;

  Conversation({
    required this.id,
    required this.particulierId,
    required this.entrepriseId,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.unreadCount,
    required this.unreadBy,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Conversation(
        id: doc.id,
        particulierId: data['particulierId'] ?? '',
        entrepriseId: data['entrepriseId'] ?? '',
        lastMessage: data['lastMessage'] ?? '',
        lastMessageTimestamp:
            (data['lastMessageTimestamp'] as Timestamp).toDate(),
        unreadCount: data['unreadCount'] ?? 0,
        unreadBy: data['unreadBy'] ?? '');
  }

  Map<String, dynamic> toFirestore() {
    return {
      'particulierId': particulierId,
      'entrepriseId': entrepriseId,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': Timestamp.fromDate(lastMessageTimestamp),
      'unreadCount': unreadCount,
      'unreadBy': unreadBy,
    };
  }
}
