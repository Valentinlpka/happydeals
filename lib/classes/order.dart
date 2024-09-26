// lib/models/order.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Orders {
  final String id;
  final String userId;
  final String sellerId;
  final List<OrderItem> items;
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
    Map data = doc.data() as Map<String, dynamic>;
    return Orders(
        id: doc.id,
        userId: data['userId'] ?? '',
        sellerId: data['sellerId'] ?? '',
        items: (data['items'] as List? ?? [])
            .map((item) => OrderItem.fromMap(item))
            .toList(),
        totalPrice: (data['totalPrice'] ?? 0).toDouble(),
        status: data['status'] ?? '',
        entrepriseId: data['entrepriseId'] ?? '',
        createdAt: (data['createdAt'] as Timestamp).toDate(),
        pickupAddress: data['pickupAddress'] ?? '',
        pickupCode: data['pickupCode'],
        promoCode: data['promoCode'],
        discountAmount: data['discountAmount']);
  }
}

class OrderItem {
  final String productId;
  final String image;
  final String name;
  final int quantity;
  final double tva;
  final double price;

  OrderItem({
    required this.productId,
    required this.image,
    required this.name,
    required this.quantity,
    required this.price,
    required this.tva,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      image: map['image'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      tva: (map['tva'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'image': image,
      'name': name,
      'quantity': quantity,
      'price': price,
      'tva': tva,
    };
  }
}
