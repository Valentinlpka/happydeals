// lib/services/cart_service.dart
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
      'price': product.price,
      'quantity': quantity,
    };
  }
}

class CartService extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _currentSellerId;

  List<CartItem> get items => _items;
  double get total =>
      _items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  void addToCart(Product product) {
    if (_currentSellerId == null) {
      _currentSellerId = product.sellerId;
    } else if (_currentSellerId != product.sellerId) {
      throw Exception(
          'Vous ne pouvez ajouter que des produits du même vendeur');
    }

    int index = _items.indexWhere((item) => item.product.id == product.id);
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
