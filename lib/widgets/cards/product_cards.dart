import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/config/app_router.dart';

class ProductCards extends StatelessWidget {
  final ProductPost post;
  final String companyName;
  final String companyLogo;

  const ProductCards({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
  });

  Future<Product?> _getProduct(String productId) async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (productDoc.exists) {
        return Product.fromFirestore(productDoc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(child: CircularProgressIndicator());
          },
        );

        try {
          final product = await _getProduct(post.productId);
          if (!context.mounted) return;
          Navigator.pop(context);
          if (product != null && context.mounted) {
            Navigator.pushNamed(
              context,
              AppRouter.productDetails,
              arguments: {
                'product': product,
              },
            );
          }
        } catch (e) {
          Navigator.pop(context);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur de chargement du produit')),
            );
          }
        }
      },
      child: Column(
        children: [
          // Image du produit
          if (post.variants.isNotEmpty && post.variants[0].images.isNotEmpty)
            Hero(
              tag: 'product-card-${post.productId}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.variants[0].images[0],
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported,
                              size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Image non disponible',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

          // Informations du produit
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom du produit
                Text(
                  post.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  post.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Prix
                if (post.variants.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (post.variants[0].discount?.isValid() ?? false) ...[
                        Text(
                          "${post.variants[0].discount!.calculateDiscountedPrice(post.variants[0].price).toStringAsFixed(2)} €",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${post.variants[0].price.toStringAsFixed(2)} €",
                          style: TextStyle(
                            fontSize: 16,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[500],
                          ),
                        ),
                      ] else
                        Text(
                          "${post.variants[0].price.toStringAsFixed(2)} €",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
