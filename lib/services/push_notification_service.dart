import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/models/notification_model.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:provider/provider.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init(BuildContext context) async {
    if (!kIsWeb) return;

    try {
      // Les permissions sont déjà demandées dans main.dart
      // Écouter les messages en premier plan
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleMessage(message, context);
      });

      // Écouter les clics sur les notifications
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message, context);
      });
    } catch (e) {
      debugPrint('Erreur d\'initialisation des notifications: $e');
    }
  }

  void _handleMessage(RemoteMessage message, BuildContext context) {
    // Ajouter la notification à Firestore via le provider
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    notificationProvider.addNotification(
      title: message.notification?.title ?? '',
      message: message.notification?.body ?? '',
      type: _getNotificationTypeFromData(message.data),
      targetId: message.data['targetId'],
    );

    // Pour le web, on peut afficher une notification native du navigateur
    if (kIsWeb) {
      _showWebNotification(message);
    }
  }

  void _showWebNotification(RemoteMessage message) {
    // Les notifications web sont gérées automatiquement par le navigateur
    // via le service worker de Firebase
  }

  NotificationType _getNotificationTypeFromData(Map<String, dynamic> data) {
    final typeStr = data['type'] ?? '';
    return NotificationType.values.firstWhere(
      (e) => e.toString().split('.').last == typeStr,
      orElse: () => NotificationType.order,
    );
  }

  void _handleNotificationClick(RemoteMessage message, BuildContext context) {
    final type = _getNotificationTypeFromData(message.data);
    final targetId = message.data['targetId'];

    switch (type) {
      case NotificationType.order:
        if (targetId != null) {
          Navigator.pushNamed(context, '/orders/$targetId');
        }
        break;
      case NotificationType.event:
        if (targetId != null) {
          Navigator.pushNamed(context, '/events/$targetId');
        }
        break;
      case NotificationType.newFollower:
        if (targetId != null) {
          Navigator.pushNamed(context, '/profile/$targetId');
        }
        break;
      case NotificationType.newPost:
        if (targetId != null) {
          Navigator.pushNamed(context, '/posts/$targetId');
        }
        break;
    }
  }
}
