import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/product.dart';

class CartItem {
  final Product product;
  int quantity;
  final double appliedPrice;

  CartItem({
    required this.product,
    required this.appliedPrice,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'name': product.name,
      'quantity': quantity,
      'price': appliedPrice,
    };
  }

  Map<String, dynamic> toMaps() {
    return {
      'productId': product.id,
      'name': product.name,
      'images': product.imageUrl,
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

  static CartItem fromMap(Map<String, dynamic> map, Product product) {
    return CartItem(
      product: product,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      appliedPrice: (map['appliedPrice'] as num?)?.toDouble() ?? product.price,
    );
  }
}

class Cart {
  String id;
  final String sellerId;
  final String entrepriseId;
  final String sellerName;
  final List<CartItem> items;
  final DateTime createdAt;
  final DateTime expiresAt;
  String? appliedPromoCode;
  double discountAmount;

  Cart({
    required this.id,
    required this.sellerId,
    required this.entrepriseId,
    required this.sellerName,
    List<CartItem>? items,
    DateTime? createdAt,
    this.appliedPromoCode,
    this.discountAmount = 0.0,
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now(),
        expiresAt = (createdAt ?? DateTime.now()).add(const Duration(hours: 2));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  // Prix original sans aucune réduction
  double get subtotal =>
      items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  // Prix après réductions Happy Deals
  double get total =>
      items.fold(0, (sum, item) => sum + (item.appliedPrice * item.quantity));

  // Économies des Happy Deals
  double get totalSavings => subtotal - total;

  // Prix final après toutes les réductions (Happy Deals + code promo)
  double get totalAfterDiscount {
    // Debug
    // Debug
    if (discountAmount <= 0) return total;

    // S'assurer que la réduction ne rend pas le prix négatif
    double finalPrice = total - discountAmount;
    // Debug

    return finalPrice > 0 ? finalPrice : 0;
  }

  // Pourcentage de réduction total
  double get totalDiscountPercentage {
    if (subtotal <= 0) return 0;
    return ((subtotal - totalAfterDiscount) / subtotal) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'entrepriseId': entrepriseId,
      'sellerName': sellerName,
      'items': items.map((item) => item.toMaps()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'appliedPromoCode': appliedPromoCode,
      'discountAmount': discountAmount,
      // Ajouter les calculs pour référence
      'subtotal': subtotal,
      'total': total,
      'totalAfterDiscount': totalAfterDiscount,
      'totalSavings': totalSavings,
      'totalDiscountPercentage': totalDiscountPercentage,
    };
  }

  static Future<Cart?> fromFirestore(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      // Créer d'abord le Cart avec les données de base
      final cart = Cart(
        id: doc.id,
        entrepriseId: data['entrepriseId'] as String? ?? '',
        sellerId: data['sellerId'] as String? ?? '',
        sellerName: data['sellerName'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        appliedPromoCode: data['appliedPromoCode'] as String?,
        discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      );

      // Charger les items
      if (data['items'] != null) {
        final itemsData = data['items'] as List<dynamic>;
        for (var itemData in itemsData) {
          final productDoc = await FirebaseFirestore.instance
              .collection('products')
              .doc(itemData['productId'] as String?)
              .get();

          if (productDoc.exists) {
            final productData = productDoc.data()!;
            final product = Product(
              id: productDoc.id,
              name: productData['name'] as String? ?? '',
              price: (productData['price'] as num?)?.toDouble() ?? 0.0,
              tva: (productData['tva'] as num?)?.toDouble() ?? 0.0,
              imageUrl: List<String>.from(productData['images'] ?? []),
              sellerId: productData['sellerId'] as String? ?? '',
              entrepriseId: productData['entrepriseId'] as String? ?? '',
              description: productData['description'] as String? ?? '',
              stock: productData['stock'] as int? ?? 0,
              isActive: productData['isActive'] as bool? ?? false,
              discountedPrice:
                  (productData['discountedPrice'] as num?)?.toDouble(),
              hasActiveHappyDeal:
                  productData['hasActiveHappyDeal'] as bool? ?? false,
            );

            cart.items.add(CartItem(
              product: product,
              quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
              appliedPrice: (itemData['appliedPrice'] as num?)?.toDouble() ??
                  product.price,
            ));
          }
        }
      }

      return cart;
    } catch (e) {
      return null;
    }
  }

  // Helper method pour vérifier si le code promo peut être appliqué
  bool canApplyPromoCode(double promoValue, bool isPercentage) {
    if (isPercentage) {
      return promoValue > 0 && promoValue <= 100;
    } else {
      return promoValue > 0 && promoValue < total;
    }
  }
}
