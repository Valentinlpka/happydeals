import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' as material show Card;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:happy/screens/payment_success.dart';
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/services/notification_service.dart';
import 'package:happy/services/order_service.dart';
import 'package:happy/services/promo_service.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:universal_html/html.dart' as html;

class CheckoutScreen extends StatefulWidget {
  final Cart cart;

  const CheckoutScreen({
    super.key,
    required this.cart,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _promoCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OrderService _orderService = OrderService();
  final PromoCodeService _promoService = PromoCodeService();

  bool _isLoading = false;
  late Cart _cart;
  Timer? _expirationTimer;
  StreamSubscription<DocumentSnapshot>? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _startExpirationTimer();
    _listenToCartChanges();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _cartSubscription?.cancel();
    _promoCodeController.dispose();
    super.dispose();
  }

  void _startExpirationTimer() {
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          // Force UI update for remaining time
          if (_cart.isExpired) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  void _listenToCartChanges() {
    _cartSubscription = _firestore
        .collection('carts')
        .doc(_cart.id)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      final updatedCart = await Cart.fromFirestore(snapshot);
      if (updatedCart != null && mounted) {
        setState(() {
          _cart = updatedCart;
        });
      }
    });
  }

  Widget _buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Commande chez ${_cart.sellerName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            _buildExpirationBadge(),
          ],
        ),
        const SizedBox(height: 20),
        ..._cart.items.map((item) => _buildOrderItem(item)),
        const Divider(),
        _buildTotalSection(),
      ],
    );
  }

  Widget _buildExpirationBadge() {
    final remainingMinutes =
        _cart.expiresAt.difference(DateTime.now()).inMinutes;
    final isNearExpiration = remainingMinutes < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isNearExpiration
            ? Colors.red.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNearExpiration ? Colors.red : Colors.grey,
          width: 1,
        ),
      ),
      child: Text(
        'Expire dans: ${remainingMinutes}min',
        style: TextStyle(
          color: isNearExpiration ? Colors.red : Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return material.Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.product.imageUrl[0],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quantité: ${item.quantity}',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  if (item.product.hasActiveHappyDeal &&
                      item.product.discountedPrice != null)
                    Text(
                      '${item.product.price.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${(item.appliedPrice * item.quantity).toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: item.product.hasActiveHappyDeal ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return material.Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sous-total'),
                Text('${_cart.subtotal.toStringAsFixed(2)} €'),
              ],
            ),
            if (_cart.totalSavings > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Économies Happy Deals',
                    style: TextStyle(color: Colors.green),
                  ),
                  Text(
                    '-${_cart.totalSavings.toStringAsFixed(2)} €',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
            if (_cart.discountAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Code promo (${_cart.appliedPromoCode})'),
                  Text('-${_cart.discountAmount.toStringAsFixed(2)} €'),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total à payer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_cart.totalAfterDiscount.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    return material.Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Code promo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoCodeController,
                    decoration: const InputDecoration(
                      hintText: 'Entrez votre code',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _applyPromoCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Appliquer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyPromoCode() async {
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) return;

    if (_cart.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce panier a expiré')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isValid = await _promoService.validatePromoCode(
        code,
        _cart.sellerId,
        _auth.currentUser!.uid,
      );

      if (!isValid) {
        throw Exception('Code promo invalide ou expiré');
      }

      final promoDetails = await _promoService.getPromoCodeDetails(code);
      if (promoDetails == null) {
        throw Exception('Erreur lors de la récupération du code promo');
      }

      final discountAmount = promoDetails['isPercentage']
          ? _cart.total * (promoDetails['value'] / 100)
          : promoDetails['value'].toDouble();

      print('Réduction calculée: $discountAmount'); // Debug
      print('Prix total avant réduction: ${_cart.total}'); // Debug
      print(
          'Prix attendu après réduction: ${_cart.total - discountAmount}'); // Debug

      await _firestore.collection('carts').doc(_cart.id).update({
        'appliedPromoCode': code,
        'discountAmount': discountAmount,
      });

      _promoCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code promo appliqué avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePayment() async {
    if (_cart.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce panier a expiré')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final cartDoc = await _firestore.collection('carts').doc(_cart.id).get();
      final updatedCart = await Cart.fromFirestore(cartDoc);

      if (updatedCart == null) {
        throw Exception('Erreur lors de la récupération du panier');
      }

      final finalAmount = (updatedCart.totalAfterDiscount * 100).round();
      print('Prix final: $finalAmount'); // Pour déboguer
      print('Prix avant conversion: ${_cart.totalAfterDiscount}'); // ex: 4.99
      print('Prix après conversion: $finalAmount'); // ex: 499
      print(
          'Prix total original: ${_cart.total}'); // Pour voir le prix avant réduction
      print('Montant de la réduction: ${_cart.discountAmount}');

      final result =
          await FirebaseFunctions.instance.httpsCallable('createPayment').call({
        'amount': finalAmount,
        'currency': 'eur',
        'cartId': _cart.id,
        'userId': user.uid,
        'isWeb': kIsWeb,
        'successUrl':
            'https://valentinlpka.github.io/happydeals/#/payment-success',
        'cancelUrl':
            'https://valentinlpka.github.io/happydeals/#/payment-cancel',
      });

      if (kIsWeb) {
        final url = result.data['url'] as String;
        final redirectUrl = Uri.parse(url).toString();

        html.window.location.href = redirectUrl;
      } else {
        await _handleMobilePayment(result.data);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleMobilePayment(Map<String, dynamic> paymentData) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentData['clientSecret'],
          merchantDisplayName: 'Happy Deals',
          style: ThemeMode.system,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      // After successful payment, navigate to success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const PaymentSuccessScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de paiement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Paiement',
      ),
      body: _cart.isExpired
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_off,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ce panier a expiré',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Veuillez retourner à la boutique',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retourner à la boutique'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    // Reload cart data
                    final doc = await _firestore
                        .collection('carts')
                        .doc(_cart.id)
                        .get();

                    if (doc.exists) {
                      final updatedCart = await Cart.fromFirestore(doc);
                      if (updatedCart != null && mounted) {
                        setState(() {
                          _cart = updatedCart;
                        });
                      }
                    }
                  },
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildOrderSummary(),
                        const SizedBox(height: 16),
                        if (!_cart.isExpired) _buildPromoCodeSection(),
                        const SizedBox(height: 100), // Space for bottom button
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: !_cart.isExpired
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total à payer',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${_cart.totalAfterDiscount.toStringAsFixed(2)} €',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handlePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Payer ${_cart.totalAfterDiscount.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
