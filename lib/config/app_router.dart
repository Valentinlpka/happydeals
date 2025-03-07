import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/auth/auth_wrapper.dart';
import 'package:happy/screens/auth/complete_profile.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:happy/screens/auth/register_page.dart';
import 'package:happy/screens/booking_detail_page.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_reservation_dealexpress_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:happy/screens/payment_cancel.dart';
import 'package:happy/screens/payment_success.dart';
import 'package:happy/screens/profile_page.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
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
        '/entreprise/:entrepriseId': (context) => const DetailsEntreprise(),
        '/company/:entrepriseId': (context) => const DetailsEntreprise(),
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

    // Extraire l'ID de l'URL
    final uri = Uri.parse(settings.name ?? '');
    final pathSegments = uri.pathSegments;

    // Gérer les différentes routes
    if (pathSegments.length == 2) {
      final id = pathSegments[1];
      switch (pathSegments[0]) {
        case 'orders':
          return MaterialPageRoute(
            builder: (context) => OrderDetailPage(orderId: id),
            settings: settings,
          );

        case 'reservations':
          return MaterialPageRoute(
            builder: (context) => ReservationDetailsPage(reservationId: id),
            settings: settings,
          );

        case 'bookings':
          return MaterialPageRoute(
            builder: (context) => BookingDetailPage(bookingId: id),
            settings: settings,
          );

        case 'profile':
          return MaterialPageRoute(
            builder: (context) => const ProfilePage(),
            settings: settings,
          );

        case 'entreprise':
        case 'company':
          return MaterialPageRoute(
            builder: (context) => DetailsEntreprise(entrepriseId: id),
            settings: settings,
          );

        case 'produits':
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('products')
                  .doc(id)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Scaffold(
                    body: Center(child: Text('Produit non trouvé')),
                  );
                }
                final product = Product.fromFirestore(snapshot.data!);
                return ModernProductDetailPage(product: product);
              },
            ),
            settings: settings,
          );
      }
    }

    // Route par défaut si aucune correspondance n'est trouvée
    return MaterialPageRoute(
      builder: (context) => const MainContainer(),
      settings: settings,
    );
  }
}
