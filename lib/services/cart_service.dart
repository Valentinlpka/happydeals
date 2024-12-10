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

    // Configurer le timer de nettoyage
    _cleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _cleanExpiredCarts(),
    );
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

    // Nettoyer les paniers locaux expirés
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
      // Ne pas vider _carts complètement pour éviter de perdre les paniers existants
      final currentCartIds = Set<String>.from(_carts.keys);
      final updatedCartIds = <String>{};

      for (var doc in snapshot.docs) {
        try {
          final cart = await Cart.fromFirestore(doc);
          if (cart != null) {
            if (cart.isExpired) {
              await doc.reference.delete();
              _carts.remove(cart.sellerId);
            } else {
              _carts[cart.sellerId] = cart;
              updatedCartIds.add(cart.sellerId);
            }
          }
        } catch (e) {
        }
      }

      // Supprimer uniquement les paniers qui n'existent plus dans Firestore
      currentCartIds
          .difference(updatedCartIds)
          .forEach((sellerId) => _carts.remove(sellerId));

      notifyListeners();
    });
  }

  Future<void> _saveCart(Cart cart) async {
    if (_auth.currentUser != null) {
      try {
        final cartData = {
          ...cart.toMap(),
          'userId': _auth.currentUser!.uid,
        };

        // Vérifier si un panier existe déjà pour ce vendeur
        final existingCartQuery = await _firestore
            .collection('carts')
            .where('userId', isEqualTo: _auth.currentUser!.uid)
            .where('sellerId', isEqualTo: cart.sellerId)
            .get();

        if (existingCartQuery.docs.isNotEmpty) {
          // Utiliser l'ID existant
          String existingId = existingCartQuery.docs.first.id;
          await _firestore
              .collection('carts')
              .doc(existingId)
              .set(cartData, SetOptions(merge: true));

          // Créer un nouveau Cart avec l'ID existant
          final updatedCart = Cart(
            id: existingId,
            sellerId: cart.sellerId,
            entrepriseId: cart.entrepriseId,
            sellerName: cart.sellerName,
            items: cart.items,
            createdAt: cart.createdAt,
            appliedPromoCode: cart.appliedPromoCode,
            discountAmount: cart.discountAmount,
          );
          _carts[cart.sellerId] = updatedCart;
        } else {
          // Créer un nouveau panier
          final docRef = _firestore.collection('carts').doc();
          // Créer un nouveau Cart avec le nouvel ID
          final newCart = Cart(
            id: docRef.id,
            sellerId: cart.sellerId,
            sellerName: cart.sellerName,
            entrepriseId: cart.entrepriseId,
            items: cart.items,
            createdAt: cart.createdAt,
            appliedPromoCode: cart.appliedPromoCode,
            discountAmount: cart.discountAmount,
          );
          await docRef.set(cartData);
          _carts[cart.sellerId] = newCart;
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

  // Modifions également addToCart pour mieux gérer les paniers multiples
  Future<void> addToCart(Product product) async {
    // Vérifier si un panier existe déjà pour ce vendeur
    var cart = _carts[product.sellerId];

    if (cart == null || cart.isExpired) {
      cart = await _getOrCreateCart(product);
    }

    bool isAvailable = await _checkStock(
      product,
      cart.items
              .firstWhere(
                (item) => item.product.id == product.id,
                orElse: () => CartItem(
                  product: product,
                  appliedPrice: product.price,
                ),
              )
              .quantity +
          1,
    );

    if (!isAvailable) {
      throw Exception('Stock insuffisant');
    }

    int index = cart.items.indexWhere((item) => item.product.id == product.id);
    if (index != -1) {
      cart.items[index].quantity++;
    } else {
      double appliedPrice =
          product.hasActiveHappyDeal && product.discountedPrice != null
              ? product.discountedPrice!
              : product.price;

      cart.items.add(CartItem(
        product: product,
        appliedPrice: appliedPrice,
      ));
    }

    await _saveCart(cart);
  }

  // Assurons-nous que la méthode deleteCart gère correctement la suppression
  Future<void> deleteCart(String sellerId) async {
    final cart = _carts[sellerId];
    if (cart == null) return;

    if (_auth.currentUser != null) {
      // Rechercher le document par sellerId et userId
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

  Future<Cart> _getOrCreateCart(Product product) async {
    // Vérifier si un panier actif existe pour ce vendeur
    var existingCart = _carts[product.sellerId];
    if (existingCart != null && !existingCart.isExpired) {
      return existingCart;
    }

    try {
      // Récupérer les informations du vendeur d'abord dans companys
      String sellerName;
      final companyDoc = await _firestore
          .collection('companys')
          .doc(
              product.entrepriseId) // Utiliser entrepriseId au lieu de sellerId
          .get();

      if (companyDoc.exists) {
        sellerName = companyDoc.data()?['name'] ?? 'Unknown Company';
      } else {
        // Si pas trouvé dans companys, chercher dans users
        final userDoc =
            await _firestore.collection('users').doc(product.sellerId).get();

        if (!userDoc.exists) {
          sellerName = 'Unknown Seller';
        } else {
          sellerName = userDoc.data()?['name'] ?? 'Unknown User';
        }
      }

      if (_auth.currentUser != null) {
        // Vérifier si un panier existe déjà dans Firestore
        final existingCartQuery = await _firestore
            .collection('carts')
            .where('userId', isEqualTo: _auth.currentUser!.uid)
            .where('sellerId', isEqualTo: product.sellerId)
            .get();

        if (existingCartQuery.docs.isNotEmpty) {
          // Utiliser le panier existant
          final existingCartDoc = existingCartQuery.docs.first;
          final existingCart = await Cart.fromFirestore(existingCartDoc);
          if (existingCart != null && !existingCart.isExpired) {
            _carts[product.sellerId] = existingCart;
            return existingCart;
          }
          // Si le panier existe mais est expiré, le supprimer
          await existingCartDoc.reference.delete();
        }

        // Créer un nouveau document dans Firestore
        final cartRef = _firestore.collection('carts').doc();
        final newCart = Cart(
          id: cartRef.id,
          sellerId: product.sellerId,
          entrepriseId: product.entrepriseId,
          sellerName: sellerName,
          createdAt: DateTime.now(),
        );

        await cartRef.set({
          ...newCart.toMap(),
          'userId': _auth.currentUser!.uid,
        });

        _carts[product.sellerId] = newCart;
        notifyListeners();
        return newCart;
      } else {
        // Version locale pour les utilisateurs non connectés
        final newCart = Cart(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sellerId: product.sellerId,
          entrepriseId: product.entrepriseId,
          sellerName: sellerName,
          createdAt: DateTime.now(),
        );

        _carts[product.sellerId] = newCart;
        notifyListeners();
        return newCart;
      }
    } catch (e) {
      throw Exception('Impossible de créer le panier: $e');
    }
  }

  Future<bool> _checkStock(Product product, int requestedQuantity) async {
    DocumentSnapshot doc =
        await _firestore.collection('products').doc(product.id).get();
    return (doc.get('stock') as int) >= requestedQuantity;
  }

  Future<void> removeFromCart(String sellerId, String productId) async {
    final cart = _carts[sellerId];
    if (cart == null) return;

    final index = cart.items.indexWhere((item) => item.product.id == productId);
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
      // Vérifier si le code s'applique aux produits du panier
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

      // Marquer le code comme utilisé
      await _promoService.usePromoCode(code, cart.sellerId);
      await _saveCart(cart);
    }
  }

  @override
  void dispose() {
    _cartsSubscription?.cancel();
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
