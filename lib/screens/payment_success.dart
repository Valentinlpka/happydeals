import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/order.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _statusMessage = 'Vérification du paiement en cours...';

  @override
  void initState() {
    super.initState();
    _verifyPaymentAndFinalizeOrder();
  }

  Future<void> _verifyPaymentAndFinalizeOrder() async {
    print('Contenu de localStorage:');
    print('cartData: ${html.window.localStorage['cartData']}');
    print('cartTotal: ${html.window.localStorage['cartTotal']}');
    print('stripeSessionId: ${html.window.localStorage['stripeSessionId']}');

    try {
      CartService cart;
      if (kIsWeb) {
        cart = await _reconstructCartFromLocalStorage();
      } else {
        cart = Provider.of<CartService>(context, listen: false);
      }

      setState(() {
        _statusMessage = 'Paiement confirmé. Finalisation de la commande...';
      });
      await _finalizeOrder(cart);
    } catch (e) {
      _handleError('Une erreur est survenue: $e', '/home');
    } finally {
      if (kIsWeb) {
        _clearLocalStorage();
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<CartService> _reconstructCartFromLocalStorage() async {
    print('Début de la reconstruction du panier');
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson == null || cartDataJson.isEmpty) {
      print('Données du panier non trouvées ou vides dans localStorage');
      throw Exception('Données du panier non trouvées ou vides');
    }

    print('Données du panier trouvées: $cartDataJson');
    final cartData = json.decode(cartDataJson) as List<dynamic>;
    final cart = CartService();

    for (var item in cartData) {
      print('Traitement de l\'item: $item');
      if (item['productId'] == null) {
        print(
            'Avertissement: ID de produit manquant dans les données du panier');
        continue;
      }

      try {
        print('Récupération du produit ${item['productId']} depuis Firestore');
        final productDoc = await _firestore
            .collection('products')
            .doc(item['productId'])
            .get();
        if (!productDoc.exists) {
          print(
              'Avertissement: Produit ${item['productId']} non trouvé dans Firestore');
          continue;
        }

        final productData = productDoc.data();
        print('Données du produit récupérées: $productData');
        if (productData == null) {
          print(
              'Avertissement: Données nulles pour le produit ${item['productId']}');
          continue;
        }

        final product = Product(
          id: item['productId'],
          name: productData['name'] ?? 'Nom inconnu',
          description: productData['description'] ?? '',
          price: (productData['price'] as num?)?.toDouble() ?? 0.0,
          imageUrl: List<String>.from(productData['image'] ?? []),
          sellerId: productData['merchantId'] ?? '',
          entrepriseId: productData['sellerId'] ?? '',
          stock: productData['stock'] as int? ?? 0,
          isActive: productData['isActive'] as bool? ?? false,
        );

        print('Produit créé: ${product.name}');

        final quantity = item['quantity'] as int? ?? 1;
        for (int i = 0; i < quantity; i++) {
          cart.addToCart(product);
          print(
              'Produit ajouté au panier: ${product.name}, quantité: ${i + 1}');
        }
      } catch (e) {
        print(
            'Erreur lors de la reconstruction du produit ${item['productId']}: $e');
      }
    }

    if (cart.items.isEmpty) {
      print('Aucun produit valide n\'a pu être ajouté au panier');
      throw Exception('Aucun produit valide n\'a pu être ajouté au panier');
    }

    print(
        'Reconstruction du panier terminée. Nombre d\'articles: ${cart.items.length}');
    return cart;
  }

  void _clearLocalStorage() {
    html.window.localStorage.remove('cartData');
    html.window.localStorage.remove('cartTotal');
    html.window.localStorage.remove('stripeSessionId');
  }

  void _handleError(String message, String redirectRoute) {
    print('Erreur: $message'); // Pour le débogage
    setState(() {
      _statusMessage = message;
      _isLoading = false;
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
          builder: (context) => OrderDetailPage(orderId: orderId)),
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
      print("Erreur lors de la récupération de l'adresse de l'entreprise: $e");
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
