import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/product.dart';

class CartItem {
  final Product product;
  final ProductVariant variant;
  final double appliedPrice;
  final double tva;
  int quantity;

  CartItem({
    required this.product,
    required this.variant,
    required this.appliedPrice,
    required this.tva,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'variantId': variant.id,
      'name': product.name,
      'originalPrice': variant.price,
      'appliedPrice': appliedPrice,
      'quantity': quantity,
      'tva': tva,
      'image': variant.images.isNotEmpty ? variant.images[0] : '',
      'variantAttributes': variant.attributes,
    };
  }

  Map<String, dynamic> toMaps() {
    return {
      'productId': product.id,
      'variantId': variant.id,
      'name': product.name,
      'images': variant.images,
      'price': variant.price,
      'attributes': variant.attributes,
      'quantity': quantity,
      'appliedPrice': appliedPrice,
      'tva': product.tva,
      'sellerId': product.sellerId,
      'entrepriseId': product.sellerId,
      'description': product.description,
      'stock': variant.stock,
      'isActive': product.isActive,
    };
  }

  static CartItem? fromMap(Map<String, dynamic> map, Product product) {
    final variantId = map['variantId'] as String?;
    if (variantId == null) return null;

    final variant = product.variants.firstWhere(
      (v) => v.id == variantId,
      orElse: () => throw Exception('Variant not found'),
    );

    final basePrice = variant.price;
    double appliedPrice =
        (map['appliedPrice'] as num?)?.toDouble() ?? basePrice;

    // Appliquer la réduction de la variante si elle existe et est valide
    if (variant.discount?.isValid() ?? false) {
      appliedPrice = variant.discount!.calculateDiscountedPrice(basePrice);
    }

    return CartItem(
      product: product,
      variant: variant,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      appliedPrice: appliedPrice,
      tva: (map['tva'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Cart {
  String id;
  final String sellerId;
  final String merchantId;
  final String sellerName;
  final List<CartItem> items;
  final DateTime createdAt;
  String? appliedPromoCode;
  double discountAmount;

  Cart({
    required this.id,
    required this.sellerId,
    required this.merchantId,
    required this.sellerName,
    List<CartItem>? items,
    DateTime? createdAt,
    this.appliedPromoCode,
    this.discountAmount = 0.0,
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt).inHours > 24;

  // Prix total sans réductions de code promo
  double get total => items.fold(
        0,
        (sum, item) => sum + (item.appliedPrice * item.quantity),
      );

  // Prix final après toutes les réductions (codes promo)
  double get finalTotal {
    if (discountAmount <= 0) return total;
    double finalPrice = total - discountAmount;
    return finalPrice > 0 ? finalPrice : 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'merchantId': merchantId,
      'sellerName': sellerName,
      'items': items.map((item) => item.toMaps()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(
        createdAt.add(const Duration(hours: 24)),
      ),
      'appliedPromoCode': appliedPromoCode,
      'discountAmount': discountAmount,
      'total': total,
      'finalTotal': finalTotal,
    };
  }

  static Future<Cart?> fromFirestore(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      final cart = Cart(
        id: doc.id,
        sellerId: data['sellerId'] as String? ?? '',
        merchantId: data['merchantId'] as String? ?? '',
        sellerName: data['sellerName'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        appliedPromoCode: data['appliedPromoCode'] as String?,
        discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      );

      if (data['items'] != null) {
        final itemsData = data['items'] as List<dynamic>;
        for (var itemData in itemsData) {
          final productDoc = await FirebaseFirestore.instance
              .collection('products')
              .doc(itemData['productId'] as String?)
              .get();

          if (productDoc.exists) {
            final product = Product.fromFirestore(productDoc);
            final cartItem = CartItem.fromMap(itemData, product);
            if (cartItem != null) {
              cart.items.add(cartItem);
            }
          }
        }
      }

      return cart;
    } catch (e) {
      print('Error creating Cart from Firestore: $e');
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
