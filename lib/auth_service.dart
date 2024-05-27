import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final db = FirebaseFirestore.instance;
  Future<String?> registration({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = FirebaseAuth.instance.currentUser!;
      db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'username': username,
      });

      return 'Success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'The account already exists for that email.';
      } else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      FirebaseAuth.instance.authStateChanges().listen((event) {});
      return 'Success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided for that user.';
      } else if (e.code == 'INVALID_LOGIN_CREDENTIALS') {
        return 'Votre email ou votre mot de passe est incorrect !';
      } else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }
}
