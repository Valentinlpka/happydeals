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
      // Pour les messages en premier plan, ne pas montrer de notification système
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Ne rien faire car la notification Firestore s'en chargera
        // Ou juste mettre à jour les données sans notification
        _handleMessage(message, context, showNotification: false);
      });

      // Pour les messages en arrière-plan, laisser la notification système
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationClick(message, context);
      });
    } catch (e) {
      debugPrint('Erreur d\'initialisation des notifications: $e');
    }
  }

  void _handleMessage(RemoteMessage message, BuildContext context,
      {bool showNotification = true}) {
    if (!showNotification) return;

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
    switch (typeStr) {
      case 'order':
        return NotificationType.order;
      case 'deal_express':
        return NotificationType.deal_express;
      case 'booking':
        return NotificationType.booking;
      default:
        return NotificationType.order;
    }
  }

  void _handleNotificationClick(RemoteMessage message, BuildContext context) {
    final type = _getNotificationTypeFromData(message.data);
    final targetId = message.data['targetId'];

    if (targetId == null) return;

    switch (type) {
      case NotificationType.order:
        Navigator.pushNamed(context, '/orders/$targetId');
        break;
      case NotificationType.deal_express:
        Navigator.pushNamed(context, '/reservations/$targetId');
        break;
      case NotificationType.booking:
        Navigator.pushNamed(context, '/bookings/$targetId');
        break;
    }
  }
}
