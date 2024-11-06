import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/cart_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:provider/provider.dart';

class ProductList extends StatelessWidget {
  final String sellerId;

  const ProductList({super.key, required this.sellerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('merchantId', isEqualTo: sellerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Aucun produit trouvé'));
        }

        final products = snapshot.data!.docs
            .map((doc) => Product.fromDocument(doc))
            .toList();

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return ProductListItem(product: products[index]);
          },
        );
      },
    );
  }
}

class ProductListItem extends StatelessWidget {
  final Product product;

  const ProductListItem({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final bool hasActiveHappyDeal =
        product.hasActiveHappyDeal && product.discountedPrice != null;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(149, 157, 165, 0.2),
            blurRadius: 24,
            spreadRadius: 0,
            offset: Offset(0, 8),
          ),
        ]),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image du produit
              Stack(
                children: [
                  ClipRRect(
                    child: Image.network(
                      product.imageUrl[0],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (hasActiveHappyDeal)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${product.discountPercentage?.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Informations du produit
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hasActiveHappyDeal) ...[
                      Text(
                        '${product.price.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      Text(
                        '${product.discountedPrice!.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                        ),
                      ),
                    ] else
                      Text(
                        '${product.price.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue[800],
                        ),
                      ),
                  ],
                ),
              ),
              // Bouton d'ajout au panier
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart),
                    onPressed: () {
                      try {
                        context.read<CartService>().addToCart(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Produit ajouté',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Votre produit a été ajouté au panier',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.blue[800],
                            duration: const Duration(seconds: 4),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            action: SnackBarAction(
                              label: 'VOIR LE PANIER',
                              textColor: Colors.white,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const CartScreen()),
                                );
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
