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

  Widget _buildPromoCodeSection() {
    return Consumer<CartService>(
      builder: (context, cart, child) {
        return Column(
          children: [
            TextField(
              controller: _promoCodeController,
              decoration: const InputDecoration(
                labelText: 'Code promo',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await cart.applyPromoCode(
                    _promoCodeController.text,
                    cart.items.first.product.entrepriseId,
                    FirebaseAuth.instance.currentUser!.uid,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Code promo appliqué avec succès')),
                  );
                } catch (e) {
                  print(e);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: const Text('Appliquer'),
            ),
            if (cart.discountAmount > 0) ...[
              Text('Réduction: ${cart.discountAmount.toStringAsFixed(2)}€'),
              Text(
                  'Total après réduction: ${cart.totalAfterDiscount.toStringAsFixed(2)}€'),
            ],
          ],
        );
      },
    );
  }

  Future<void> _handlePayment(CartService cart) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User not authenticated");
      }

      if (cart.items.isEmpty) {
        throw Exception("Cart is empty");
      }

      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createPayment').call({
        'amount': (cart.totalAfterDiscount * 100).round(),
        'currency': 'eur',
        'userId': user.uid,
        'isWeb': kIsWeb,
        'successUrl':
            'https://valentinlpka.github.io/happydeals/#/payment-success',
        'cancelUrl':
            'https://valentinlpka.github.io/happydeals/#/payment-cancel',
      });

      if (kIsWeb) {
        // Logique de paiement web (inchangée)
        final cartData = cart.items
            .map((item) => {
                  'productId': item.product.id,
                  'name': item.product.name,
                  'quantity': item.quantity,
                  'price': item.product.price,
                  'sellerId': item.product.sellerId,
                  'tva': item.product.tva,
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

        // Ajout du stockage des informations du code promo
        if (cart.appliedPromoCode != null) {
          html.window.localStorage['appliedPromoCode'] = cart.appliedPromoCode!;
          html.window.localStorage['discountAmount'] =
              cart.discountAmount.toString();
        }

        final sessionId = result.data['sessionId'];
        final sessionUrl = result.data['url'];

        html.window.localStorage['stripeSessionId'] = sessionId;
        html.window.location.href = sessionUrl;
      } else {
        // Logique de paiement mobile
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: result.data['clientSecret'],
            merchantDisplayName: 'Happy Deals',
          ),
        );

        await Stripe.instance.presentPaymentSheet();

        // Si nous arrivons ici, le paiement a réussi
        await _finalizeOrder(cart);
      }
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

  Future<void> _finalizeOrder(CartService cart) async {
    final user = _auth.currentUser;
    final address =
        await _fetchCompanyAddress(cart.items.first.product.entrepriseId);

    final orderId = await _orderService.createOrder(Orders(
        id: '',
        userId: user != null ? user.uid : '',
        sellerId: cart.items.first.product.sellerId,
        items: cart.items
            .map((item) => OrderItem(
                  productId: item.product.id,
                  name: item.product.name,
                  image: item.product.imageUrl[0],
                  quantity: item.quantity,
                  price: item.product.price,
                  tva: item.product.tva,
                ))
            .toList(),
        promoCode: cart.appliedPromoCode,
        discountAmount: cart.discountAmount,
        totalPrice: cart.total,
        status:
            'paid', // Le statut reste 'paid' car le paiement a été effectué sur le compte de la plateforme
        createdAt: DateTime.now(),
        pickupAddress: address ?? "",
        entrepriseId: cart.items.first.product.entrepriseId));

    // Créer une notification pour le vendeur
    await _notificationService.createNotification(NotificationModel(
      id: '',
      userId: cart.items.first.product.entrepriseId,
      type: 'new_order',
      message:
          'Nouvelle commande reçue pour un montant de ${cart.total.toStringAsFixed(2)} €',
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
          String adresse = addressMap['adresse'] ?? '';
          String codePostal = addressMap['codePostal'] ?? '';
          String ville = addressMap['ville'] ?? '';
          return '$adresse, $codePostal $ville';
        }
      }
    } catch (e) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    return Scaffold(
      bottomNavigationBar: SafeArea(
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
                onPressed: () => _handlePayment(cart),
                child: const Text('Procéder au paiement'),
              ),
            ),
          ),
        ),
      ),
      appBar: AppBar(title: const Text('Paiement')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Récapitulatif de la commande',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return ListTile(
                          leadingAndTrailingTextStyle: const TextStyle(
                              fontSize: 16, color: Colors.black),
                          leading: Image.network(item.product.imageUrl[0]),
                          title: Text(item.product.name),
                          subtitle: Text('Quantité: ${item.quantity}'),
                          trailing: Text(
                              '${(item.product.price * item.quantity).toStringAsFixed(2)} €'),
                        );
                      },
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${cart.total.toStringAsFixed(2)} €',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPromoCodeSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
