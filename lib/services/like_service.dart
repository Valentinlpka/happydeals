import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/match_market/liked_products_page.dart';

class LikeService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static void _showLikeToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Produit ajouté aux coups de cœur'),
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LikedProductsPage(),
              ),
            );
          },
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static Future<void> toggleLike(String productId, BuildContext context) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final likeQuery = await _firestore
        .collection('likes')
        .where('userId', isEqualTo: userId)
        .where('productId', isEqualTo: productId)
        .get();

    if (likeQuery.docs.isEmpty) {
      // Ajouter le like
      await _firestore.collection('likes').add({
        'userId': userId,
        'productId': productId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      _showLikeToast(context);
    } else {
      // Supprimer le like
      await _firestore
          .collection('likes')
          .doc(likeQuery.docs.first.id)
          .delete();
    }
  }

  static Stream<bool> isLiked(String productId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(false);

    return _firestore
        .collection('likes')
        .where('userId', isEqualTo: userId)
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }
}
