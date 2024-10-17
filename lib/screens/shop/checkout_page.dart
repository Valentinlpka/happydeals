import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happy/classes/notification.dart';
import 'package:happy/screens/shop/order_detail_page.dart';
import 'package:happy/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../classes/order.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _promoCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OrderService _orderService = OrderService();
  bool _isLoading = false;

  Widget _buildOrderSummary(CartService cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Récapitulatif de la commande',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        ...cart.items.map((item) => _buildOrderItem(item)),
        const Divider(),
        _buildTotalSection(cart),
      ],
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return ListTile(
      leading: Image.network(item.product.imageUrl[0],
          width: 50, height: 50, fit: BoxFit.cover),
      title: Text(item.product.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quantité: ${item.quantity}'),
          if (item.product.hasActiveHappyDeal &&
              item.product.discountedPrice != null)
            Text(
              'Prix original: ${item.product.price.toStringAsFixed(2)} €',
              style: const TextStyle(
                  decoration: TextDecoration.lineThrough, color: Colors.grey),
            ),
        ],
      ),
      trailing: Text(
        '${(item.appliedPrice * item.quantity).toStringAsFixed(2)} €',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: item.product.hasActiveHappyDeal ? Colors.red : null,
        ),
      ),
    );
  }

  Widget _buildTotalSection(CartService cart) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sous-total'),
            Text('${cart.subtotal.toStringAsFixed(2)} €'),
          ],
        ),
        if (cart.totalSavings > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Économies Happy Deals',
                  style: TextStyle(color: Colors.green)),
              Text('-${cart.totalSavings.toStringAsFixed(2)} €',
                  style: const TextStyle(color: Colors.green)),
            ],
          ),
        ],
        if (cart.discountAmount > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Code promo (${cart.appliedPromoCode})'),
              Text('-${cart.discountAmount.toStringAsFixed(2)} €'),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${cart.total.toStringAsFixed(2)} €',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildPromoCodeSection() {
    return Consumer<CartService>(
      builder: (context, cart, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Code promo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoCodeController,
                    decoration: const InputDecoration(
                      hintText: 'Entrez votre code promo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _applyPromoCode(cart),
                  child: const Text('Appliquer'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyPromoCode(CartService cart) async {
    try {
      await cart.applyPromoCode(
        _promoCodeController.text,
        cart.items.first.product.entrepriseId,
        FirebaseAuth.instance.currentUser!.uid,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code promo appliqué avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _handlePayment(CartService cart) async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not authenticated");
      if (cart.items.isEmpty) throw Exception("Cart is empty");

      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createPayment').call({
        'amount': (cart.total * 100).round(),
        'currency': 'eur',
        'userId': user.uid,
        'isWeb': kIsWeb,
        'successUrl':
            'https://valentinlpka.github.io/happydeals/#/payment-success',
        'cancelUrl':
            'https://valentinlpka.github.io/happydeals/#/payment-cancel',
        'cartItems': cart.items
            .map((item) => item.toMap())
            .toList(), // Make sure this is passed
      });

      if (kIsWeb) {
        _handleWebPayment(cart, result.data);
      } else {
        await _handleMobilePayment(result.data);
        await _finalizeOrder(cart);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Une erreur est survenue: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleWebPayment(CartService cart, Map<String, dynamic> paymentData) {
    // Créer une structure de données qui évite les doublons
    final cartData = cart.items.map((item) => item.toMap()).toList();
    final uniqueCartData = {};
    for (var item in cartData) {
      final productId = item['productId'];
      if (uniqueCartData.containsKey(productId)) {
        uniqueCartData[productId]['quantity'] += item['quantity'];
      } else {
        uniqueCartData[productId] = item;
      }
    }

    html.window.localStorage['cartData'] =
        json.encode(uniqueCartData.values.toList());
    html.window.localStorage['cartTotal'] = cart.total.toString();
    html.window.localStorage['cartSubtotal'] = cart.subtotal.toString();
    html.window.localStorage['cartSavings'] = cart.totalSavings.toString();
    if (cart.appliedPromoCode != null) {
      html.window.localStorage['appliedPromoCode'] = cart.appliedPromoCode!;
      html.window.localStorage['discountAmount'] =
          cart.discountAmount.toString();
    }
    html.window.localStorage['stripeSessionId'] = paymentData['sessionId'];
    html.window.location.href = paymentData['url'];
  }

  Future<void> _handleMobilePayment(Map<String, dynamic> paymentData) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: paymentData['clientSecret'],
        merchantDisplayName: 'Happy Deals',
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }

  Future<void> _finalizeOrder(CartService cart) async {
    final user = _auth.currentUser;
    final address =
        await _fetchCompanyAddress(cart.items.first.product.entrepriseId);
    print('subtotal : ${cart.subtotal}');
    print('subtotal : ${cart.totalSavings}');
    final orderId = await _orderService.createOrder(Orders(
      id: '',
      userId: user?.uid ?? '',
      sellerId: cart.items.first.product.sellerId,
      items: cart.items
          .map((item) => OrderItem(
                productId: item.product.id,
                name: item.product.name,
                image: item.product.imageUrl[0],
                quantity: item.quantity,
                originalPrice: item.product.price.toDouble(),
                appliedPrice: item.appliedPrice.toDouble(),
                tva: item.product.tva.toDouble(),
              ))
          .toList(),
      subtotal: cart.subtotal.toDouble(),
      happyDealSavings: cart.totalSavings.toDouble(),
      promoCode: cart.appliedPromoCode,
      discountAmount: cart.discountAmount.toDouble(),
      totalPrice: cart.totalAfterDiscount.toDouble(),
      status: 'paid',
      createdAt: DateTime.now(),
      pickupAddress: address ?? "",
      entrepriseId: cart.items.first.product.entrepriseId,
    ));

    await _notificationService.createNotification(NotificationModel(
      id: '',
      userId: cart.items.first.product.entrepriseId,
      type: 'new_order',
      message:
          'Nouvelle commande reçue pour un montant de ${cart.totalAfterDiscount.toStringAsFixed(2)} €',
      relatedId: orderId,
      timestamp: DateTime.now(),
    ));

    await cart.finalizePromoCodeUsage();
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
          return '${addressMap['adresse'] ?? ''}, ${addressMap['codePostal'] ?? ''} ${addressMap['ville'] ?? ''}';
        }
      }
    } catch (e) {
      print('Erreur lors de la récupération de l\'adresse: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderSummary(cart),
                  const SizedBox(height: 20),
                  _buildPromoCodeSection(),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed:
                cart.items.isNotEmpty ? () => _handlePayment(cart) : null,
            child: Text('Payer ${cart.total.toStringAsFixed(2)} €'),
          ),
        ),
      ),
    );
  }
}
