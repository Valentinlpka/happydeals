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
        // Convertir le nom de la route en titre de page plus lisible
        String pageTitle;
        switch (screenName) {
          case '/':
            pageTitle = 'Accueil';
            break;
          case '/login':
            pageTitle = 'Connexion';
            break;
          case '/signup':
            pageTitle = 'Inscription';
            break;
          case '/profile_completion':
            pageTitle = 'Compléter le profil';
            break;
          case '/home':
            pageTitle = 'Tableau de bord';
            break;
          case '/cart':
            pageTitle = 'Panier';
            break;
          case '/payment-cancel':
            pageTitle = 'Paiement annulé';
            break;
          default:
            if (screenName.startsWith('/entreprise/')) {
              pageTitle = 'Entreprise';
              _analytics.logEvent(
                name: 'view_company',
                parameters: {
                  'company_id': screenName.split('/').last,
                },
              );
            } else if (screenName.startsWith('/emploi/')) {
              pageTitle = 'Offre d\'emploi';
              _analytics.logEvent(
                name: 'view_job_offer',
                parameters: {
                  'job_id': screenName.split('/').last,
                },
              );
            } else {
              pageTitle = screenName
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

        // Envoyer l'événement de vue avec le nom de la route
        _analytics.logScreenView(
          screenName:
              pageTitle, // Utiliser le titre descriptif comme nom d'écran
          screenClass: screenName, // Utiliser le nom de la route comme classe
        );

        // Mettre à jour le titre de la page web
        _analytics.updateWebPageTitle(pageTitle);
      } catch (e) {
        debugPrint('Erreur lors de la mise à jour du titre de la page: $e');
        // En cas d'erreur, on envoie quand même l'événement avec le nom brut
        _analytics.logScreenView(
          screenName: screenName,
          screenClass: route.settings.runtimeType.toString(),
        );
      }
    }
  }
}
