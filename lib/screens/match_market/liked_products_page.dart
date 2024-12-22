import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/product_detail_page.dart';

class LikedProductsPage extends StatelessWidget {
  const LikedProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    print('Current userId: $userId');

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Vous devez être connecté')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes coups de cœur'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('likes')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          print('Snapshot hasData: ${snapshot.hasData}');
          print('Snapshot hasError: ${snapshot.hasError}');
          if (snapshot.hasError) print('Snapshot error: ${snapshot.error}');

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          print('Number of likes: ${snapshot.data!.docs.length}');

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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final like = snapshot.data!.docs[index];
              print('Loading product details for like: ${like.id}');

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('products')
                    .doc(like['productId'])
                    .get(),
                builder: (context, productSnapshot) {
                  print(
                      'Product snapshot for ${like['productId']} - hasData: ${productSnapshot.hasData}');
                  if (productSnapshot.hasError) {
                    print('Error loading product: ${productSnapshot.error}');
                  }

                  if (!productSnapshot.hasData) {
                    return const SizedBox(height: 100);
                  }

                  if (!productSnapshot.data!.exists) {
                    // Le produit a été supprimé
                    FirebaseFirestore.instance
                        .collection('likes')
                        .doc(like.id)
                        .delete();
                    return const SizedBox();
                  }

                  final product = Product.fromFirestore(productSnapshot.data!);
                  final mainVariant =
                      product.variants.isNotEmpty ? product.variants[0] : null;
                  if (mainVariant == null) return const SizedBox();

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
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ModernProductDetailPage(product: product),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(12)),
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: mainVariant.images.isNotEmpty
                                    ? Image.network(
                                        mainVariant.images[0],
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.image, size: 40),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${mainVariant.price.toStringAsFixed(2)}€',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (product.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        product.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
