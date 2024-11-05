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
  final String sellerName;
  final List<CartItem> items;
  final DateTime createdAt;
  final DateTime expiresAt;
  String? appliedPromoCode;
  double discountAmount;

  Cart({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    List<CartItem>? items,
    DateTime? createdAt,
    this.appliedPromoCode,
    this.discountAmount = 0.0,
  })  : items = items ?? [],
        createdAt = createdAt ?? DateTime.now(),
        expiresAt = (createdAt ?? DateTime.now()).add(const Duration(hours: 2));

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  double get subtotal =>
      items.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  double get total =>
      items.fold(0, (sum, item) => sum + (item.appliedPrice * item.quantity));

  double get totalSavings => subtotal - total;

  double get totalAfterDiscount => total - discountAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'appliedPromoCode': appliedPromoCode,
      'discountAmount': discountAmount,
    };
  }

  static Future<Cart?> fromFirestore(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;

      // Créer d'abord le Cart avec les données de base
      final cart = Cart(
        id: doc.id,
        sellerId: data['sellerId'] as String? ?? '',
        sellerName: data['sellerName'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        appliedPromoCode: data['appliedPromoCode'] as String?,
        discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      );

      // Ensuite, charger les items s'ils existent
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
      print('Erreur lors de la conversion du Cart: $e');
      return null;
    }
  }
}
