import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class LikeProvider with ChangeNotifier {
  final likeList = [];

  Future<void> handleLike(Post post, String currentUserId) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(post.id);
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(currentUserId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final postSnapshot = await transaction.get(postRef);
      final userSnapshot = await transaction.get(userRef);

      if (!postSnapshot.exists || !userSnapshot.exists) {
        throw Exception("Document does not exist!");
      }

      final List<String> likedBy = List<String>.from(postSnapshot['likedBy']);
      final int likes = postSnapshot['likes'];

      if (likedBy.contains(currentUserId)) {
        likeList.remove(currentUserId);

        likedBy.remove(currentUserId);
        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': likes - 1,
        });
        transaction.update(userRef, {
          'likedPosts': FieldValue.arrayRemove([post.id])
        });
      } else {
        likeList.add(currentUserId);
        likedBy.add(currentUserId);
        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': likes + 1,
        });
        transaction.update(userRef, {
          'likedPosts': FieldValue.arrayUnion([post.id])
        });
      }
    });

    notifyListeners(); // Notify listeners after state change
  }
}
