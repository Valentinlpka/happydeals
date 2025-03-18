import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:happy/config/app_router.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/notification_provider.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/providers/search_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/services/firebase_service.dart';
import 'package:happy/theme/app_theme.dart';
import 'package:happy/widgets/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_fr;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initializeUrlStrategy();
  setUrlStrategy(PathUrlStrategy());

  await FirebaseService().initialize();

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

  runApp(const MyApp());
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
        home: AppRouter.getHomeScreen(),
        initialRoute: '/',
        routes: AppRouter.routes,
        onGenerateRoute: AppRouter.generateRoute,
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
