import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/auth_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

/// Widget qui gère l'état d'authentification et redirige vers les écrans appropriés
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
            future: _initializeUserData(context),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Erreur d\'initialisation: ${snapshot.error}'),
                );
              }

              return const MainContainer();
            },
          );
        }

        return const AuthPage();
      },
    );
  }

  /// Initialise les données utilisateur après la connexion
  Future<void> _initializeUserData(BuildContext context) async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    await userModel.loadUserData();
  }
}
