import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:happy/widgets/product_card.dart';

class LikedProductsPage extends StatelessWidget {
  const LikedProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Vous devez être connecté')),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Mes coups de cœur',
        align: Alignment.center,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('likes')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun coup de cœur pour le moment',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Découvrir des produits'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final like = snapshot.data!.docs[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('products')
                    .doc(like['productId'])
                    .get(),
                builder: (context, productSnapshot) {
                  if (!productSnapshot.hasData) {
                    return const SizedBox();
                  }

                  if (!productSnapshot.data!.exists) {
                    FirebaseFirestore.instance
                        .collection('likes')
                        .doc(like.id)
                        .delete();
                    return const SizedBox();
                  }

                  final product = Product.fromFirestore(productSnapshot.data!);

                  return Dismissible(
                    key: Key(like.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) {
                      FirebaseFirestore.instance
                          .collection('likes')
                          .doc(like.id)
                          .delete();
                    },
                    child: ProductCard(
                      product: product,
                      width: double.infinity,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
