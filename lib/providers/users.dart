import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';

class Users with ChangeNotifier {
  String userId = "";
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

        likeList.clear();

        if (data != null && data['likedPosts'] != null) {
          likeList.addAll(data['likedPosts'].cast<String>());
          notifyListeners();
        }
      }
    });
  }

  void logout() {
    userId = "";
    likeList.clear();
  }

  Future<void> handleLike(Post post) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    // Optimistically update the local state
    if (likeList.contains(post.id)) {
      likeList.remove(post.id);
      post.likes -= 1;
    } else {
      likeList.add(post.id);
      post.likes += 1;
    }
    notifyListeners();

    // Firestore update in the background
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        final userSnapshot = await transaction.get(userRef);

        if (!postSnapshot.exists || !userSnapshot.exists) {
          throw Exception("Document does not exist!");
        }

        final List<String> likedBy = List<String>.from(postSnapshot['likedBy']);
        final int likes = postSnapshot['likes'];

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likes': likes - 1,
          });
          transaction.update(userRef, {
            'likedPosts': FieldValue.arrayRemove([post.id])
          });
        } else {
          likedBy.add(userId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likes': likes + 1,
          });
          transaction.update(userRef, {
            'likedPosts': FieldValue.arrayUnion([post.id])
          });
        }
      });
    } catch (e) {
      // Revert the optimistic update if the Firestore transaction fails
      if (likeList.contains(post.id)) {
        likeList.remove(post.id);
        post.likes -= 1;
      } else {
        likeList.add(post.id);
        post.likes += 1;
      }
      notifyListeners();
    }
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
