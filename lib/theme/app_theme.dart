import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Couleurs principales originales
  static const Color primaryColor = Colors.blue;
  static const Color secondaryColor = Color(0xFF0B7FE9);
  static const Color accentColor = Color(0xFF42A5F5);
  static const Color mediumGrey = Color.fromARGB(255, 200, 200, 200);

  // Couleurs pastel pour le dégradé
  static const Color pastelBlue = Color(0xFFE4F1FE);
  static const Color pastelPink = Color(0xFFFFF0F7);
  static const Color pastelPurple = Color(0xFFF5F0FF);

  // Couleurs de fond
  static const Color backgroundLight = Color(0xFFFCFCFF);
  static const Color backgroundDark = Color(0xFFF6F9FF);

  // Couleurs de texte
  static const Color textPrimary = Color(0xFF2D3748);
  static const Color textSecondary = Color(0xFF718096);

  // Couleurs d'état
  static const Color success = Color(0xFF48BB78);
  static const Color error = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFECC94B);

  // Dégradés
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, secondaryColor],
  );

  // Dégradé de fond subtil
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFFF8FDFF), // Blanc avec une touche de bleu
      Color(0xFFF0F8FF), // Bleu très clair
      Color(0xFFFFF0F8), // Rose très clair
    ],
    stops: [0.1, 0.6, 0.9],
  );

  // Ombres
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // Rayons de bordure
  static const double borderRadius = 12.0;

  // Thème clair (restauré selon le thème original)
  static ThemeData lightTheme = ThemeData(
    actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (BuildContext context) => const Icon(
              Icons.arrow_back_ios_new_outlined,
              size: 20,
            )),
    scaffoldBackgroundColor: Colors.grey[50],
    dialogBackgroundColor: Colors.grey[50],
    primarySwatch: Colors.blue,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    primaryColorLight: Colors.grey[50],
    primaryColorDark: Colors.black,
    textTheme: GoogleFonts.nunitoSansTextTheme(),
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

  // Méthode pour obtenir le conteneur avec dégradé de fond
  static Widget backgroundContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[50]),
      child: child,
    );
  }

  // Méthode pour créer une carte avec un dégradé subtil
  static Widget gradientCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // Méthode pour obtenir une carte moderne
  static Widget modernCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
