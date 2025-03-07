import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/firebase_options.dart';

/// Service pour gérer les initialisations et fonctionnalités liées à Firebase
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  /// Initialise Firebase et les autres services nécessaires
  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      await _initializeWebFCM();
    }
  }

  /// Initialise Firebase Cloud Messaging pour le web
  Future<void> _initializeWebFCM() async {
    try {
      // Attendre que l'utilisateur soit connecté
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        String? token = await FirebaseMessaging.instance.getToken(
          vapidKey:
              'BJqxpGh0zaBedTU9JBdIQ8LrVUXetBpUBKT4wrrV_LXiI9vy0LwRa4_KCprNARbLEiV9gFnVipimUO5AN60XqSI',
        );

        if (token != null) {
          // Sauvegarder le token dans Firestore pour l'utilisateur
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});

          debugPrint('FCM Token Web: $token');
        }
      }
    } catch (e) {
      debugPrint('Erreur d\'initialisation FCM: $e');
    }
  }

  /// Met à jour le token FCM de l'utilisateur connecté
  Future<void> updateFCMTokenForCurrentUser() async {
    if (!kIsWeb) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? token = await FirebaseMessaging.instance.getToken(
          vapidKey:
              'BJqxpGh0zaBedTU9JBdIQ8LrVUXetBpUBKT4wrrV_LXiI9vy0LwRa4_KCprNARbLEiV9gFnVipimUO5AN60XqSI',
        );

        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token});
        }
      }
    } catch (e) {
      debugPrint('Erreur de mise à jour du token FCM: $e');
    }
  }
}
