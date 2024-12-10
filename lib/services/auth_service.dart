import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/auth/login_page.dart';
import 'package:provider/provider.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> signUp(
      {required String email, required String password}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      await _firestore.collection('users').doc(user!.uid).set({
        'email': email,
        'isProfileComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

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
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await Provider.of<UserModel>(context, listen: false).loadUserData();
      return 'Success';
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      // Nettoyer les données de conversation
      final conversationService =
          Provider.of<ConversationService>(context, listen: false);
      await conversationService.cleanUp();

      // Nettoyer les données utilisateur
      final userModel = Provider.of<UserModel>(context, listen: false);
      userModel.clearUserData();

      // Ensuite se déconnecter de Firebase
      await _auth.signOut();

      // Naviguer vers la page de connexion
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
        (Route<dynamic> route) => false,
      );

    } catch (e) {
    }
  }

  User? get currentUser => _auth.currentUser;
}
