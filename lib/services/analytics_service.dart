import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/firebase_options.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialiser Firebase avec les options par défaut
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _analytics = FirebaseAnalytics.instance;
      await _analytics?.setAnalyticsCollectionEnabled(true);
      _isInitialized = true;
      debugPrint('Analytics initialisé avec succès');
    } catch (e) {
      debugPrint('Erreur d\'initialisation Analytics: $e');
      _isInitialized = false;
    }
  }

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi de l\'événement Analytics: $e');
    }
  }

  Future<void> setUserProperties({
    required String userId,
    required Map<String, String> properties,
  }) async {
    try {
      await _analytics?.setUserId(id: userId);
      for (var entry in properties.entries) {
        await _analytics?.setUserProperty(
          name: entry.key,
          value: entry.value,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la définition des propriétés utilisateur: $e');
    }
  }

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      if (kIsWeb) {
        // Pour le web, on utilise le titre de la page comme nom d'écran
        final String webScreenName =
            screenName.replaceAll('/', '_').toLowerCase();
        await _analytics?.logScreenView(
          screenName: webScreenName,
        );

        // Mettre à jour le titre de la page
        await _analytics?.setCurrentScreen(
          screenName: webScreenName,
        );
      } else {
        await _analytics?.logScreenView(
          screenName: screenName,
          screenClass: screenClass,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi de la vue d\'écran: $e');
    }
  }

  // Méthode spécifique pour le web
  Future<void> updateWebPageTitle(String title) async {
    if (kIsWeb) {
      try {
        final String screenName = title.toLowerCase().replaceAll(' ', '_');
        await _analytics?.setCurrentScreen(
          screenName: screenName,
        );
      } catch (e) {
        debugPrint('Erreur lors de la mise à jour du titre de la page: $e');
      }
    }
  }
}
