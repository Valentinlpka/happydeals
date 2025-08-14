import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/screens/shop/checkout_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Rayon de la Terre en kilomètres

    // Conversion en radians
    final double lat1Rad = lat1 * math.pi / 180;
    final double lon1Rad = lon1 * math.pi / 180;
    final double lat2Rad = lat2 * math.pi / 180;
    final double lon2Rad = lon2 * math.pi / 180;

    // Différence de longitude et latitude
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;

    // Formule de Haversine
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  void _showDeleteConfirmation(
      BuildContext context, Cart cart, CartService cartService) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Êtes-vous sûr de vouloir\nsupprimer ce panier ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        cartService.deleteCart(cart.sellerId);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Supprimer',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _proceedToCheckout(BuildContext context, Cart cart) {
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre panier est vide')),
      );
      return;
    }

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            key: UniqueKey(),
            cart: cart,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du passage à la caisse: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          final activeCarts = cartService.activeCarts;
          final userModel = Provider.of<UserModel>(context);

          if (activeCarts.isEmpty) {
            return const Center(child: Text('Vous n\'avez aucun panier actif'));
          }

          return ListView.builder(
            itemCount: activeCarts.length,
            itemBuilder: (context, cartIndex) {
              final cart = activeCarts[cartIndex];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('companys')
                    .doc(cart.sellerId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox();
                  }

                  final companyData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  final companyAddress =
                      companyData['adress'] as Map<String, dynamic>;

                  double distance = 0;
                  if (userModel.latitude != 0 && userModel.longitude != 0) {
                    // Conversion des coordonnées string en double
                    final companyLat = double.tryParse(companyAddress['latitude'].toString()) ?? 0.0;
                    final companyLng = double.tryParse(companyAddress['longitude'].toString()) ?? 0.0;
                    
                    distance = calculateDistance(
                      userModel.latitude,
                      userModel.longitude,
                      companyLat,
                      companyLng,
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Colors.blue[50],
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: const Color(0xFF3476B2),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundImage:
                                        NetworkImage(companyData['logo'] ?? ''),
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      companyData['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      spacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            companyData['categorie'] ?? '',
                                            style: TextStyle(
                                              color: Colors.blue[900],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${companyAddress['ville']} • ${distance.toStringAsFixed(1)} km',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.red),
                                    onPressed: () => _showDeleteConfirmation(
                                      context,
                                      cart,
                                      cartService,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cart.items.length,
                          itemBuilder: (context, itemIndex) {
                            final item = cart.items[itemIndex];
                            final hasDiscount =
                                item.variant.discount?.isValid() ?? false;

                            return ListTile(
                              leading: item.variant.images.isNotEmpty
                                  ? _buildProductImage(item.variant.images[0])
                                  : const Icon(Icons.image_not_supported),
                              title: Text(item.product.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.variant.attributes.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(', '),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (hasDiscount)
                                    Text(
                                      '${item.variant.price.toStringAsFixed(2)} €',
                                      style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    '${item.appliedPrice.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      color: hasDiscount ? Colors.red : null,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () => cartService.removeFromCart(
                                      cart.sellerId,
                                      item.product.id,
                                      item.variant.id,
                                    ),
                                  ),
                                  Text('${item.quantity}'),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () async {
                                      try {
                                        await cartService.addToCart(
                                          item.product,
                                          variantId: item.variant.id,
                                        );
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(e.toString())),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              if (cart.discountAmount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    'Code promo appliqué: -${cart.discountAmount.toStringAsFixed(2)} €',
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[800],
                                  minimumSize: const Size(double.infinity, 50),
                                ),
                                onPressed: () =>
                                    _proceedToCheckout(context, cart),
                                child: Text(
                                  'Payer ce panier (${cart.finalTotal.toStringAsFixed(2)} €)',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  String _validateImageUrl(String url) {
    if (url.isEmpty) {
      return '';
    }

    try {
      // Convertir l'URL en Uri pour la validation et l'encodage
      var uri = Uri.parse(url);

      // Si l'URL est relative (commence par '/'), ajoutez le domaine de base
      if (url.startsWith('/')) {
        return 'https://votre-domaine.com$url';
      }

      // S'assurer que l'URL utilise HTTPS pour iOS
      if (uri.scheme == 'http') {
        uri = uri.replace(scheme: 'https');
      }

      // Si aucun schéma n'est spécifié, ajouter HTTPS
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return 'https://$url';
      }

      // Encoder l'URL pour gérer les caractères spéciaux
      return uri.toString();
    } catch (e) {
      debugPrint('Erreur de validation d\'URL: $e');
      return '';
    }
  }

  Widget _buildProductImage(String imageUrl) {
    final validatedUrl = _validateImageUrl(imageUrl);

    if (validatedUrl.isEmpty) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.grey[100],
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: Colors.grey,
          size: 24,
        ),
      );
    }

    return Image.network(
      validatedUrl,
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 50,
          height: 50,
          color: Colors.grey[100],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Erreur de chargement d\'image: $error');
        return Container(
          width: 50,
          height: 50,
          color: Colors.grey[100],
          child: const Icon(
            Icons.image_not_supported,
            color: Colors.grey,
            size: 24,
          ),
        );
      },
    );
  }
}
