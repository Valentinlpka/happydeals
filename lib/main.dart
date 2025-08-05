import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:happy/config/app_router.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/providers/restaurant_menu_provider.dart';
import 'package:happy/providers/restaurant_provider.dart';
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
import 'package:universal_html/html.dart' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // ✅ OBLIGATOIRE: Initialiser Firebase en PREMIER
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialisé avec succès');

    // Initialisation synchrone de Stripe pour mobile uniquement
    if (!kIsWeb) {
      Stripe.publishableKey =
          'pk_test_51LTLueEdQ2kxvmjkFjbvo65zeyYFfgfwZJ4yX8msvLiOkHju26pIj77RZ1XaZOoCG6ULyzn95z1irjk18AsNmwZx00OlxLu8Yt';
      await Stripe.instance.applySettings();
    }

    // Configuration URL pour le web (synchrone)
    if (kIsWeb) {
      initializeUrlStrategy();
      setUrlStrategy(const PathUrlStrategy());
    }

    // Initialisation rapide des dates
    await initializeDateFormatting('fr_FR', null);

    // Lancer l'app immédiatement
    runApp(const MyApp());

    // Initialiser le reste de manière asynchrone APRÈS le lancement
    _initializeServicesAfterAppStart();
    
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation: $e');
    // Lancer l'app même en cas d'erreur
    runApp(const MyApp());
  }
}

void _initializeServicesAfterAppStart() async {
  // Attendre que l'app soit complètement lancée
  await Future.delayed(const Duration(milliseconds: 100));
  
  try {
    // Initialiser Analytics de manière non-bloquante
    final analytics = AnalyticsService();
    analytics.initialize().then((_) {
      analytics.logEvent(
        name: 'application_start',
        parameters: {
          'platform': kIsWeb ? 'web' : 'mobile',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }).catchError((e) {
      debugPrint('Erreur Analytics: $e');
    });

    // Initialiser PWA et FCM de manière asynchrone
    if (kIsWeb) {
      _checkAndInitializePWA();
      _initializeFirebaseMessagingWeb();
    }

    // Configurer les listeners après le démarrage
    _setupAuthStateListener();
    
  } catch (e) {
    debugPrint('Erreur lors de l\'initialisation des services: $e');
  }
}

void _checkAndInitializePWA() async {
  try {
    final isPWA = await _checkIfPWA();
    if (isPWA) {
      debugPrint('📱 Application exécutée en mode PWA');
      // Loguer l'événement PWA sans bloquer
      final analytics = AnalyticsService();
      analytics.logEvent(
        name: 'pwa_start',
        parameters: {
          'platform': 'pwa',
          'timestamp': DateTime.now().toIso8601String(),
        },
      ).catchError((e) => debugPrint('Erreur PWA Analytics: $e'));
    }
  } catch (e) {
    debugPrint('Erreur PWA: $e');
  }
}

void _setupAuthStateListener() {
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user == null && AppRouter.navigatorKey.currentContext != null) {
      // Utiliser addPostFrameCallback pour éviter les problèmes de build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = AppRouter.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          try {
            // Réinitialiser les providers de manière sécurisée
            final homeProvider = Provider.of<HomeProvider>(context, listen: false);
            final userModel = Provider.of<UserModel>(context, listen: false);
            final conversationService = Provider.of<ConversationService>(context, listen: false);
            final savedAdsProvider = Provider.of<SavedAdsProvider>(context, listen: false);
            
            homeProvider.reset();
            userModel.clearUserData();
            conversationService.cleanUp();
            savedAdsProvider.reset();
          } catch (e) {
            debugPrint('Erreur lors de la réinitialisation des providers: $e');
          }
        }
      });
    }
  });
}

Future<bool> _checkIfPWA() async {
  if (!kIsWeb) return false;

  try {
    final window = html.window;
    return window.matchMedia('(display-mode: standalone)').matches ||
        window.matchMedia('(display-mode: fullscreen)').matches;
  } catch (e) {
    debugPrint('Erreur lors de la vérification du mode PWA: $e');
    return false;
  }
}

Future<void> _initializeFirebaseMessagingWeb() async {
  try {
    // Demander les permissions de manière asynchrone
    final permission = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (permission.authorizationStatus == AuthorizationStatus.authorized) {
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
        ChangeNotifierProvider(create: (_) => RestaurantProvider()),
        ChangeNotifierProvider(create: (_) => RestaurantMenuProvider()),
      ],
      child: MaterialApp(
        navigatorKey: AppRouter.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        title: 'up',
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
        builder: (context, child) {
          // Initialisation ScreenUtil avec gestion d'erreur
          try {
            ScreenUtil.init(
              context,
              designSize: const Size(375, 812),
              minTextAdapt: true,
              splitScreenMode: true,
            );
          } catch (e) {
            debugPrint('Erreur ScreenUtil: $e');
          }
          return child!;
        },
      ),
    );
  }
}