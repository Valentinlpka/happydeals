import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/order_confirmation_page.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/services/order_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  _PaymentSuccessScreenState createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrderService _orderService = OrderService();
  bool _isLoading = true;
  String _statusMessage = 'Vérification du paiement en cours...';

  @override
  void initState() {
    super.initState();
    _verifyPaymentAndFinalizeOrder();
  }

  Future<void> _verifyPaymentAndFinalizeOrder() async {
    try {
      CartService cart;
      if (kIsWeb) {
        // Récupération et reconstruction du panier depuis le localStorage
        final cartDataJson = html.window.localStorage['cartData'];
        final cartTotal =
            double.parse(html.window.localStorage['cartTotal'] ?? '0');
        if (cartDataJson != null) {
          final cartData = json.decode(cartDataJson) as List<dynamic>;
          cart = CartService();
          for (var item in cartData) {
            final product = Product(
              id: item['productId'],
              name: item['name'],
              description: item['description'] ??
                  '', // Utilisez une valeur par défaut si non sauvegardée
              price: item['price'],
              imageUrl: (item['imageUrl'] as List<dynamic>?)?.cast<String>() ??
                  [], // Conversion en List<String> avec valeur par défaut
              sellerId: item['sellerId'],
              entrepriseId: item['entrepriseId'],
              stock: item['stock'] ??
                  0, // Utilisez une valeur par défaut si non sauvegardée
              isActive: item['isActive'] ??
                  true, // Utilisez une valeur par défaut si non sauvegardée
            );
            cart.addToCart(product);
            // Ajuster la quantité si nécessaire
            if (item['quantity'] > 1) {
              for (int i = 1; i < item['quantity']; i++) {
                cart.addToCart(product);
              }
            }
          }
        } else {
          throw Exception('Cart data not found');
        }
      } else {
        cart = Provider.of<CartService>(context, listen: false);
      }

      setState(() {
        _statusMessage = 'Paiement confirmé. Finalisation de la commande...';
      });
      await _finalizeOrder(cart);
    } catch (e) {
      _handleError('Une erreur inattendue est survenue: $e', '/home');
    } finally {
      if (kIsWeb) {
        html.window.localStorage.remove('cartData');
        html.window.localStorage.remove('cartTotal');
        html.window.localStorage.remove('stripeSessionId');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleError(String message, String redirectRoute) {
    setState(() {
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed(redirectRoute);
    });
  }

  Future<void> _finalizeOrder(CartService cart) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final address =
        await _fetchCompanyAddress(cart.items.first.product.entrepriseId);

    final orderId = await _orderService.createOrder(Orders(
      id: '',
      userId: user.uid,
      sellerId: cart.items.first.product.sellerId,
      items: cart.items
          .map((item) => OrderItem(
                productId: item.product.id,
                image: item.product.imageUrl[0],
                name: item.product.name,
                quantity: item.quantity,
                price: item.product.price,
              ))
          .toList(),
      totalPrice: cart.total,
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
    ));

    cart.clearCart();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => OrderConfirmationScreen(orderId: orderId)),
    );
  }

  Future<String?> _fetchCompanyAddress(String entrepriseId) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(entrepriseId)
          .get();

      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('adress')) {
          Map<String, dynamic> addressMap =
              data['adress'] as Map<String, dynamic>;
          String adresse = addressMap['adresse'] ?? '';
          String codePostal = addressMap['codePostal'] ?? '';
          String ville = addressMap['ville'] ?? '';
          return '$adresse, $codePostal $ville';
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "Erreur lors de la récupération de l'adresse de l'entreprise: $e");
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traitement du paiement')),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_statusMessage),
                ],
              )
            : Text(_statusMessage),
      ),
    );
  }
}
