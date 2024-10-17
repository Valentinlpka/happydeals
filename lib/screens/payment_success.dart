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
import 'package:happy/services/promo_service.dart';
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
  final PromoCodeService _promoCodeService = PromoCodeService();

  bool _isLoading = true;
  String _statusMessage = 'Vérification du paiement en cours...';

  @override
  void initState() {
    super.initState();
    _verifyPaymentAndFinalizeOrder();
  }

  Future<void> _verifyPaymentAndFinalizeOrder() async {
    try {
      print(
          'Mise à jour Début de la vérification du paiement et de la finalisation de la commande');
      if (kIsWeb) _logLocalStorageContent();

      final cart = await _getCart();
      print("Panier récupéré. Nombre d'articles: ${cart.items.length}");

      setState(() =>
          _statusMessage = 'Paiement confirmé. Finalisation de la commande...');

      await _finalizeOrder(cart);
      print('Commande finalisée avec succès');

      await _finalizePromoCodeUsage(cart);
      print('Utilisation du code promo finalisée');

      _showSuccessMessage();
    } catch (e) {
      print('Erreur: $e');
      _handleError('Une erreur est survenue: $e');
    } finally {
      if (kIsWeb) _clearLocalStorage();
      setState(() => _isLoading = false);
    }
  }

  Future<CartService> _getCart() async {
    if (kIsWeb) {
      return _reconstructCartFromLocalStorage();
    } else {
      return Provider.of<CartService>(context, listen: false);
    }
  }

  Future<CartService> _reconstructCartFromLocalStorage() async {
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson == null || cartDataJson.isEmpty) {
      throw Exception('Données du panier non trouvées ou vides');
    }

    final cartData = json.decode(cartDataJson) as List<dynamic>;
    final cart = CartService();

    // Utiliser un Map pour éviter les doublons
    Map<String, CartItem> itemMap = {};

    for (var item in cartData) {
      try {
        final product = Product(
          id: item['productId'],
          name: item['name'],
          price: (item['price'] as num).toDouble(),
          tva: (item['tva'] as num).toDouble(),
          imageUrl: List<String>.from(item['imageUrl']),
          sellerId: item['sellerId'],
          entrepriseId: item['entrepriseId'],
          description: item['description'],
          stock: item['stock'],
          isActive: item['isActive'],
        );

        final cartItem = CartItem(
          product: product,
          quantity: item['quantity'],
          appliedPrice: (item['appliedPrice'] as num).toDouble(),
        );

        itemMap[product.id] = cartItem;
      } catch (e) {
        print('Erreur lors de la reconstruction du produit: $e');
      }
    }

    // Ajoutez les articles uniques au panier
    cart.items.addAll(itemMap.values);

    // Ajoutez des logs pour le débogage
    print('Nombre d\'articles après reconstruction: ${cart.items.length}');
    for (var item in cart.items) {
      print(
          'Article reconstruit: ${item.product.id}, Quantité: ${item.quantity}');
    }

    cart.appliedPromoCode = html.window.localStorage['appliedPromoCode'];
    cart.discountAmount =
        double.tryParse(html.window.localStorage['discountAmount'] ?? '0') ?? 0;

    return cart;
  }

  Future<void> _finalizeOrder(CartService cart) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non authentifié');

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
                originalPrice: item.product.price.toDouble(),
                appliedPrice: item.appliedPrice.toDouble(),
                tva: item.product.tva.toDouble(),
              ))
          .toList(),
      subtotal: cart.subtotal.toDouble(),
      happyDealSavings: cart.totalSavings.toDouble(),
      totalPrice: cart.totalAfterDiscount.toDouble(),
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
      entrepriseId: cart.items.first.product.entrepriseId,
      promoCode: cart.appliedPromoCode,
      discountAmount: cart.discountAmount.toDouble(),
    ));

    cart.clearCart();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => OrderDetailPage(orderId: orderId)),
    );
  }

  Future<void> _finalizePromoCodeUsage(CartService cart) async {
    if (kIsWeb) {
      final appliedPromoCode = html.window.localStorage['appliedPromoCode'];
      if (appliedPromoCode != null && appliedPromoCode.isNotEmpty) {
        await _promoCodeService.usePromoCode(appliedPromoCode);
      }
    } else {
      await cart.finalizePromoCodeUsage();
    }
  }

  Future<String?> _fetchCompanyAddress(String entrepriseId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('companys').doc(entrepriseId).get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('adress')) {
          Map<String, dynamic> addressMap =
              data['adress'] as Map<String, dynamic>;
          return '${addressMap['adresse'] ?? ''}, ${addressMap['codePostal'] ?? ''} ${addressMap['ville'] ?? ''}';
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération de l'adresse de l'entreprise: $e");
    }
    return null;
  }

  void _logLocalStorageContent() {
    print('Contenu de localStorage:');
    print('cartData: ${html.window.localStorage['cartData']}');
    print('cartTotal: ${html.window.localStorage['cartTotal']}');
    print('cartSubtotal: ${html.window.localStorage['cartSubtotal']}');
    print('cartTotalSavings: ${html.window.localStorage['cartTotalSavings']}');
    print('stripeSessionId: ${html.window.localStorage['stripeSessionId']}');
    print('appliedPromoCode: ${html.window.localStorage['appliedPromoCode']}');
  }

  void _clearLocalStorage() {
    html.window.localStorage.remove('cartData');
    html.window.localStorage.remove('cartTotal');
    html.window.localStorage.remove('cartSubtotal');
    html.window.localStorage.remove('cartTotalSavings');
    html.window.localStorage.remove('stripeSessionId');
    html.window.localStorage.remove('appliedPromoCode');
    html.window.localStorage.remove('discountAmount');
  }

  void _handleError(String message) {
    setState(() {
      _statusMessage = message;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  void _showSuccessMessage() {
    setState(() => _statusMessage = 'Commande finalisée avec succès!');
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
