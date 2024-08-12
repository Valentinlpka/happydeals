import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/screens/shop/checkout_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon Panier')),
      body: Consumer<CartService>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return const Center(child: Text('Votre panier est vide'));
          }
          return ListView.builder(
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return ListTile(
                leading: Image.network(item.product.imageUrl[0]),
                title: Text(item.product.name),
                subtitle: Text('${item.product.price} €'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => cart.removeFromCart(item.product),
                    ),
                    Text('${item.quantity}'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        try {
                          await cart.addToCart(item.product);
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
          );
        },
      ),
      bottomNavigationBar: Consumer<CartService>(
        builder: (context, cart, child) {
          return SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(
                width: 0.4,
                color: Colors.black26,
              ))),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.blue[800]),
                    ),
                    onPressed: cart.items.isNotEmpty
                        ? () => _proceedToCheckout(context, cart)
                        : null,
                    child: Text('Acheter (${cart.total.toStringAsFixed(2)} €)'),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _proceedToCheckout(BuildContext context, CartService cart) {
    if (kIsWeb) {
      // Sauvegarde des données du panier pour le web
      final cartData = cart.items
          .map((item) => {
                'productId': item.product.id,
                'name': item.product.name,
                'quantity': item.quantity,
                'price': item.product.price,
                'sellerId': item.product.sellerId,
                'entrepriseId': item.product.entrepriseId,
                'imageUrl': item.product.imageUrl,
                'description': item.product.description,
                'stock': item.product.stock,
                'isActive': item.product.isActive,
              })
          .toList();

      final cartDataJson = json.encode(cartData);
      html.window.localStorage['cartData'] = cartDataJson;
      html.window.localStorage['cartTotal'] = cart.total.toString();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );
  }
}
