import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/auth_page.dart';
import 'package:happy/screens/auth/email_verification_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:provider/provider.dart';

/// Widget qui gère l'état d'authentification et redirige vers les écrans appropriés
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Afficher immédiatement la page de connexion si pas d'utilisateur
        if (!snapshot.hasData) {
          return const AuthPage();
        }

        // Si l'utilisateur n'est pas vérifié, afficher la page de vérification
        if (!snapshot.data!.emailVerified) {
          return const EmailVerificationPage();
        }

        // Pour les utilisateurs connectés et vérifiés
        return FutureBuilder(
          future: _initializeUserData(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Erreur: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            return const MainContainer();
          },
        );
      },
    );
  }

  /// Initialise les données utilisateur après la connexion
  Future<void> _initializeUserData(BuildContext context) async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    await userModel.loadUserData();
  }
}

// Widget de chargement optimisé
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

// Widget d'erreur
class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erreur: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthWrapper()),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
