import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/auth_page.dart';
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
import 'package:happy/services/cart_service.dart';
import 'package:happy/widgets/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_fr;
import 'package:universal_html/html.dart' as html;

import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initializeUrlStrategy();
  setUrlStrategy(PathUrlStrategy());

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('fr_FR', null);
  timeago.setLocaleMessages('fr', timeago_fr.FrMessages());

  if (kIsWeb) {
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

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => HomeProvider()),
      ChangeNotifierProvider(create: (_) => UserModel()),
      ChangeNotifierProvider(create: (_) => ConversationService()),
      ChangeNotifierProvider(create: (_) => SavedAdsProvider()),
      ChangeNotifierProvider(create: (_) => CartService()),
      ChangeNotifierProvider(create: (_) => ReviewService()),
      ChangeNotifierProvider(create: (_) => NotificationProvider()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => UserModel()),
        ChangeNotifierProvider(create: (_) => ConversationService()),
        ChangeNotifierProvider(create: (_) => SavedAdsProvider()),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => ReviewService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(context),
        home: Builder(
          builder: (context) {
            final currentUrl = html.window.location.href;
            if (currentUrl.contains('/payment-success')) {
              String? sessionId;
              String? orderId;
              String? reservationId;
              String? bookingId;

              try {
                final uri = Uri.parse(currentUrl);
                final params = uri.queryParameters;

                sessionId = params['session_id'];
                orderId = params['orderId'];
                reservationId = params['reservationId'];
                bookingId = params['bookingId'];
              } catch (e) {
                print('Error parsing URL parameters: $e');
              }

              return UnifiedPaymentSuccessScreen(
                sessionId: sessionId,
                orderId: orderId,
                reservationId: reservationId,
                bookingId: bookingId,
              );
            }

            return const AuthWrapper();
          },
        ),
        initialRoute: '/',
        routes: {
          '/signup': (context) => const SignUpPage(),
          '/login': (context) => const Login(),
          '/profile_completion': (context) => const ProfileCompletionPage(),
          '/home': (context) => const MainContainer(),
          '/cart': (context) => const CartScreen(),
          '/payment-cancel': (context) => const PaymentCancel(),
          '/entreprise/:entrepriseId': (context) => const DetailsEntreprise(),
          '/company/:entrepriseId': (context) => const DetailsEntreprise(),
        },
        onGenerateRoute: (settings) {
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
                  builder: (context) =>
                      ReservationDetailsPage(reservationId: id),
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

              print(
                  'URL Params: sessionId=$sessionId, orderId=$orderId, reservationId=$reservationId, bookingId=$bookingId');
            } catch (e) {
              print('Error parsing URL parameters: $e');
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

          // Route par défaut si aucune correspondance n'est trouvée
          return MaterialPageRoute(
            builder: (context) => const MainContainer(),
            settings: settings,
          );
        },
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('fr', 'FR'),
        ],
        locale: const Locale('fr', 'FR'),
      ),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    const Color mediumGrey = Color.fromARGB(255, 200, 200, 200);

    return ThemeData(
      actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (BuildContext context) => const Icon(
                Icons.arrow_back_ios_new_outlined,
                size: 20,
              )),

      scaffoldBackgroundColor: Colors.grey[50],
      dialogBackgroundColor: Colors.grey[50],

      primarySwatch: Colors.blue,
      splashColor: Colors.transparent, // <- Here
      highlightColor: Colors.transparent, // <- Here
      hoverColor: Colors.transparent, // <- Here
      primaryColorLight: Colors.grey[50],
      primaryColorDark: Colors.black,
      textTheme: GoogleFonts.nunitoSansTextTheme(Theme.of(context).textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      primaryColor: Colors.blue[600],
      brightness: Brightness.light,
      appBarTheme: AppBarTheme(
          surfaceTintColor: Colors.grey[50], backgroundColor: Colors.grey[50]),

      useMaterial3: true,
      colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        focusColor: Colors.grey[200],
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: mediumGrey),
          borderRadius: BorderRadius.circular(10),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: mediumGrey),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          // Vérifier si nous sommes sur la page de paiement
          final currentUrl = html.window.location.href;
          if (currentUrl.contains('/payment-success')) {
            // Ne pas rediriger si nous sommes sur la page de paiement
            return const SizedBox.shrink(); // Widget vide
          }

          return FutureBuilder(
            future: _initializeProviders(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                    child: Text('Erreur d\'initialisation: ${snapshot.error}'));
              }

              return const MainContainer();
            },
          );
        }

        return const AuthPage();
      },
    );
  }

  Future<void> _initializeProviders(BuildContext context) async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    await userModel.loadUserData();
  }
}
