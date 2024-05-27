import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Users with ChangeNotifier {
  String? userId;
  final List<String> likeList = [];

  void login() {
    if (FirebaseAuth.instance.currentUser != null) {
      userId = FirebaseAuth.instance.currentUser!.uid;
    }

    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get()
        .then((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();

        if (data != null && data['posts_liked'] != null) {
          likeList.addAll(data['posts_liked'].cast<String>());
          notifyListeners();
        }
      }
    });
  }

  void logout() {
    userId = null;
    likeList.clear();
  }

  Future<void> likePost(String postId) async {
    likeList.add(postId);
    notifyListeners();

    try {
      // Ajouter le like dans la collection "Utilisateurs"
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'posts_liked': FieldValue.arrayUnion([postId]),
      }, SetOptions(merge: true));

      // Ajouter le like dans la collection "Posts"
      await FirebaseFirestore.instance.collection('companys').doc(postId).set({
        'liked_by': FieldValue.arrayUnion([userId]),
      }, SetOptions(merge: true));
    } catch (e) {
      likeList.remove(postId);
      notifyListeners();
    }
  }

  Future<void> unlikePost(String postId) async {
    likeList.remove(postId);
    notifyListeners();

    try {
      // Ajouter le like dans la collection "Utilisateurs"
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'posts_liked': FieldValue.arrayRemove([postId]),
      }, SetOptions(merge: true));

      // Ajouter le like dans la collection "Posts"
      await FirebaseFirestore.instance.collection('companys').doc(postId).set({
        'liked_by': FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true));
      notifyListeners();
    } catch (e) {
      likeList.add(postId);
      notifyListeners();
    }
  }
}
