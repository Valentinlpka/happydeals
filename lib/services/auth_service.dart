import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:provider/provider.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<String?> signUp(
      {required String email, required String password}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      await user?.sendEmailVerification();

      // Ne plus créer le document ici - il sera créé lors de l'onboarding
      
      return 'Success';
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signIn(
      {required String email,
      required String password,
      required BuildContext context}) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!result.user!.emailVerified) {
        await _auth.signOut();
        return 'Veuillez vérifier votre email avant de vous connecter';
      }
      if (!context.mounted) return 'Erreur lors de la connexion';
      await Provider.of<UserModel>(context, listen: false).loadUserData();

      // Initialiser FCM après une connexion réussie
      if (kIsWeb) {
        await updateFCMToken();
      }

      return 'Success';
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<bool> checkEmailVerified() async {
    User? user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  Future<void> resendVerificationEmail() async {
    User? user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      // Nettoyer les données de conversation
      final conversationService =
          Provider.of<ConversationService>(context, listen: false);
      await conversationService.cleanUp();

      // Nettoyer les données utilisateur
      if (!context.mounted) return;
      final userModel = Provider.of<UserModel>(context, listen: false);
      userModel.clearUserData();

      // Ensuite se déconnecter de Firebase
      await _auth.signOut();

      // Naviguer vers la page de connexion si le contexte est monté
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Login()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
    }
  }

  Future<void> updateFCMToken() async {
    if (!kIsWeb) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Demander d'abord la permission
        NotificationSettings settings =
            await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          String? token = await FirebaseMessaging.instance.getToken(
            vapidKey:
                'BJqxpGh0zaBedTU9JBdIQ8LrVUXetBpUBKT4wrrV_LXiI9vy0LwRa4_KCprNARbLEiV9gFnVipimUO5AN60XqSI',
          );

          if (token != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'fcmToken': token});

            debugPrint('FCM Token mis à jour: $token');
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur de mise à jour du token FCM: $e');
    }
  }

  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'error';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Vérifier si l'utilisateur existe déjà dans Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Nouveau utilisateur Google - sera redirigé vers l'onboarding
          // Le document sera créé lors de l'onboarding avec toutes les informations
          return 'new_user';
        }

        return 'success';
      }

      return 'error';
    } catch (e) {
      print('Erreur lors de la connexion Google: $e');
      return 'error';
    }
  }

  User? get currentUser => _auth.currentUser;
}
