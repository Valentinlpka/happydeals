import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createNotification(NotificationModel notification) async {
    await _firestore.collection('notifications').add(notification.toMap());
  }

  // Autres méthodes du service...
}
