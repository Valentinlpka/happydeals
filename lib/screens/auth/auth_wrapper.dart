import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
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
    try {
      final userModel = Provider.of<UserModel>(context, listen: false);
      final conversationService =
          Provider.of<ConversationService>(context, listen: false);
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final savedAdsProvider =
          Provider.of<SavedAdsProvider>(context, listen: false);

      // Réinitialiser de manière asynchrone
      await Future.wait([
        Future(() => homeProvider.reset()),
        Future(() => userModel.clearUserData()),
        conversationService.cleanUp(),
        Future(() => savedAdsProvider.reset()),
      ]);

      // Charger les nouvelles données
      await userModel.loadUserData();
      await conversationService.initializeForUser(userModel.userId);
      await savedAdsProvider.initializeSavedAds(userModel.userId);

      // Charger le feed initial si nécessaire
      if (userModel.likedCompanies.isNotEmpty ||
          userModel.followedUsers.isNotEmpty) {
        await homeProvider.loadUnifiedFeed(
          userModel.likedCompanies,
          userModel.followedUsers,
          refresh: true,
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de l\'initialisation des données utilisateur: $e');
      rethrow;
    }
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
