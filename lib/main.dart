import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/review_service.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/auth/auth_page.dart';
import 'package:happy/screens/auth/complete_profile.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:happy/screens/auth/register_page.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:happy/screens/payment_cancel.dart';
import 'package:happy/screens/payment_success.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_fr;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
	setUrlStrategy(HashUrlStrategy());

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      systemNavigationBarColor: Colors.white,
    ),
  );

  if (kIsWeb) {
  } else {
    Stripe.publishableKey =
        'pk_test_51LTLueEdQ2kxvmjkFjbvo65zeyYFfgfwZJ4yX8msvLiOkHju26pIj77RZ1XaZOoCG6ULyzn95z1irjk18AsNmwZx00OlxLu8Yt';
    await Stripe.instance.applySettings();
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await initializeDateFormatting('fr_FR', null);
  timeago.setLocaleMessages('fr', timeago_fr.FrMessages());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserModel()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => ConversationService()),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => ReviewService())
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(context),
        home: const AuthWrapper(),
        initialRoute: '/',
        routes: {
          '/signup': (context) => const SignUpPage(),
          '/login': (context) => const Login(),
          '/profile_completion': (context) => const ProfileCompletionPage(),
          '/home': (context) => const MainContainer(),
          '/cart': (context) => const CartScreen(),
          '/payment-cancel': (context) => const PaymentCancel(),
          '/order-confirmation': (context) => const PaymentSuccessScreen(),
          '/company/:entrepriseId': (context) => const DetailsEntreprise(),
        },
        onGenerateRoute: (settings) {
  if (settings.name?.startsWith('/company/') ?? false) {
    final entrepriseId = settings.name!.split('/').last;
    return MaterialPageRoute(
      builder: (context) => DetailsEntreprise(entrepriseId: entrepriseId),
      settings: settings,
    );
  }
  
  // Ajoutez cette condition
  if (settings.name?.startsWith('/payment-success') ?? false) {
    return MaterialPageRoute(
      builder: (context) => PaymentSuccessScreen(
        sessionId: Uri.base.queryParameters['session_id'],
      ),
      settings: settings,
    );
  }
  
  return null;
},
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

      primarySwatch: Colors.blue,
      splashColor: Colors.transparent, // <- Here
      highlightColor: Colors.transparent, // <- Here
      hoverColor: Colors.transparent, // <- Here
      primaryColorLight: Colors.white,
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
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.grey[50],
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
          surfaceTintColor: Colors.white,
          backgroundColor: Colors.grey[50]),

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
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);

    await userModel.loadUserData();
    await homeProvider.loadSavedLocation();
    // Initialisez d'autres providers si nécessaire
  }
}
