import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import '../screens/auth/auth_page.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:timeago/timeago.dart' as timeago_fr;

void main() async {
  timeago.setLocaleMessages('fr', timeago_fr.FrMessages());
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Users()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Gilroy',
          focusColor: Colors.blue,
          primaryColorLight: Colors.blue,
          primaryColorDark: Colors.blue,
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
          primaryColor: Colors.blue,
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(surfaceTintColor: Colors.white),
          colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              background: Colors.white,
              surfaceTint: Colors.white),
          useMaterial3: true,
        ),
        home: const AuthPage(),
      ),
    );
  }
}
