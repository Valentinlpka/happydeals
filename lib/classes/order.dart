import 'package:cloud_firestore/cloud_firestore.dart';

class Orders {
  final String id;
  final String userId;
  final String sellerId;
  final List<OrderItem> items;
  final double subtotal;
  final double happyDealSavings;
  final double totalPrice;
  final String status;
  final DateTime createdAt;
  final String pickupAddress;
  final String? pickupCode;
  final String entrepriseId;
  final String? promoCode;
  final double? discountAmount;

  Orders({
    required this.id,
    required this.userId,
    required this.sellerId,
    required this.items,
    required this.subtotal,
    required this.happyDealSavings,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.pickupAddress,
    required this.entrepriseId,
    this.pickupCode,
    this.promoCode,
    this.discountAmount,
  });

  factory Orders.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Orders(
      id: doc.id,
      userId: data['userId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => OrderItem.fromMap(item))
          .toList(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
      happyDealSavings: (data['happyDealSavings'] as num?)?.toDouble() ?? 0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
      status: data['status'] ?? '',
      entrepriseId: data['entrepriseId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      pickupAddress: data['pickupAddress'] ?? '',
      pickupCode: data['pickupCode'],
      promoCode: data['promoCode'],
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sellerId': sellerId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'happyDealSavings': happyDealSavings,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'pickupAddress': pickupAddress,
      'pickupCode': pickupCode,
      'entrepriseId': entrepriseId,
      'promoCode': promoCode,
      'discountAmount': discountAmount,
    };
  }
}

class OrderItem {
  final String productId;
  final String image;
  final String name;
  final int quantity;
  final double tva;
  final double originalPrice;
  final double appliedPrice;

  OrderItem({
    required this.productId,
    required this.image,
    required this.name,
    required this.quantity,
    required this.originalPrice,
    required this.appliedPrice,
    required this.tva,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      image: map['image'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble() ?? 0,
      appliedPrice: (map['appliedPrice'] as num?)?.toDouble() ?? 0,
      tva: (map['tva'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'image': image,
      'name': name,
      'quantity': quantity,
      'originalPrice': originalPrice,
      'appliedPrice': appliedPrice,
      'tva': tva,
    };
  }
}
