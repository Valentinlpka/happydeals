import 'package:flutter/material.dart';
import 'package:happy/services/analytics_service.dart';

class AnalyticsNavigatorObserver extends NavigatorObserver {
  static final AnalyticsNavigatorObserver _instance =
      AnalyticsNavigatorObserver._internal();
  factory AnalyticsNavigatorObserver() => _instance;
  AnalyticsNavigatorObserver._internal();

  final AnalyticsService _analytics = AnalyticsService();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sendScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _sendScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      _sendScreenView(previousRoute);
    }
  }

  void _sendScreenView(Route<dynamic> route) {
    final String? screenName = route.settings.name;
    if (screenName != null) {
      try {
        // Liste des routes à ignorer
        final routesToIgnore = ['/', '', 'up', 'up!', 'up !'];
        if (routesToIgnore.contains(screenName.toLowerCase().trim())) {
          debugPrint('🚫 Route ignorée: $screenName');
          return;
        }

        // Convertir le nom de la route en titre de page plus lisible
        String pageTitle;
        String? eventName;
        Map<String, Object>? eventParams;

        // Normaliser le nom de l'écran pour éviter les doublons
        final normalizedScreenName = screenName.toLowerCase().trim();

        switch (normalizedScreenName) {
          case '/':
          case '/home':
            pageTitle = 'Accueil';
            eventName = 'view_home';
            break;
          case '/login':
            pageTitle = 'Connexion';
            eventName = 'view_login';
            break;
          case '/signup':
            pageTitle = 'Inscription';
            eventName = 'view_signup';
            break;
          case '/profile_completion':
            pageTitle = 'Compléter le profil';
            eventName = 'view_profile_completion';
            break;
          case '/cart':
            pageTitle = 'Panier';
            eventName = 'view_cart';
            break;
          case '/payment-cancel':
            pageTitle = 'Paiement annulé';
            eventName = 'view_payment_cancel';
            break;
          default:
            if (normalizedScreenName.startsWith('/entreprise/')) {
              final companyId = normalizedScreenName.split('/').last;
              pageTitle = 'Entreprise';
              eventName = 'view_company';
              eventParams = {'company_id': companyId};
            } else if (normalizedScreenName.startsWith('/emploi/')) {
              final jobId = normalizedScreenName.split('/').last;
              pageTitle = 'Offre d\'emploi';
              eventName = 'view_job_offer';
              eventParams = {'job_id': jobId};
            } else if (normalizedScreenName.startsWith('/produit/')) {
              final productId = normalizedScreenName.split('/').last;
              pageTitle = 'Produit';
              eventName = 'view_product';
              eventParams = {'product_id': productId};
            } else if (normalizedScreenName.startsWith('/service/')) {
              final serviceId = normalizedScreenName.split('/').last;
              pageTitle = 'Service';
              eventName = 'view_service';
              eventParams = {'service_id': serviceId};
            } else if (normalizedScreenName.startsWith('/deal_express/')) {
              final dealId = normalizedScreenName.split('/').last;
              pageTitle = 'Deal Express';
              eventName = 'view_deal_express';
              eventParams = {'deal_id': dealId};
            } else if (normalizedScreenName.startsWith('/concours/')) {
              final contestId = normalizedScreenName.split('/').last;
              pageTitle = 'Jeu Concours';
              eventName = 'view_contest';
              eventParams = {'contest_id': contestId};
            } else if (normalizedScreenName.startsWith('/parrainage/')) {
              final referralId = normalizedScreenName.split('/').last;
              pageTitle = 'Parrainage';
              eventName = 'view_referral';
              eventParams = {'referral_id': referralId};
            } else if (normalizedScreenName.startsWith('/evenement/')) {
              final eventId = normalizedScreenName.split('/').last;
              pageTitle = 'Événement';
              eventName = 'view_event';
              eventParams = {'event_id': eventId};
            } else if (normalizedScreenName.startsWith('/happy_deal/')) {
              final happyDealId = normalizedScreenName.split('/').last;
              pageTitle = 'Happy Deal';
              eventName = 'view_happy_deal';
              eventParams = {'happy_deal_id': happyDealId};
            } else if (normalizedScreenName.startsWith('/code_promo/')) {
              final promoCodeId = normalizedScreenName.split('/').last;
              pageTitle = 'Code Promo';
              eventName = 'view_promo_code';
              eventParams = {'promo_code_id': promoCodeId};
            } else {
              pageTitle = normalizedScreenName
                  .replaceAll('/', ' ')
                  .replaceAll('_', ' ')
                  .split(' ')
                  .where((word) => word.isNotEmpty)
                  .map((word) =>
                      word[0].toUpperCase() +
                      (word.length > 1 ? word.substring(1) : ''))
                  .join(' ');
            }
        }

        // Normaliser le titre de la page pour le web
        final normalizedPageTitle = pageTitle
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .trim();

        // Vérifier si ce n'est pas une variante du titre "Up"
        if (normalizedPageTitle == 'up' ||
            normalizedPageTitle == 'up_' ||
            normalizedPageTitle.startsWith('up_!')) {
          return;
        }

        // Vérification supplémentaire avant d'envoyer l'événement
        if (!normalizedPageTitle.startsWith('up') &&
            !normalizedPageTitle.contains('up_') &&
            normalizedPageTitle != 'up') {
          _analytics.logScreenView(
            screenName: normalizedPageTitle,
            screenClass: normalizedScreenName,
          );

          if (eventName != null) {
            _analytics.logEvent(
              name: eventName,
              parameters: eventParams,
            );
          }
        } else {
          debugPrint('🚫 Vue ignorée (titre Up): $normalizedPageTitle');
        }

        // Mettre à jour le titre de la page web uniquement si ce n'est pas le titre par défaut
        if (!pageTitle.toLowerCase().contains('up')) {
          _analytics.updateWebPageTitle(pageTitle);
        }
      } catch (e) {
        debugPrint('❌ Erreur lors de la mise à jour du titre de la page: $e');
        // En cas d'erreur, on n'envoie plus l'événement brut pour éviter les doublons
        if (!screenName.toLowerCase().contains('up')) {
          _analytics.logScreenView(
            screenName: screenName,
            screenClass: route.settings.runtimeType.toString(),
          );
        }
      }
    }
  }
}
