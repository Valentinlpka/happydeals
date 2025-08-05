import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/home_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/auth_page.dart';
import 'package:happy/screens/auth/email_verification_page.dart';
import 'package:happy/screens/auth/onboarding_questionnaire_page.dart';
import 'package:happy/screens/main_container.dart';
import 'package:provider/provider.dart';

/// Widget qui gère l'état d'authentification et redirige vers les écrans appropriés
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🔍 AuthWrapper: build() appelé');
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('🔍 StreamBuilder: snapshot.hasData = ${snapshot.hasData}');
        debugPrint('🔍 StreamBuilder: connectionState = ${snapshot.connectionState}');
        
        // État de connexion en cours
        if (snapshot.connectionState == ConnectionState.waiting) {
          debugPrint('🔍 Affichage: Loading spinner (connexion en cours)');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connexion...'),
                ],
              ),
            ),
          );
        }

        // Afficher immédiatement la page de connexion si pas d'utilisateur
        if (!snapshot.hasData || snapshot.data == null) {
          debugPrint('🔍 Affichage: AuthPage (pas d\'utilisateur)');
          return const AuthPage();
        }

        final user = snapshot.data!;
        debugPrint('🔍 Utilisateur connecté: ${user.uid}');
        debugPrint('🔍 Email: ${user.email}, vérifié: ${user.emailVerified}');
        debugPrint('🔍 Téléphone: ${user.phoneNumber}');
        
        // Vérifier si l'utilisateur doit vérifier son email
        bool needsEmailVerification = user.email != null && 
                                    user.email!.isNotEmpty && 
                                    !user.emailVerified && 
                                    (user.phoneNumber == null || user.phoneNumber!.isEmpty);
        
        if (needsEmailVerification) {
          debugPrint('🔍 Affichage: EmailVerificationPage');
          return const EmailVerificationPage();
        }

        // Pour les utilisateurs connectés et vérifiés (email ou téléphone)
        debugPrint('🔍 Vérification du statut onboarding...');
        return FutureBuilder<bool>(
          future: _checkOnboardingStatus(user),
          builder: (context, onboardingSnapshot) {
            debugPrint('🔍 Onboarding check: ${onboardingSnapshot.connectionState}');
            
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              debugPrint('🔍 Affichage: Loading onboarding check');
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Vérification du profil...'),
                    ],
                  ),
                ),
              );
            }

            if (onboardingSnapshot.hasError) {
              debugPrint('🔍 Erreur onboarding: ${onboardingSnapshot.error}');
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Erreur onboarding: ${onboardingSnapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Forcer le rebuild
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const AuthWrapper()),
                          );
                        },
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Si l'utilisateur n'a pas terminé l'onboarding, le rediriger
            if (onboardingSnapshot.data == false) {
              debugPrint('🔍 Affichage: OnboardingQuestionnairePage');
              return const OnboardingQuestionnairePage();
            }

            debugPrint('🔍 Onboarding terminé, initialisation des données...');
            // Si l'onboarding est terminé, initialiser les données utilisateur
            return FutureBuilder(
              future: _initializeUserData(context),
              builder: (context, snapshot) {
                debugPrint('🔍 User data init: ${snapshot.connectionState}');
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  debugPrint('🔍 Affichage: Loading user data');
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Chargement des données...'),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  debugPrint('🔍 Erreur user data: ${snapshot.error}');
                  return Scaffold(
                    body: Center(
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
                    ),
                  );
                }

                debugPrint('🔍 Affichage: MainContainer');
                return const MainContainer();
              },
            );
          },
        );
      },
    );
  }

  /// Initialise les données utilisateur après la connexion
  Future<void> _initializeUserData(BuildContext context) async {
    try {
      debugPrint('🔍 Début initialisation données utilisateur');
      
      final userModel = Provider.of<UserModel>(context, listen: false);
      final conversationService = Provider.of<ConversationService>(context, listen: false);
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final savedAdsProvider = Provider.of<SavedAdsProvider>(context, listen: false);

      debugPrint('🔍 Providers récupérés');

      // Réinitialiser de manière asynchrone avec timeout
      debugPrint('🔍 Réinitialisation des providers...');
      await Future.wait([
        Future(() => homeProvider.reset()),
        Future(() => userModel.clearUserData()),
        conversationService.cleanUp(),
        Future(() => savedAdsProvider.reset()),
      ]).timeout(const Duration(seconds: 10));

      debugPrint('🔍 Reset terminé, chargement des données...');

      // Charger les nouvelles données avec timeout
      await userModel.loadUserData().timeout(const Duration(seconds: 15));
      debugPrint('🔍 UserModel chargé');
      
      await conversationService.initializeForUser(userModel.userId).timeout(const Duration(seconds: 10));
      debugPrint('🔍 ConversationService initialisé');
      
      await savedAdsProvider.initializeSavedAds(userModel.userId).timeout(const Duration(seconds: 10));
      debugPrint('🔍 SavedAdsProvider initialisé');

      // Charger le feed initial si nécessaire
      if (userModel.likedCompanies.isNotEmpty || userModel.followedUsers.isNotEmpty) {
        debugPrint('🔍 Chargement du feed...');
        await homeProvider.loadUnifiedFeed(
          userModel.likedCompanies,
          userModel.followedUsers,
          refresh: true,
        ).timeout(const Duration(seconds: 15));
        debugPrint('🔍 Feed chargé');
      }

      debugPrint('🔍 ✅ Initialisation terminée avec succès');
    } catch (e) {
      debugPrint('🔍 ❌ Erreur lors de l\'initialisation des données utilisateur: $e');
      rethrow;
    }
  }

  /// Vérifie si l'utilisateur a terminé son onboarding
  Future<bool> _checkOnboardingStatus(User user) async {
    try {
      debugPrint('🔍 Vérification onboarding pour ${user.uid}');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));
      
      debugPrint('🔍 Document utilisateur récupéré: exists=${userDoc.exists}');
      
      // Si le document n'existe pas, l'utilisateur n'a pas terminé l'onboarding
      if (!userDoc.exists) {
        debugPrint('🔍 Document n\'existe pas, onboarding non terminé');
        return false;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final completed = userData['onboardingCompleted'] == true;
      debugPrint('🔍 onboardingCompleted: $completed');
      
      return completed;
    } catch (e) {
      debugPrint('🔍 ❌ Erreur vérification onboarding: $e');
      // En cas d'erreur, on considère que l'onboarding n'est pas terminé
      return false;
    }
  }
}