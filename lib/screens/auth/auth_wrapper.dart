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
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, 
                              color: Colors.orange, size: 64),
                          const SizedBox(height: 24),
                          const Text(
                            'Vérification du profil',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Problème lors de la vérification de votre profil.\nVeuillez patienter ou réessayer.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await FirebaseAuth.instance.signOut();
                                    } catch (e) {
                                      debugPrint('Erreur lors de la déconnexion: $e');
                                    }
                                  },
                                  child: const Text('Se déconnecter'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Forcer le rebuild
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const AuthWrapper()),
                                    );
                                  },
                                  child: const Text('Réessayer'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              // En cas de problème persistant, permettre de continuer
                              debugPrint('🔍 Forçage de l\'accès à l\'application');
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const MainContainer()),
                              );
                            },
                            child: const Text(
                              'Continuer quand même',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 24),
                          const Text(
                            'Problème de connexion',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Impossible de charger vos données.\nVérifiez votre connexion internet et réessayez.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await FirebaseAuth.instance.signOut();
                                    } catch (e) {
                                      debugPrint('Erreur lors de la déconnexion: $e');
                                    }
                                  },
                                  child: const Text('Se déconnecter'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                                  ),
                                  child: const Text('Réessayer'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
      
      // Vérifier que le contexte est toujours valide
      if (!context.mounted) {
        debugPrint('🔍 ❌ Contexte non monté, abandon de l\'initialisation');
        return;
      }

      final userModel = Provider.of<UserModel>(context, listen: false);
      final conversationService = Provider.of<ConversationService>(context, listen: false);
      final homeProvider = Provider.of<HomeProvider>(context, listen: false);
      final savedAdsProvider = Provider.of<SavedAdsProvider>(context, listen: false);

      debugPrint('🔍 Providers récupérés');

      // Réinitialiser de manière asynchrone avec timeout plus long pour Android
      debugPrint('🔍 Réinitialisation des providers...');
      try {
        await Future.wait([
          Future(() => homeProvider.reset()),
          Future(() => userModel.clearUserData()),
          Future(() => conversationService.cleanUp()),
          Future(() => savedAdsProvider.reset()),
        ]).timeout(const Duration(seconds: 20)); // Timeout augmenté pour Android
      } catch (e) {
        debugPrint('🔍 ⚠️ Erreur lors du reset (non critique): $e');
        // Continuer même si le reset échoue
      }

      debugPrint('🔍 Reset terminé, chargement des données...');

      // Charger les nouvelles données avec timeout plus long et gestion d'erreur
      try {
        await userModel.loadUserData().timeout(const Duration(seconds: 30)); // Timeout augmenté
        debugPrint('🔍 UserModel chargé');
      } catch (e) {
        debugPrint('🔍 ❌ Erreur UserModel: $e');
        throw Exception('Erreur lors du chargement du profil utilisateur');
      }
      
      // Vérifier que le contexte est toujours valide avant de continuer
      if (!context.mounted) {
        debugPrint('🔍 ❌ Contexte non monté après loadUserData');
        return;
      }

      // Initialiser les services de manière non-bloquante
      try {
        await Future.wait([
          conversationService.initializeForUser(userModel.userId)
              .timeout(const Duration(seconds: 15))
              .catchError((e) {
                debugPrint('🔍 ⚠️ Erreur ConversationService: $e');
                return Future.value(); // Continuer même si ça échoue
              }),
          savedAdsProvider.initializeSavedAds(userModel.userId)
              .timeout(const Duration(seconds: 15))
              .catchError((e) {
                debugPrint('🔍 ⚠️ Erreur SavedAdsProvider: $e');
                return Future.value(); // Continuer même si ça échoue
              }),
        ]);
        debugPrint('🔍 Services initialisés');
      } catch (e) {
        debugPrint('🔍 ⚠️ Erreur services (non critique): $e');
        // Continuer même si les services échouent
      }

      // Charger le feed initial de manière optionnelle
      if (userModel.likedCompanies.isNotEmpty || userModel.followedUsers.isNotEmpty) {
        debugPrint('🔍 Chargement du feed...');
        try {
          await homeProvider.loadUnifiedFeed(
            userModel.likedCompanies,
            userModel.followedUsers,
            refresh: true,
          ).timeout(const Duration(seconds: 20));
          debugPrint('🔍 Feed chargé');
        } catch (e) {
          debugPrint('🔍 ⚠️ Erreur feed (non critique): $e');
          // Le feed peut être chargé plus tard
        }
      }

      debugPrint('🔍 ✅ Initialisation terminée avec succès');
    } catch (e) {
      debugPrint('🔍 ❌ Erreur lors de l\'initialisation des données utilisateur: $e');
      // Ne pas rethrow, mais retourner une erreur plus spécifique
      throw Exception('Impossible de charger les données utilisateur. Veuillez réessayer.');
    }
  }

  /// Vérifie si l'utilisateur a terminé son onboarding
  Future<bool> _checkOnboardingStatus(User user) async {
    try {
      debugPrint('🔍 Vérification onboarding pour ${user.uid}');
      
      // Timeout plus long pour Android et gestion d'erreur améliorée
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
            const Duration(seconds: 20), // Timeout augmenté pour Android
            onTimeout: () {
              debugPrint('🔍 ⏰ Timeout lors de la récupération du document utilisateur');
              throw Exception('Timeout lors de la vérification du profil');
            },
          );
      
      debugPrint('🔍 Document utilisateur récupéré: exists=${userDoc.exists}');
      
      // Si le document n'existe pas, l'utilisateur n'a pas terminé l'onboarding
      if (!userDoc.exists) {
        debugPrint('🔍 Document n\'existe pas, onboarding non terminé');
        return false;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        debugPrint('🔍 Données utilisateur nulles, onboarding non terminé');
        return false;
      }
      
      final completed = userData['onboardingCompleted'] == true;
      debugPrint('🔍 onboardingCompleted: $completed');
      
      return completed;
    } catch (e) {
      debugPrint('🔍 ❌ Erreur vérification onboarding: $e');
      // En cas d'erreur réseau ou timeout, permettre à l'utilisateur de continuer
      // mais loguer l'erreur pour investigation
      if (e.toString().contains('timeout') || e.toString().contains('network')) {
        debugPrint('🔍 ⚠️ Erreur réseau détectée, autorisation de continuer');
        return true; // Laisser l'utilisateur continuer en cas de problème réseau
      }
      return false;
    }
  }
}