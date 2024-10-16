// lib/services/cart_service.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/services/promo_service.dart';
import 'package:universal_html/html.dart' as html;

class CartItem {
  final Product product;
  int quantity;
  final double appliedPrice;

  CartItem(
      {required this.product, required this.appliedPrice, this.quantity = 1});

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'name': product.name,
      'imageUrl': product.imageUrl,
      'price': product.price,
      'tva': product.tva,
      'quantity': quantity,
      'appliedPrice': appliedPrice,
      'sellerId': product.sellerId,
      'entrepriseId': product.entrepriseId,
      'description': product.description,
      'stock': product.stock,
      'isActive': product.isActive,
    };
  }

  static CartItem fromMap(Map<String, dynamic> map) {
    return CartItem(
      product: Product(
        id: map['productId'] ?? '',
        name: map['name'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        tva: (map['tva'] as num?)?.toDouble() ?? 0.0,
        imageUrl: List<String>.from(map['imageUrl'] ?? []),
        sellerId: map['sellerId'] ?? '',
        entrepriseId: map['entrepriseId'] ?? '',
        description: map['description'] ?? '',
        stock: map['stock'] as int? ?? 0,
        isActive: map['isActive'] as bool? ?? false,
      ),
      quantity: map['quantity'] as int? ?? 1,
      appliedPrice: (map['appliedPrice'] as num?)?.toDouble() ?? map['price'],
    );
  }
}

class CartService extends ChangeNotifier {
  String? appliedPromoCode;
  double discountAmount = 0.00;

  List<CartItem> _items = [];
  String? _currentSellerId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PromoCodeService _promoCodeService = PromoCodeService();

  CartService() {
    if (kIsWeb) {
      _loadFromLocalStorage();
    }
  }

  List<CartItem> get items => _items;

  double get subtotal =>
      _items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  double get total =>
      _items.fold(0, (sum, item) => sum + (item.appliedPrice * item.quantity));

  double get totalSavings => subtotal - total;

  double get totalAfterDiscount => total - discountAmount;

  Future<void> applyPromoCode(
      String code, String companyId, String customerId) async {
    final isValid =
        await _promoCodeService.validatePromoCode(code, companyId, customerId);

    if (isValid) {
      final promoDetails = await _promoCodeService.getPromoCodeDetails(code);
      if (promoDetails != null) {
        appliedPromoCode = code;
        if (promoDetails['isPercentage']) {
          discountAmount = total * (promoDetails['value'] / 100);
        } else {
          discountAmount = promoDetails['value'];
        }
        notifyListeners();
      }
      if (kIsWeb) {
        html.window.localStorage['appliedPromoCode'] = code;
      }
    } else {
      throw Exception('Code promo invalide ou expiré');
    }
  }

  Future<void> finalizePromoCodeUsage() async {
    if (appliedPromoCode != null) {
      await _promoCodeService.usePromoCode(appliedPromoCode!);
      appliedPromoCode = null;
      discountAmount = 0;
      notifyListeners();
    }
  }

  void removePromoCode() {
    appliedPromoCode = null;
    discountAmount = 0;
    notifyListeners();
  }

  void _loadFromLocalStorage() {
    final cartDataJson = html.window.localStorage['cartData'];
    if (cartDataJson != null && cartDataJson.isNotEmpty) {
      final cartData = json.decode(cartDataJson) as List<dynamic>;
      _items = cartData.map((item) => CartItem.fromMap(item)).toList();
      _currentSellerId =
          _items.isNotEmpty ? _items.first.product.sellerId : null;

      discountAmount =
          double.tryParse(html.window.localStorage['discountAmount'] ?? '0') ??
              0;
      appliedPromoCode = html.window.localStorage['appliedPromoCode'];

      notifyListeners();
    }
  }

  void _saveToLocalStorage() {
    if (kIsWeb) {
      final cartData = _items.map((item) => item.toMap()).toList();
      final cartDataJson = json.encode(cartData);
      html.window.localStorage['cartData'] = cartDataJson;
      html.window.localStorage['cartTotal'] = total.toString();
      html.window.localStorage['cartSubtotal'] = subtotal.toString();
      html.window.localStorage['cartTotalSavings'] = totalSavings.toString();
      html.window.localStorage['cartTotalAfterDiscount'] =
          totalAfterDiscount.toString();
      html.window.localStorage['discountAmount'] = discountAmount.toString();
      if (appliedPromoCode != null) {
        html.window.localStorage['appliedPromoCode'] = appliedPromoCode!;
      } else {
        html.window.localStorage.remove('appliedPromoCode');
      }
    }
  }

  Future<bool> checkStock(Product product, int requestedQuantity) async {
    DocumentSnapshot doc =
        await _firestore.collection('products').doc(product.id).get();
    int currentStock = doc.get('stock') as int;
    return currentStock >= requestedQuantity;
  }

  Future<void> addToCart(Product product) async {
    if (_currentSellerId == null) {
      _currentSellerId = product.sellerId;
    } else if (_currentSellerId != product.sellerId) {
      throw Exception(
          'Vous ne pouvez ajouter que des produits du même vendeur');
    }

    int index = _items.indexWhere((item) => item.product.id == product.id);
    int newQuantity = index != -1 ? _items[index].quantity + 1 : 1;

    bool isAvailable = await checkStock(product, newQuantity);
    if (!isAvailable) {
      throw Exception('Stock insuffisant');
    }

    double appliedPrice =
        product.hasActiveHappyDeal && product.discountedPrice != null
            ? product.discountedPrice!
            : product.price;

    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product, appliedPrice: appliedPrice));
    }
    _saveToLocalStorage();
    notifyListeners();
  }

  void removeFromCart(Product product) {
    int index = _items.indexWhere((item) => item.product.id == product.id);
    if (index != -1) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      if (_items.isEmpty) {
        _currentSellerId = null;
      }
      _saveToLocalStorage();
      notifyListeners();
    }
  }

  Future<void> addToCartWithQuantity(Product product, int quantity) async {
    if (_currentSellerId == null) {
      _currentSellerId = product.sellerId;
    } else if (_currentSellerId != product.sellerId) {
      throw Exception(
          'Vous ne pouvez ajouter que des produits du même vendeur');
    }

    int index = _items.indexWhere((item) => item.product.id == product.id);

    bool isAvailable = await checkStock(product, quantity);
    if (!isAvailable) {
      throw Exception('Stock insuffisant');
    }

    // Déterminer le prix à appliquer (prix normal ou prix réduit du Happy Deal)
    double appliedPrice =
        product.hasActiveHappyDeal && product.discountedPrice != null
            ? product.discountedPrice!
            : product.price;

    if (index != -1) {
      // Mettre à jour la quantité si le produit est déjà dans le panier
      _items[index].quantity = quantity;
      // Mettre à jour le prix appliqué au cas où le Happy Deal aurait changé
      _items[index] = CartItem(
          product: product, quantity: quantity, appliedPrice: appliedPrice);
    } else {
      // Ajouter un nouveau CartItem avec le prix appliqué
      _items.add(CartItem(
          product: product, quantity: quantity, appliedPrice: appliedPrice));
    }

    _saveToLocalStorage();
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _currentSellerId = null;
    _saveToLocalStorage();
    notifyListeners();
  }
}
