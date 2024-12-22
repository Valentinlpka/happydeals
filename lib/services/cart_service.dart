import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/screens/shop/cart_models.dart';
import 'package:happy/services/promo_service.dart';

class CartService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PromoCodeService _promoService = PromoCodeService();
  final Map<String, Cart> _carts = {};
  StreamSubscription<QuerySnapshot>? _cartsSubscription;
  Timer? _cleanupTimer;

  CartService() {
    _initialize();
  }

  List<Cart> get activeCarts =>
      _carts.values.where((cart) => !cart.isExpired).toList();

  Future<void> _initialize() async {
    if (_auth.currentUser != null) {
      await _subscribeToUserCarts();
    }

    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanExpiredCarts(),
    );
  }

  Future<void> addToCart(Product product, {required String variantId}) async {
    final variant = product.variants.firstWhere(
      (v) => v.id == variantId,
      orElse: () => throw Exception('Variant not found'),
    );

    if (variant.stock <= 0) {
      throw Exception('Produit en rupture de stock');
    }

    var cart = _carts[product.sellerId];
    if (cart == null || cart.isExpired) {
      cart = await _getOrCreateCart(product);
    }

    int index = cart.items.indexWhere((item) =>
        item.product.id == product.id && item.variant.id == variantId);

    if (index != -1) {
      if (cart.items[index].quantity >= variant.stock) {
        throw Exception('Stock insuffisant');
      }
      cart.items[index].quantity++;
    } else {
      double appliedPrice = variant.price;
      if (variant.discount?.isValid() ?? false) {
        appliedPrice =
            variant.discount!.calculateDiscountedPrice(variant.price);
      }

      cart.items.add(CartItem(
        product: product,
        variant: variant,
        appliedPrice: appliedPrice,
        tva: product.tva,
      ));
    }

    await _saveCart(cart);
  }

  Future<void> removeFromCart(
      String sellerId, String productId, String variantId) async {
    final cart = _carts[sellerId];
    if (cart == null) return;

    final index = cart.items.indexWhere(
      (item) => item.product.id == productId && item.variant.id == variantId,
    );

    if (index == -1) return;

    if (cart.items[index].quantity > 1) {
      cart.items[index].quantity--;
    } else {
      cart.items.removeAt(index);
    }

    if (cart.items.isEmpty) {
      await deleteCart(sellerId);
    } else {
      await _saveCart(cart);
    }
  }

  Future<void> applyPromoCode(String sellerId, String code) async {
    final cart = _carts[sellerId];
    if (cart == null) return;

    final isValid = await _promoService.validatePromoCode(
      code,
      cart.sellerId,
      _auth.currentUser?.uid ?? '',
    );

    if (!isValid) {
      throw Exception('Code promo invalide ou expiré');
    }

    final promoDetails = await _promoService.getPromoCodeDetails(code);
    if (promoDetails != null) {
      final productIds = cart.items.map((item) => item.product.id).toList();
      final isApplicable = await _promoService.isPromoCodeApplicableToProducts(
        code,
        cart.sellerId,
        productIds,
      );

      if (!isApplicable) {
        throw Exception(
            'Ce code promo ne s\'applique pas aux produits sélectionnés');
      }

      cart.appliedPromoCode = code;
      if (promoDetails['isPercentage']) {
        cart.discountAmount = cart.total * (promoDetails['value'] / 100);
      } else {
        cart.discountAmount = promoDetails['value'];
      }

      await _promoService.usePromoCode(code, cart.sellerId);
      await _saveCart(cart);
    }
  }

  Future<Cart> _getOrCreateCart(Product product) async {
    var existingCart = _carts[product.sellerId];
    if (existingCart != null && !existingCart.isExpired) {
      return existingCart;
    }

    try {
      String sellerName = '';
      final companyDoc =
          await _firestore.collection('companys').doc(product.sellerId).get();

      if (companyDoc.exists) {
        sellerName = companyDoc.data()?['name'] ?? 'Unknown Company';
      }

      if (_auth.currentUser != null) {
        final existingCartQuery = await _firestore
            .collection('carts')
            .where('userId', isEqualTo: _auth.currentUser!.uid)
            .where('sellerId', isEqualTo: product.sellerId)
            .get();

        if (existingCartQuery.docs.isNotEmpty) {
          final existingCartDoc = existingCartQuery.docs.first;
          final existingCart = await Cart.fromFirestore(existingCartDoc);
          if (existingCart != null && !existingCart.isExpired) {
            _carts[product.sellerId] = existingCart;
            return existingCart;
          }
          await existingCartDoc.reference.delete();
        }

        final cartRef = _firestore.collection('carts').doc();
        final newCart = Cart(
          id: cartRef.id,
          sellerId: product.sellerId,
          merchantId: product.merchantId,
          sellerName: sellerName,
          createdAt: DateTime.now(),
        );

        await cartRef.set({
          ...newCart.toMap(),
          'userId': _auth.currentUser!.uid,
        });

        _carts[product.sellerId] = newCart;
        return newCart;
      } else {
        final newCart = Cart(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sellerId: product.sellerId,
          merchantId: product.merchantId,
          sellerName: sellerName,
          createdAt: DateTime.now(),
        );

        _carts[product.sellerId] = newCart;
        return newCart;
      }
    } catch (e) {
      throw Exception('Impossible de créer le panier: $e');
    }
  }

  Future<void> _saveCart(Cart cart) async {
    if (_auth.currentUser != null) {
      try {
        final cartData = {
          ...cart.toMap(),
          'userId': _auth.currentUser!.uid,
        };

        final existingCartQuery = await _firestore
            .collection('carts')
            .where('userId', isEqualTo: _auth.currentUser!.uid)
            .where('sellerId', isEqualTo: cart.sellerId)
            .get();

        if (existingCartQuery.docs.isNotEmpty) {
          String existingId = existingCartQuery.docs.first.id;
          await _firestore
              .collection('carts')
              .doc(existingId)
              .set(cartData, SetOptions(merge: true));

          cart.id = existingId;
          _carts[cart.sellerId] = cart;
        } else {
          final docRef = _firestore.collection('carts').doc();
          cart.id = docRef.id;
          await docRef.set(cartData);
          _carts[cart.sellerId] = cart;
        }

        notifyListeners();
      } catch (e) {
        throw Exception('Impossible de sauvegarder le panier');
      }
    } else {
      _carts[cart.sellerId] = cart;
      notifyListeners();
    }
  }

  Future<void> deleteCart(String sellerId) async {
    final cart = _carts[sellerId];
    if (cart == null) return;

    if (_auth.currentUser != null) {
      final cartQuery = await _firestore
          .collection('carts')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('sellerId', isEqualTo: sellerId)
          .get();

      for (var doc in cartQuery.docs) {
        await doc.reference.delete();
      }
    }

    _carts.remove(sellerId);
    notifyListeners();
  }

  Future<void> _cleanExpiredCarts() async {
    if (_auth.currentUser != null) {
      final snapshot = await _firestore
          .collection('carts')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('expiresAt', isLessThan: Timestamp.fromDate(DateTime.now()))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    _carts.removeWhere((_, cart) => cart.isExpired);
    notifyListeners();
  }

  Future<void> _subscribeToUserCarts() async {
    _cartsSubscription?.cancel();

    _cartsSubscription = _firestore
        .collection('carts')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .snapshots()
        .listen((snapshot) async {
      for (var doc in snapshot.docs) {
        try {
          final cart = await Cart.fromFirestore(doc);
          if (cart != null) {
            if (cart.isExpired) {
              await doc.reference.delete();
              _carts.remove(cart.sellerId);
            } else {
              _carts[cart.sellerId] = cart;
            }
          }
        } catch (e) {
          print('Error processing cart document: $e');
        }
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _cartsSubscription?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
