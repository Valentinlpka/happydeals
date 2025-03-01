import 'package:flutter/material.dart';
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/screens/shop/checkout_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du passage à la caisse: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        align: Alignment.center,
        title: 'Mes Paniers',
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          final activeCarts = cartService.activeCarts;

          if (activeCarts.isEmpty) {
            return const Center(child: Text('Vous n\'avez aucun panier actif'));
          }

          return ListView.builder(
            itemCount: activeCarts.length,
            itemBuilder: (context, cartIndex) {
              final cart = activeCarts[cartIndex];
              final remainingHours =
                  24 - DateTime.now().difference(cart.createdAt).inHours;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: Colors.blue[50],
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              cart.sellerName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'Expire dans: ${remainingHours}h',
                            style: TextStyle(
                              color: remainingHours < 2
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(
                              context,
                              cart,
                              cartService,
                            ),
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
                              Text(
                                'TVA: ${item.tva.toStringAsFixed(2)} %',
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
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
                            onPressed: () => _proceedToCheckout(context, cart),
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
      ),
    );
  }

  String _validateImageUrl(String url) {
    if (url.isEmpty) {
      return 'https://via.placeholder.com/50';
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
      print('Erreur de validation d\'URL: $e');
      return 'https://via.placeholder.com/50';
    }
  }

  Widget _buildProductImage(String imageUrl) {
    return Image.network(
      _validateImageUrl(imageUrl),
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('Erreur de chargement d\'image: $error');
        return const Icon(Icons.image_not_supported);
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}
