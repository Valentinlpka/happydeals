import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
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
    print('====== SIGN OUT DEBUG ======');
    try {
      // D'abord effacer les données
      final userModel = Provider.of<UserModel>(context, listen: false);
      print('Current user ID before clear: ${userModel.userId}');

      userModel.clearUserData();
      print('User data cleared');

      // Ensuite se déconnecter de Firebase
      await _auth.signOut();
      print('Firebase sign out successful');

      // Naviguer vers la page de connexion
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const Login()),
        (Route<dynamic> route) => false,
      );

      print('Navigation to login completed');
      print('==============================');
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  User? get currentUser => _auth.currentUser;
}
