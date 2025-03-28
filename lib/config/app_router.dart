import 'package:flutter/material.dart';
import 'package:happy/screens/auth/auth_wrapper.dart';
import 'package:happy/screens/auth/complete_profile.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:happy/screens/auth/register_page.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_emploi_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:happy/screens/payment_cancel.dart';
import 'package:happy/screens/payment_success.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:universal_html/html.dart' as html;

/// Classe qui gère le routage de l'application
class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Routes nommées statiques
  static Map<String, WidgetBuilder> get routes => {
        '/signup': (context) => const SignUpPage(),
        '/login': (context) => const Login(),
        '/profile_completion': (context) => const ProfileCompletionPage(),
        '/home': (context) => const MainContainer(),
        '/cart': (context) => const CartScreen(),
        '/payment-cancel': (context) => const PaymentCancel(),
      };

  /// Détermine la page d'accueil basée sur l'URL actuelle (principalement pour le web)
  static Widget getHomeScreen() {
    if (html.window.location.href.contains('/payment-success')) {
      String? sessionId;
      String? orderId;
      String? reservationId;
      String? bookingId;

      try {
        final uri = Uri.parse(html.window.location.href);
        final params = uri.queryParameters;

        sessionId = params['session_id'];
        orderId = params['orderId'];
        reservationId = params['reservationId'];
        bookingId = params['bookingId'];
      } catch (e) {
        debugPrint('Error parsing URL parameters: $e');
      }

      return UnifiedPaymentSuccessScreen(
        sessionId: sessionId,
        orderId: orderId,
        reservationId: reservationId,
        bookingId: bookingId,
      );
    }

    return const AuthWrapper();
  }

  /// Gère les routes dynamiques
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    // Gérer la route payment-success
    if (settings.name?.startsWith('/payment-success') ?? false) {
      String fullUrl = html.window.location.href;
      String? sessionId;
      String? orderId;
      String? reservationId;
      String? bookingId;

      try {
        final uri = Uri.parse(fullUrl);
        final params = uri.queryParameters;

        sessionId = params['session_id'];
        orderId = params['orderId'];
        reservationId = params['reservationId'];
        bookingId = params['bookingId'];
      } catch (e) {
        debugPrint('Error parsing URL parameters: $e');
      }

      return MaterialPageRoute(
        builder: (context) => UnifiedPaymentSuccessScreen(
          sessionId: sessionId,
          orderId: orderId,
          reservationId: reservationId,
          bookingId: bookingId,
        ),
        settings: settings,
      );
    }

    // Gérer les routes dynamiques pour les entreprises
    if (settings.name?.startsWith('/entreprise/') ?? false) {
      final String entrepriseId = settings.name?.split('/').last ?? '';
      return MaterialPageRoute(
        builder: (context) => DetailsEntreprise(entrepriseId: entrepriseId),
        settings: settings,
      );
    }

    if (settings.name?.startsWith('/company/') ?? false) {
      final String entrepriseId = settings.name?.split('/').last ?? '';
      return MaterialPageRoute(
        builder: (context) => DetailsEntreprise(entrepriseId: entrepriseId),
        settings: settings,
      );
    }

    // Gérer les routes pour les offres d'emploi
    if (settings.name?.startsWith('/emploi/') ?? false) {
      final arguments = settings.arguments as Map<String, dynamic>?;
      if (arguments == null) {
        // Gérer le cas où aucun argument n'est passé
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Offre non trouvée')),
          ),
          settings: settings,
        );
      }

      return MaterialPageRoute(
        builder: (context) => DetailsEmploiPage(
          post: arguments['post'],
          individualName: arguments['individualName'],
          individualPhoto: arguments['individualPhoto'],
        ),
        settings: settings,
      );
    }

    // Route par défaut
    return MaterialPageRoute(
      builder: (context) => const AuthWrapper(),
      settings: settings,
    );
  }
}
