import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  List<NotificationModel> _notifications = [];
  bool _hasUnreadNotifications = false;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  List<NotificationModel> get notifications => _notifications;
  bool get hasUnreadNotifications => _hasUnreadNotifications;

  NotificationProvider() {
    _initNotificationListener();
  }

  void _initNotificationListener() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _notificationSubscription?.cancel();
    _notificationSubscription = _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      _updateUnreadStatus();
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      final notification =
          _notifications.firstWhere((n) => n.id == notificationId);
      notification.isRead = true;
      _updateUnreadStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors du marquage de la notification comme lue: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final batch = _db.batch();
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final unreadNotifications = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      for (var notification in _notifications) {
        notification.isRead = true;
      }
      _updateUnreadStatus();
      notifyListeners();
    } catch (e) {
      debugPrint(
          'Erreur lors du marquage de toutes les notifications comme lues: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();

      // Mettre à jour la liste locale
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la suppression de la notification: $e');
      rethrow;
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required NotificationType type,
    String? targetId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _db.collection('notifications').add({
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'type': type.toString().split('.').last,
        'userId': userId,
        'targetId': targetId,
        'isRead': false,
      });
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout de la notification: $e');
    }
  }

  void _updateUnreadStatus() {
    _hasUnreadNotifications = _notifications.any((n) => !n.isRead);
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }
}
