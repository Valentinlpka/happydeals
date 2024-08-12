// lib/services/cart_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/product.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'name': product.name,
      'images': product.imageUrl[0],
      'price': product.price,
      'quantity': quantity,
    };
  }
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _currentSellerId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CartItem> get items => _items;
  double get total =>
      _items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

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

    if (index != -1) {
      _items[index].quantity++;
    } else {
      _items.add(CartItem(product: product));
    }
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
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _currentSellerId = null;
    notifyListeners();
  }
}
