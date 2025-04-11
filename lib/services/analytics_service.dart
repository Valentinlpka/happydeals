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

  // Cache pour éviter les doublons de vues
  String? _lastScreenName;
  DateTime? _lastScreenViewTime;

  // Initialisation basique
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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

  // Méthode unique pour logger des événements
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      debugPrint('🔍 Analytics Event: $name');
      debugPrint('📝 Parameters: $parameters');

      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      debugPrint('❌ Erreur Analytics: $e');
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
      // Liste complète des titres à ignorer
      final titlesToIgnore = [
        'up',
        'up!',
        'up !',
        'up_',
        'up_!',
        'up particulier',
        'up_particulier'
      ];

      // Normaliser et vérifier le nom d'écran
      final normalizedName = screenName.toLowerCase().trim();
      if (titlesToIgnore.contains(normalizedName)) {
        debugPrint('�� Vue ignorée (titre par défaut): $screenName');
        return;
      }

      // Vérifier si c'est la même vue que la dernière vue enregistrée
      final now = DateTime.now();
      if (_lastScreenName == normalizedName &&
          _lastScreenViewTime != null &&
          now.difference(_lastScreenViewTime!) < const Duration(seconds: 2)) {
        debugPrint('🚫 Vue ignorée (doublon): $screenName');
        return;
      }

      if (kIsWeb) {
        final String webScreenName = normalizedName
            .replaceAll(RegExp(r'[^a-z0-9]'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .trim();

        // Vérification supplémentaire pour le web
        if (titlesToIgnore.contains(webScreenName)) {
          debugPrint('🚫 Vue web ignorée (titre par défaut): $webScreenName');
          return;
        }

        if (_analytics == null) {
          debugPrint('⚠️ Analytics non initialisé pour le web');
          return;
        }

        await _analytics?.logScreenView(
          screenName: webScreenName,
        );

        await _analytics
            ?.logScreenView(
          screenName: webScreenName,
        )
            .catchError((error) {
          debugPrint(
              '❌ Erreur lors de la mise à jour du titre de la page web: $error');
        });
      } else {
        await _analytics?.logScreenView(
          screenName: normalizedName,
          screenClass: screenClass,
        );
      }

      _lastScreenName = normalizedName;
      _lastScreenViewTime = now;
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'envoi de la vue d\'écran: $e');
    }
  }

  // Méthode spécifique pour le web
  Future<void> updateWebPageTitle(String title) async {
    if (kIsWeb) {
      try {
        final String screenName = title.toLowerCase().replaceAll(' ', '_');
        // Vérifier si c'est la même vue que la dernière vue enregistrée
        if (_lastScreenName == screenName) {
          return; // Ignorer la mise à jour en double
        }
        await _analytics?.logScreenView(
          screenName: screenName,
        );
        _lastScreenName = screenName;
      } catch (e) {
        debugPrint('Erreur lors de la mise à jour du titre de la page: $e');
      }
    }
  }

  // Méthodes pour suivre les interactions avec les produits
  Future<void> logProductInteraction({
    required String productId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'product_id': productId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'product_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les services
  Future<void> logServiceInteraction({
    required String serviceId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'service_id': serviceId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'service_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les deals express
  Future<void> logDealExpressInteraction({
    required String dealId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'deal_id': dealId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'deal_express_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les jeux concours
  Future<void> logContestInteraction({
    required String contestId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'contest_id': contestId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'contest_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les parrainages
  Future<void> logReferralInteraction({
    required String referralId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'referral_id': referralId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'referral_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les événements
  Future<void> logEventInteraction({
    required String eventId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'event_id': eventId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'event_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les happy deals
  Future<void> logHappyDealInteraction({
    required String happyDealId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'happy_deal_id': happyDealId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'happy_deal_interaction', parameters: params);
  }

  // Méthodes pour suivre les interactions avec les codes promo
  Future<void> logPromoCodeInteraction({
    required String promoCodeId,
    required String interactionType,
    Map<String, Object>? additionalParams,
  }) async {
    final params = {
      'promo_code_id': promoCodeId,
      'interaction_type': interactionType,
      ...?additionalParams,
    };
    await logEvent(name: 'promo_code_interaction', parameters: params);
  }
}
