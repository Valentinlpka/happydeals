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
      _logLocalStorageContent();

      final cart = await _getCart();

      setState(() {
        _statusMessage = 'Paiement confirmé. Finalisation de la commande...';
      });

      await _finalizeOrder(cart);

      await _finalizePromoCodeUsage();

      _showSuccessMessage();
    } catch (e) {
      _handleError('Une erreur est survenue: $e');
    } finally {
      if (kIsWeb) {
        _clearLocalStorage();
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _finalizePromoCodeUsage() async {
    if (kIsWeb) {
      final appliedPromoCode = html.window.localStorage['appliedPromoCode'];
      if (appliedPromoCode != null && appliedPromoCode.isNotEmpty) {
        await _promoCodeService.usePromoCode(appliedPromoCode);
        html.window.localStorage.remove('appliedPromoCode');
      }
    } else {
      // Pour les applications mobiles, utilisez la méthode existante du CartService
      final cart = Provider.of<CartService>(context, listen: false);
      await cart.finalizePromoCodeUsage();
    }
  }

  void _logLocalStorageContent() {
    if (kIsWeb) {
      print('Contenu de localStorage:');
      print('cartData: ${html.window.localStorage['cartData']}');
      print('cartTotal: ${html.window.localStorage['cartTotal']}');
      print('stripeSessionId: ${html.window.localStorage['stripeSessionId']}');
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
    print('Début de la reconstruction du panier');
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson == null || cartDataJson.isEmpty) {
      throw Exception('Données du panier non trouvées ou vides');
    }

    print('Données brutes du panier: $cartDataJson');
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
        final product = await _fetchProductFromFirestore(item['productId']);
        final quantity = item['quantity'] as int? ?? 1;
        print(
            'Ajout du produit ${product.name} avec une quantité de $quantity');

        // Vérifier si le produit existe déjà dans le panier
        final existingItem = cart.items.firstWhere(
          (cartItem) => cartItem.product.id == product.id,
        );

        print(
            'Le produit ${product.name} existe déjà dans le panier. Mise à jour de la quantité.');
        existingItem.quantity = quantity;

        print(
            'Panier après ajout: ${cart.items.map((i) => "${i.product.name}: ${i.quantity}").join(", ")}');
      } catch (e) {
        print(
            'Erreur lors de la reconstruction du produit ${item['productId']}: $e');
      }
    }

    if (cart.items.isEmpty) {
      throw Exception('Aucun produit valide n\'a pu être ajouté au panier');
    }

    print('Reconstruction du panier terminée. Contenu final du panier:');
    for (var item in cart.items) {
      print('${item.product.name}: ${item.quantity} : ${item.product.tva}');
    }

    // Mettre à jour le localStorage avec les quantités correctes
    _updateLocalStorage(cart);

    return cart;
  }

  void _updateLocalStorage(CartService cart) {
    final cartData = cart.items
        .map((item) => {
              'productId': item.product.id,
              'name': item.product.name,
              'quantity': item.quantity,
              'price': item.product.price,
              'tva': item.product.tva,
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

    print('localStorage mis à jour avec les nouvelles quantités');
  }

  Future<Product> _fetchProductFromFirestore(String productId) async {
    final productDoc =
        await _firestore.collection('products').doc(productId).get();
    if (!productDoc.exists) {
      throw Exception('Produit $productId non trouvé dans Firestore');
    }

    final productData = productDoc.data();
    if (productData == null) {
      throw Exception('Données nulles pour le produit $productId');
    }

    return Product(
      id: productId,
      name: productData['name'] ?? 'Nom inconnu',
      description: productData['description'] ?? '',
      price: (productData['price'] as num?)?.toDouble() ?? 0.0,
      tva: (productData['tva'] as num?)?.toDouble() ?? 0.0,
      imageUrl: List<String>.from(productData['image'] ?? []),
      sellerId: productData['merchantId'] ?? '',
      entrepriseId: productData['sellerId'] ?? '',
      stock: productData['stock'] as int? ?? 0,
      isActive: productData['isActive'] as bool? ?? false,
    );
  }

  void _clearLocalStorage() {
    html.window.localStorage.remove('cartData');
    html.window.localStorage.remove('cartTotal');
    html.window.localStorage.remove('stripeSessionId');
    html.window.localStorage.remove('appliedPromoCode');
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
      print('Produit: ${item.product.name}, Quantité: ${item.quantity}');
    }

    // Vérification supplémentaire des quantités
    bool quantitiesCorrect = cart.items.every((item) {
      final localStorageQuantity =
          _getQuantityFromLocalStorage(item.product.id);
      print(
          'Produit: ${item.product.name}, Quantité dans le panier: ${item.quantity}, Quantité dans localStorage: $localStorageQuantity');
      return item.quantity == localStorageQuantity;
    });

    if (!quantitiesCorrect) {
      print(
          'Erreur: Les quantités dans le panier ne correspondent pas à celles du localStorage');
      // Correction des quantités si nécessaire
      _correctCartQuantities(cart);
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
                price: item.product.price,
                tva: item.product.tva,
              ))
          .toList(),
      totalPrice: cart.total,
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
      entrepriseId: cart.items.first.product.entrepriseId,
    ));

    print('Commande créée avec l\'ID: $orderId');
    print('Détails de la commande:');
    final createdOrder = await _orderService.getOrder(orderId);
    for (var item in createdOrder.items) {
      print('Produit: ${item.name}, Quantité: ${item.quantity}');
    }

    cart.clearCart();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => OrderDetailPage(orderId: orderId)),
    );
  }

  int _getQuantityFromLocalStorage(String productId) {
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson != null) {
      final cartData = json.decode(cartDataJson) as List<dynamic>;
      final item = cartData.firstWhere((item) => item['productId'] == productId,
          orElse: () => null);
      if (item != null) {
        return item['quantity'] as int? ?? 0;
      }
    }
    return 0;
  }

  void _correctCartQuantities(CartService cart) {
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson != null) {
      final cartData = json.decode(cartDataJson) as List<dynamic>;
      for (var item in cart.items) {
        final localStorageItem = cartData.firstWhere(
            (element) => element['productId'] == item.product.id,
            orElse: () => null);
        if (localStorageItem != null) {
          final correctQuantity = localStorageItem['quantity'] as int? ?? 1;
          if (item.quantity != correctQuantity) {
            print(
                'Correction de la quantité pour ${item.product.name} de ${item.quantity} à $correctQuantity');
            item.quantity = correctQuantity;
          }
        }
      }
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
