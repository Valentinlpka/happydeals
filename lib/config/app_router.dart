import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/auth/auth_wrapper.dart';
import 'package:happy/screens/auth/complete_profile.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:happy/screens/auth/register_page.dart';
import 'package:happy/screens/booking_detail_page.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_dealsexpress_page.dart';
import 'package:happy/screens/details_page/details_emploi_page.dart';
import 'package:happy/screens/details_page/details_evenement_page.dart';
import 'package:happy/screens/details_page/details_happydeals.dart';
import 'package:happy/screens/details_page/details_jeuxconcours_page.dart';
import 'package:happy/screens/details_page/details_parrainage.dart';
import 'package:happy/screens/details_page/details_reservation_dealexpress_page.dart';
import 'package:happy/screens/details_page/details_service_page.dart';
import 'package:happy/screens/payment_cancel.dart';
import 'package:happy/screens/payment_success.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/screens/promo_code_detail.dart';
import 'package:happy/screens/restaurant_order_detail_page.dart';
import 'package:happy/screens/restaurants/restaurant_detail_wrapper.dart';
import 'package:happy/screens/restaurants/restaurant_test_page.dart';
import 'package:happy/screens/restaurants/restaurants_page.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/screens/unified_cart_page.dart';
import 'package:universal_html/html.dart' as html;

/// Classe qui gère le routage de l'application
class AppRouter {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Définition des noms de routes constants
  static const String home = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String profileCompletion = '/profile_completion';
  static const String cart = '/cart';
  static const String paymentCancel = '/payment-cancel';
  static const String paymentSuccess = '/payment-success';

  // Routes pour les notifications et détails
  static const String orderDetails = '/order';
  static const String reservationDetails = '/reservation';
  static const String bookingDetails = '/booking';
  static const String productDetails = '/product';
  static const String serviceDetails = '/service';
  static const String companyDetails = '/company';
  static const String dealExpressDetails = '/deal-express';
  static const String eventDetails = '/event';
  static const String contestDetails = '/contest';
  static const String referralDetails = '/referral';
  static const String happyDealDetails = '/happy-deal';
  static const String promoCodeDetails = '/promo-code';
  static const String jobDetails = '/job';
  static const String userProfile = '/user-profile';
  static const String restaurants = '/restaurants';
  static const String restaurantsTest = '/restaurants-test';
  static const String restaurantDetails = '/restaurant';
  static const String restaurantOrderDetails = '/restaurant-order';

  /// Routes nommées statiques
  static Map<String, WidgetBuilder> get routes => {
        '/': (context) => getHomeScreen(),
        login: (context) => const Login(),
        signup: (context) => const SignUpPage(),
        profileCompletion: (context) => const ProfileCompletionPage(),
        cart: (context) => const UnifiedCartPage(),
        paymentCancel: (context) => const PaymentCancel(),
        restaurants: (context) => const RestaurantsPage(),
        restaurantsTest: (context) => const RestaurantTestPage(),
      };

  /// Détermine la page d'accueil
  static Widget getHomeScreen() {
    if (kIsWeb && html.window.location.href.contains(paymentSuccess)) {
      final uri = Uri.parse(html.window.location.href);
      final params = uri.queryParameters;

      return UnifiedPaymentSuccessScreen(
        sessionId: params['session_id'],
        orderId: params['orderId'],
      );
    }
    return const AuthWrapper();
  }

  /// Gère les routes dynamiques
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    // Extraire le nom de la route et les arguments
    final uri = Uri.parse(settings.name ?? '');
    final path = uri.path;
    final args = settings.arguments;

    // Fonction helper pour créer une route avec transition
    MaterialPageRoute getRoute(Widget page) {
      return MaterialPageRoute(
        builder: (_) => page,
        settings: settings,
      );
    }

    // Gestion des routes
    switch (path) {
      // Route de paiement réussi
      case paymentSuccess:
        if (kIsWeb) {
          final params = uri.queryParameters;
          return getRoute(UnifiedPaymentSuccessScreen(
            sessionId: params['session_id'],
            orderId: params['orderId'],
          ));
        }
        break;

      // Détails de commande
      case orderDetails:
        final String orderId;
        if (kIsWeb) {
          orderId = uri.pathSegments.last;
        } else {
          orderId = args as String;
        }
        return getRoute(OrderDetailPage(orderId: orderId));

      // Détails de réservation
      case reservationDetails:
        final String reservationId;
        if (kIsWeb) {
          reservationId = uri.pathSegments.last;
        } else {
          reservationId = args as String;
        }
        return getRoute(ReservationDetailsPage(reservationId: reservationId));

      // Détails de booking
      case bookingDetails:
        final String bookingId;
        if (kIsWeb) {
          bookingId = uri.pathSegments.last;
        } else {
          bookingId = args as String;
        }
        return getRoute(BookingDetailPage(bookingId: bookingId));

      // Détails de restaurant order
      case restaurantOrderDetails:
        final String restaurantOrderId;
        if (kIsWeb) {
          restaurantOrderId = uri.pathSegments.last;
        } else {
          restaurantOrderId = args as String;
        }
        return getRoute(RestaurantOrderDetailPage(orderId: restaurantOrderId));

      // Détails de produit
      case productDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(ModernProductDetailPage(product: args['product']));
        }
        break;

      // Détails de service
      case serviceDetails:
        final String serviceId;
        if (kIsWeb) {
          serviceId = uri.pathSegments.last;
        } else {
          serviceId = args as String;
        }
        return getRoute(ServiceDetailPage(serviceId: serviceId));

      // Détails d'entreprise
      case companyDetails:
        final String companyId;
        if (kIsWeb) {
          companyId = uri.pathSegments.last;
        } else {
          companyId = args as String;
        }
        return getRoute(DetailsEntreprise(entrepriseId: companyId));

      // Détails de deal express
      case dealExpressDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(DetailsDealsExpress(post: args['post']));
        }
        break;

      // Détails d'événement
      case eventDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(DetailsEvenementPage(
            event: args['event'],
            currentUserId: args['currentUserId'],
          ));
        }
        break;

      // Détails de concours
      case contestDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(DetailsJeuxConcoursPage(
            contest: args['contest'],
            currentUserId: args['currentUserId'],
          ));
        }
        break;

      // Détails de parrainage
      case referralDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(DetailsParrainagePage(
            referral: args['referral'],
            currentUserId: args['currentUserId'],
          ));
        }
        break;

      // Détails de happy deal
      case happyDealDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(DetailsHappyDeals(
            happydeal: args['happydeal'],
          ));
        }
        break;

      // Détails de code promo
      case promoCodeDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(PromoCodeDetails(
            post: args['post'],
          ));
        }
        break;

      // Détails d'offre d'emploi
      case jobDetails:
        if (args is Map<String, dynamic>) {
          return getRoute(DetailsEmploiPage(
            post: args['post'],
          ));
        }
        break;

      // Profil utilisateur
      case userProfile:
        final String userId;
        if (kIsWeb) {
          userId = uri.pathSegments.last;
        } else {
          userId = args as String;
        }
        return getRoute(Profile(userId: userId));

      // Restaurants
      case restaurants:
        return getRoute(const RestaurantsPage());
      case restaurantsTest:
        return getRoute(const RestaurantTestPage());
      case restaurantDetails:
        final String restaurantId;
        if (kIsWeb) {
          restaurantId = uri.pathSegments.last;
        } else {
          restaurantId = args as String;
        }
        return getRoute(RestaurantDetailWrapper(restaurantId: restaurantId));
    }

    // Route par défaut si aucune correspondance n'est trouvée
    return getRoute(const AuthWrapper());
  }

  /// Helper pour construire les URLs web
  static String buildWebUrl(String route, String id) {
    return '$route/$id';
  }

  /// HelDetailsper pour la navigation
  static Future<T?> navigateTo<T>(BuildContext context, String route,
      {Object? arguments}) {
    if (kIsWeb && arguments is String) {
      // Pour le web, construire l'URL avec l'ID
      return Navigator.pushNamed(context, buildWebUrl(route, arguments));
    }
    // Pour mobile, utiliser les arguments normalement
    return Navigator.pushNamed(context, route, arguments: arguments);
  }
}
