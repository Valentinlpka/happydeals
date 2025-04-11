import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  order,
  dealExpress,
  booking,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final NotificationType type;
  final String? targetId;
  final String userId; // ID de l'utilisateur destinataire
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    required this.userId,
    this.targetId,
    this.isRead = false,
  });

  // Conversion depuis Firestore
  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      type: _stringToNotificationType(data['type'] ?? ''),
      userId: data['userId'] ?? '',
      targetId: data['targetId'],
      isRead: data['isRead'] ?? false,
    );
  }

  // Conversion vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type.toString().split('.').last,
      'userId': userId,
      'targetId': targetId,
      'isRead': isRead,
    };
  }

  static NotificationType _stringToNotificationType(String type) {
    switch (type) {
      case 'order':
        return NotificationType.order;
      case 'deal_express':
        return NotificationType.dealExpress;
      case 'booking':
        return NotificationType.booking;
      default:
        return NotificationType.order;
    }
  }
}
