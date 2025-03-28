import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:happy/config/app_router.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/providers/search_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/services/analytics_service.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/theme/app_theme.dart';
import 'package:happy/widgets/analytics_navigator_observer.dart';
import 'package:happy/widgets/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  // Initialiser les widgets Flutter de manière asynchrone
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration URL uniquement pour le web
  if (kIsWeb) {
    initializeUrlStrategy();
    // ignore: prefer_const_constructors
    setUrlStrategy(PathUrlStrategy());
  }

  try {
    // Initialiser Firebase et Analytics en premier
    await AnalyticsService().initialize();

    // Autres initialisations
    await Future.wait([
      initializeDateFormatting('fr_FR', null),
    ]);

    // Configuration de timeago
    timeago.setLocaleMessages('fr', timeago.FrMessages());

    // Initialiser FCM pour le web
    if (kIsWeb) {
      await _initializeFirebaseMessagingWeb().catchError((e) {
        debugPrint('Erreur d\'initialisation FCM: $e');
      });
    }

    // Envoyer un événement de test
    await AnalyticsService().logEvent(
      name: 'app_start',
      parameters: {
        'platform': kIsWeb ? 'web' : 'mobile',
        'timestamp': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      },
    );
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation: $e');
  }

  runApp(const MyApp());
}

Future<void> _initializeFirebaseMessagingWeb() async {
  try {
    // Demander les permissions de manière asynchrone
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Obtenir le token FCM
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey:
          'BJqxpGh0zaBedTU9JBdIQ8LrVUXetBpUBKT4wrrV_LXiI9vy0LwRa4_KCprNARbLEiV9gFnVipimUO5AN60XqSI',
    );

    if (token != null) {
      debugPrint('FCM Token Web obtenu: $token');

      // Écouteur pour sauvegarder le token quand l'utilisateur se connecte
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': token})
              .then((_) => debugPrint(
                  'Token FCM sauvegardé pour l\'utilisateur ${user.uid}'))
              .catchError((error) =>
                  debugPrint('Erreur lors de la sauvegarde du token: $error'));
        }
      });
    }
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation de FCM: $e');
  }
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
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
      ],
      child: MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        title: 'Up !',
        home: AppRouter.getHomeScreen(),
        initialRoute: '/',
        routes: AppRouter.routes,
        onGenerateRoute: AppRouter.generateRoute,
        navigatorObservers: [AnalyticsNavigatorObserver()],
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
}
