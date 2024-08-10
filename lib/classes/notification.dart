class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String message;
  final String relatedId;
  final DateTime timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.message,
    required this.relatedId,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'message': message,
      'relatedId': relatedId,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['userId'],
      type: map['type'],
      message: map['message'],
      relatedId: map['relatedId'],
      timestamp: map['timestamp'].toDate(),
      isRead: map['isRead'] ?? false,
    );
  }
}
