import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/services/cart_service.dart';
import 'package:happy/services/promo_service.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:happy/widgets/unified_payment_button.dart';
import 'package:provider/provider.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commande chez ${_cart.sellerName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildExpirationBadge(),
            ],
          ),
          const SizedBox(height: 24),
          ..._cart.items.map((item) => _buildOrderItem(item)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _buildTotalSection(),
        ],
      ),
    );
  }

  Widget _buildExpirationBadge() {
    final remainingMinutes = _cart.createdAt
        .add(const Duration(hours: 24))
        .difference(DateTime.now())
        .inMinutes;
    final isNearExpiration = remainingMinutes < 30;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isNearExpiration
            ? Colors.red.withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNearExpiration ? Colors.red : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 16,
            color: isNearExpiration ? Colors.red : Colors.grey[700],
          ),
          const SizedBox(width: 6),
          Text(
            '${remainingMinutes}min',
            style: TextStyle(
              color: isNearExpiration ? Colors.red : Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    final hasDiscount = item.variant.discount?.isValid() ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (item.variant.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item.variant.images[0],
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.variant.attributes.entries
                      .map((e) => '${e.key}: ${e.value}')
                      .join(', '),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Qté: ${item.quantity}',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${item.variant.price.toStringAsFixed(2)} €',
                        style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${(item.appliedPrice * item.quantity).toStringAsFixed(2)} €',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: hasDiscount ? Colors.red[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSection() {
    return Padding(
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
                Row(
                  children: [
                    Text('Code promo (${_cart.appliedPromoCode})'),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _removePromoCode,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '-${_cart.discountAmount.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
    );
  }

  Future<void> _removePromoCode() async {
    setState(() => _isLoading = true);

    try {
      await _firestore.collection('carts').doc(_cart.id).update({
        'appliedPromoCode': null,
        'discountAmount': 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code promo supprimé')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erreur lors de la suppression du code promo')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBottomPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 12,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total à payer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_cart.finalTotal.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: UnifiedPaymentButton(
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
                            'tva': item.tva,
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
                successUrl: '${Uri.base.origin}/#/payment-success',
                cancelUrl: '${Uri.base.origin}/#/payment-cancel',
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Code promo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoCodeController,
                  decoration: InputDecoration(
                    hintText: 'Entrez votre code',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
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
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Appliquer',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
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
      await Provider.of<CartService>(context, listen: false)
          .applyPromoCode(_cart.sellerId, code);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBarBack(
        title: 'Paiement',
      ),
      body: _cart.isExpired ? _buildExpiredCart() : _buildCheckoutContent(),
      bottomNavigationBar:
          !_cart.isExpired ? _buildBottomPaymentSection() : null,
    );
  }
}
