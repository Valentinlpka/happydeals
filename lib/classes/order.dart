// orders.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String variantId;
  final String name;
  final double originalPrice;
  final double appliedPrice;
  final int quantity;
  final double tva;
  final String image;
  final Map<String, String> variantAttributes;

  OrderItem({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.originalPrice,
    required this.appliedPrice,
    required this.quantity,
    required this.tva,
    required this.image,
    required this.variantAttributes,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      variantId: map['variantId'] ?? '',
      name: map['name'] ?? '',
      originalPrice: (map['originalPrice'] ?? 0.0).toDouble(),
      appliedPrice: (map['appliedPrice'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
      tva: (map['tva'] ?? 20.0).toDouble(),
      image: map['image'] ?? '',
      variantAttributes:
          Map<String, String>.from(map['variantAttributes'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'variantId': variantId,
      'name': name,
      'originalPrice': originalPrice,
      'appliedPrice': appliedPrice,
      'quantity': quantity,
      'tva': tva,
      'image': image,
      'variantAttributes': variantAttributes,
    };
  }
}

class Orders {
  final String id;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String pickupAddress;
  final String? pickupCode;
  final String? promoCode;
  final double? discountAmount;
  final String sellerId;
  final String userId;

  final String entrepriseId;
  final double totalPrice;

  Orders({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.items,
    required this.pickupAddress,
    this.pickupCode,
    this.promoCode,
    this.discountAmount,
    required this.sellerId,
    required this.userId,
    required this.entrepriseId,
    required this.totalPrice,
  });

  // Calcul du sous-total (somme des prix originaux)
  double get subtotal => items.fold(
        0,
        (total, item) => total + (item.originalPrice * item.quantity),
      );

  // Calcul des réductions totales
  double get totalDiscount => items.fold(
        0,
        (total, item) =>
            total + ((item.originalPrice - item.appliedPrice) * item.quantity),
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'items': items.map((item) => item.toMap()).toList(),
      'pickupAddress': pickupAddress,
      'pickupCode': pickupCode,
      'promoCode': promoCode,
      'discountAmount': discountAmount,
      'sellerId': sellerId,
      'userId': userId,
      'entrepriseId': entrepriseId,
      'totalPrice': totalPrice,
    };
  }

  factory Orders.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Orders(
      id: doc.id,
      status: data['status'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      items: (data['items'] as List<dynamic>)
          .map((item) => OrderItem.fromMap(item))
          .toList(),
      pickupAddress: data['pickupAddress'] ?? '',
      pickupCode: data['pickupCode'],
      promoCode: data['promoCode'],
      discountAmount: data['discountAmount']?.toDouble(),
      sellerId: data['sellerId'] ?? '',
      entrepriseId: data['entrepriseId'] ?? '',
      userId: data['userId'] ?? '',
      totalPrice: (data['totalPrice'] ?? 0.0).toDouble(),
    );
  }
}
