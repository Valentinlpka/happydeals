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
          'Démarrage de la vérification du paiement et de la finalisation de la commande');
      _logLocalStorageContent();

      print('Récupération du panier...');
      final cart = await _getCart();
      print(
          "Panier récupéré avec succès. Nombre d'articles: ${cart.items.length}");

      setState(() {
        _statusMessage = 'Paiement confirmé. Finalisation de la commande...';
      });

      print('Début de la finalisation de la commande...');
      await _finalizeOrder(cart);
      print('Commande finalisée avec succès');

      print("Finalisation de l'utilisation du code promo...");
      await _finalizePromoCodeUsage(cart);
      print('Utilisation du code promo finalisée');

      _showSuccessMessage();
      print('Message de succès affiché');
    } catch (e, stackTrace) {
      print(
          'Erreur lors de la vérification du paiement ou de la finalisation de la commande:');
      print(e);
      print('Stack trace:');
      print(stackTrace);
      _handleError('Une erreur est survenue: $e');
    } finally {
      if (kIsWeb) {
        print('Nettoyage du localStorage...');
        _clearLocalStorage();
        print('localStorage nettoyé');
      }
      setState(() {
        _isLoading = false;
      });
      print('État de chargement mis à jour: _isLoading = false');
    }
  }

  Future<void> _finalizePromoCodeUsage(CartService cart) async {
    if (kIsWeb) {
      final appliedPromoCode = html.window.localStorage['appliedPromoCode'];
      if (appliedPromoCode != null && appliedPromoCode.isNotEmpty) {
        await _promoCodeService.usePromoCode(appliedPromoCode);
        html.window.localStorage.remove('appliedPromoCode');
      }
    } else {
      await cart.finalizePromoCodeUsage();
    }
  }

  void _logLocalStorageContent() {
    if (kIsWeb) {
      print('Contenu de localStorage:');
      print('cartData: ${html.window.localStorage['cartData']}');
      print('cartTotal: ${html.window.localStorage['cartTotal']}');
      print('cartSubtotal: ${html.window.localStorage['cartSubtotal']}');
      print(
          'cartTotalSavings: ${html.window.localStorage['cartTotalSavings']}');
      print('stripeSessionId: ${html.window.localStorage['stripeSessionId']}');
      print(
          'appliedPromoCode: ${html.window.localStorage['appliedPromoCode']}');
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
    print('Début de la reconstruction du panier depuis localStorage');
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson == null || cartDataJson.isEmpty) {
      print(
          'Erreur: Données du panier non trouvées ou vides dans localStorage');
      throw Exception('Données du panier non trouvées ou vides');
    }

    print('Données brutes du panier trouvées: $cartDataJson');
    final cartData = json.decode(cartDataJson) as List<dynamic>;
    final cart = CartService();

    for (var item in cartData) {
      print('Traitement de l\'item: $item');
      if (item['productId'] == null) {
        print(
            'Avertissement: ID de produit manquant dans les données du panier pour l\'item: $item');
        continue;
      }

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
        final quantity = item['quantity'] as int;
        final appliedPrice = (item['appliedPrice'] as num).toDouble();

        print(
            'Produit reconstruit: ${product.name}, quantité: $quantity, prix appliqué: $appliedPrice');

        cart.items.add(CartItem(
          product: product,
          quantity: quantity,
          appliedPrice: appliedPrice,
        ));

        print(
            'État actuel du panier: ${cart.items.map((i) => "${i.product.name}: ${i.quantity}").join(", ")}');
      } catch (e) {
        print(
            'Erreur lors de la reconstruction du produit ${item['productId']}: $e');
      }
    }

    if (cart.items.isEmpty) {
      print('Erreur: Aucun produit valide n\'a pu être ajouté au panier');
      throw Exception('Aucun produit valide n\'a pu être ajouté au panier');
    }

    print('Reconstruction du panier terminée. Contenu final du panier:');
    for (var item in cart.items) {
      print(
          '${item.product.name}: Quantité=${item.quantity}, Prix appliqué=${item.appliedPrice}, TVA=${item.product.tva}');
    }

    // Récupérer les informations du code promo
    cart.appliedPromoCode = html.window.localStorage['appliedPromoCode'];
    cart.discountAmount =
        double.tryParse(html.window.localStorage['discountAmount'] ?? '0') ?? 0;

    return cart;
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
    print('Erreur: $message');
    setState(() {
      _statusMessage = message;
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  Future<void> _finalizeOrder(CartService cart) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final address =
        await _fetchCompanyAddress(cart.items.first.product.entrepriseId);

    print('Contenu du panier avant création de la commande:');
    for (var item in cart.items) {
      print(
          'Produit: ${item.product.name}, Quantité: ${item.quantity}, Prix appliqué: ${item.appliedPrice}');
    }

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
                originalPrice: item.product.price,
                appliedPrice: item.appliedPrice,
                tva: item.product.tva,
              ))
          .toList(),
      subtotal: cart.subtotal,
      happyDealSavings: cart.totalSavings,
      totalPrice: cart.totalAfterDiscount,
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
      entrepriseId: cart.items.first.product.entrepriseId,
      promoCode: cart.appliedPromoCode,
      discountAmount: cart.discountAmount,
    ));

    print('Commande créée avec l\'ID: $orderId');
    print('Détails de la commande:');
    final createdOrder = await _orderService.getOrder(orderId);
    for (var item in createdOrder.items) {
      print(
          'Produit: ${item.name}, Quantité: ${item.quantity}, Prix original: ${item.originalPrice}, Prix appliqué: ${item.appliedPrice}');
    }

    cart.clearCart();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => OrderDetailPage(orderId: orderId)),
    );
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

  void _showSuccessMessage() {
    setState(() {
      _statusMessage = 'Commande finalisée avec succès!';
    });
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
