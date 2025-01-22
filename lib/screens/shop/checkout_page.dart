import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material show Card;
import 'package:flutter/material.dart' hide Card;
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/services/promo_service.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:happy/widgets/unified_payment_button.dart';

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
  String? _orderId;
  String? _pickupAddress;
  final TextEditingController _promoCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromoCodeService _promoService = PromoCodeService();

  bool _isLoading = false;
  late Cart _cart;
  Timer? _expirationTimer;
  StreamSubscription<DocumentSnapshot>? _cartSubscription;

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _generateOrderId();
    _loadPickupAddress();
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

  Future<void> _loadPickupAddress() async {
    final address = await _fetchPickupAddress(_cart.sellerId);
    if (mounted) {
      setState(() {
        _pickupAddress = address;
      });
    }
  }

  Future<void> _generateOrderId() async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    setState(() {
      _orderId = orderRef.id;
    });
  }

  void _startExpirationTimer() {
    _expirationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
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
        Column(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
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
    final remainingMinutes = _cart.createdAt
        .add(const Duration(hours: 24))
        .difference(DateTime.now())
        .inMinutes;
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
    final hasDiscount = item.variant.discount?.isValid() ?? false;

    return material.Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.variant.images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.variant.images[0],
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
                    item.variant.attributes.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(', '),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  Text(
                    'Quantité: ${item.quantity}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (hasDiscount)
                    Text(
                      '${item.variant.price.toStringAsFixed(2)} €',
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
                color: hasDiscount ? Colors.red : null,
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
                Text('${_cart.total.toStringAsFixed(2)} €'),
              ],
            ),
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
                  '${_cart.finalTotal.toStringAsFixed(2)} €',
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

  Widget _buildBottomPaymentSection() {
    return SafeArea(
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
                  '${_cart.finalTotal.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            UnifiedPaymentButton(
              type: 'order',
              amount: (_cart.finalTotal * 100).round(),
              metadata: {
                'orderId': _orderId!,
                'cartId': _cart.id,
                'userId': _auth.currentUser?.uid,
              },
              orderData: {
                'userId': _auth.currentUser?.uid,
                'items': _cart.items
                    .map((item) => {
                          'productId': item.product.id,
                          'variantId': item.variant.id,
                          'name': item.product.name,
                          'variantAttributes': item.variant.attributes,
                          'quantity': item.quantity,
                          'appliedPrice': item.appliedPrice,
                          'originalPrice': item.variant.price,
                          'image': item.variant.images.isNotEmpty
                              ? item.variant.images[0]
                              : '',
                          'sellerId': _cart.sellerId,
                          'entrepriseId': _cart.sellerId,
                        })
                    .toList(),
                'sellerId': _cart.sellerId,
                'entrepriseId': _cart.sellerId,
                'subtotal': _cart.total,
                'promoCode': _cart.appliedPromoCode,
                'discountAmount': _cart.discountAmount,
                'totalPrice': _cart.finalTotal,
                'pickupAddress': _pickupAddress,
              },
              successUrl: kIsWeb
                  ? '${Uri.base.origin}/#/payment-success'
                  : 'happydeals://payment-success',
              cancelUrl: kIsWeb
                  ? '${Uri.base.origin}/#/payment-cancel'
                  : 'happydeals://payment-cancel',
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _fetchPickupAddress(String sellerId) async {
    try {
      final companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(sellerId)
          .get();

      if (!companyDoc.exists) {
        return null;
      }

      final data = companyDoc.data();
      if (data == null) return null;

      final address = data['adress'] as Map<String, dynamic>?;
      if (address == null) {
        return null;
      }

      return [
        address['adresse'],
        address['code_postal'],
        address['ville'],
      ].where((element) => element != null).join(', ');
    } catch (e) {
      return null;
    }
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

  Widget _buildExpiredCart() {
    return Center(
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
    );
  }

  Widget _buildCheckoutContent() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            final doc =
                await _firestore.collection('carts').doc(_cart.id).get();

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
                const SizedBox(height: 100),
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
    );
  }

  // Les autres méthodes restent identiques
  // _fetchPickupAddress, _buildPromoCodeSection, _applyPromoCode,
  // _buildExpiredCart, _buildCheckoutContent, build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Paiement',
      ),
      body: _cart.isExpired ? _buildExpiredCart() : _buildCheckoutContent(),
      bottomNavigationBar:
          !_cart.isExpired ? _buildBottomPaymentSection() : null,
    );
  }
}
