// lib/screens/checkout_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/screens/shop/order_confirmation_page.dart';
import 'package:provider/provider.dart';

import '../../services/cart_service.dart';
import '../../services/order_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final OrderService _orderService = OrderService();
  bool _isLoading = false;

  Future<void> _handlePayment(CartService cart) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print(cart.items.first.product.sellerId);
      final paymentIntentResult = await _orderService.createPaymentIntent(
        amount: (cart.total * 100).round(),
        currency: 'eur',
        connectAccountId: cart.items.first.product.sellerId,
      );

      // Configurer la feuille de paiement
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentResult['clientSecret'],
          merchantDisplayName: 'Your App Name',
          // Vous pouvez personnaliser davantage l'apparence ici
        ),
      );

      // Afficher la feuille de paiement
      await Stripe.instance.presentPaymentSheet();

      // Si nous arrivons ici, le paiement a réussi
      final user = _auth.currentUser;

      final orderId = await _orderService.createOrder(Orders(
        id: '',
        userId: user != null
            ? user.uid
            : '', // Remplacez par l'ID de l'utilisateur actuel
        sellerId: cart.items.first.product.sellerId,
        items: cart.items
            .map((item) => OrderItem(
                  productId: item.product.id,
                  name: item.product.name,
                  quantity: item.quantity,
                  price: item.product.price,
                ))
            .toList(),
        totalPrice: cart.total,
        status: 'paid',
        createdAt: DateTime.now(),
        pickupAddress: 'Adresse de retrait', // À remplacer par l'adresse réelle
      ));

      cart.clearCart();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(orderId: orderId)),
      );
    } on StripeException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur de paiement: ${e.error.localizedMessage}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Une erreur est survenue: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return ListTile(
                        title: Text(item.product.name),
                        trailing:
                            Text('${item.quantity} x ${item.product.price} €'),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Total: ${cart.total.toStringAsFixed(2)} €',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          child: const Text('Payer'),
                          onPressed: () => _handlePayment(cart),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
