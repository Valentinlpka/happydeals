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
                // Icône personnalisée
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
                // Message
                const Text(
                  'Êtes-vous sûr de vouloir\nsupprimer ce panier ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                // Boutons
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
              final remainingTime = cart.expiresAt.difference(DateTime.now());

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // En-tête du panier
                    Container(
                      color: Colors.blue[50],
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                'Expire dans: ${remainingTime.inMinutes}min',
                                style: TextStyle(
                                  color: remainingTime.inMinutes < 30
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.close, color: Colors.red),
                                onPressed: () => _showDeleteConfirmation(
                                  context,
                                  cart,
                                  cartService,
                                ),
                              ),
                            ],
                          ),
                          if (cart.totalSavings > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Économies: ${cart.totalSavings.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Liste des articles
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.items.length,
                      itemBuilder: (context, itemIndex) {
                        final item = cart.items[itemIndex];
                        return ListTile(
                          leading: Image.network(
                            item.product.imageUrl[0],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                          title: Text(item.product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item.product.hasActiveHappyDeal &&
                                  item.product.discountedPrice != null)
                                Text(
                                  '${item.product.price.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                              Text(
                                '${item.appliedPrice.toStringAsFixed(2)} €',
                                style: TextStyle(
                                  color: item.product.hasActiveHappyDeal
                                      ? Colors.red
                                      : null,
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
                                ),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  try {
                                    await cartService.addToCart(item.product);
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

                    // Pied du panier avec total et bouton d'achat
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
                              'Payer ce panier (${cart.totalAfterDiscount.toStringAsFixed(2)} €)',
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

  void _proceedToCheckout(BuildContext context, Cart cart) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(cart: cart),
      ),
    );
  }
}
