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
          .where('isActive', isEqualTo: true)
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
            .map((doc) => Product.fromFirestore(doc))
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
    final mainVariant =
        product.variants.isNotEmpty ? product.variants[0] : null;
    final hasDiscount = mainVariant?.discount?.isValid() ?? false;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ModernProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(149, 157, 165, 0.2),
              blurRadius: 24,
              spreadRadius: 0,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mainVariant != null && mainVariant.images.isNotEmpty)
                Stack(
                  children: [
                    ClipRRect(
                      child: Image.network(
                        mainVariant.images[0],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (hasDiscount)
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
                            '-${mainVariant.discount!.value.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(width: 16),
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
                    if (mainVariant != null) ...[
                      const SizedBox(height: 4),
                      if (hasDiscount) ...[
                        Text(
                          '${mainVariant.price.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Text(
                          '${mainVariant.discount!.calculateDiscountedPrice(mainVariant.price).toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ] else
                        Text(
                          '${mainVariant.price.toStringAsFixed(2)} €',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue[800],
                          ),
                        ),
                      Text(
                        'Stock: ${mainVariant.stock}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  if (mainVariant != null && mainVariant.stock > 0)
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart),
                      onPressed: () async {
                        try {
                          // Si le produit a plusieurs variantes, afficher un dialogue de sélection
                          if (product.variants.length > 1) {
                            final selectedVariant =
                                await showDialog<ProductVariant>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Choisir une variante'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: product.variants
                                          .where((v) => v.stock > 0)
                                          .map((variant) {
                                        // Créer un label avec les attributs de la variante
                                        final attributes = variant
                                            .attributes.entries
                                            .map((e) => '${e.key}: ${e.value}')
                                            .join(', ');
                                        final price =
                                            variant.discount?.isValid() ?? false
                                                ? variant.discount!
                                                    .calculateDiscountedPrice(
                                                        variant.price)
                                                : variant.price;

                                        return ListTile(
                                          title: Text(attributes),
                                          subtitle: Text(
                                              '${price.toStringAsFixed(2)}€'),
                                          trailing:
                                              Text('Stock: ${variant.stock}'),
                                          onTap: () {
                                            Navigator.of(context).pop(variant);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            );

                            if (selectedVariant != null) {
                              context.read<CartService>().addToCart(
                                    product,
                                    variantId: selectedVariant.id,
                                  );
                            }
                          } else {
                            // Si une seule variante, l'ajouter directement
                            context.read<CartService>().addToCart(
                                  product,
                                  variantId: mainVariant.id,
                                );
                          }

                          // Afficher le message de confirmation
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text('Produit ajouté au panier'),
                                ],
                              ),
                              action: SnackBarAction(
                                label: 'VOIR LE PANIER',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const CartScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
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
