import 'package:cloud_firestore/cloud_firestore.dart';

class RestaurantOrder {
  final String id;
  final double amount;
  final DateTime createdAt;
  final double? discountAmount;
  final double? distance;
  final List<RestaurantOrderItem> items;
  final String paymentId;
  final String? promoCode;
  final String restaurantAddress;
  final String restaurantLogo;
  final String restaurantName;
  final String status;
  final String type;
  final DateTime updatedAt;
  final String userId;
  final double? deliveryFee;
  final double? serviceFee;
  final double subtotal;
  final String? pickupTime;

  RestaurantOrder({
    required this.id,
    required this.amount,
    required this.createdAt,
    this.discountAmount,
    this.distance,
    required this.items,
    required this.paymentId,
    this.promoCode,
    required this.restaurantAddress,
    required this.restaurantLogo,
    required this.restaurantName,
    required this.status,
    required this.type,
    required this.updatedAt,
    required this.userId,
    this.deliveryFee,
    this.serviceFee,
    required this.subtotal,
    this.pickupTime,
  });

  factory RestaurantOrder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RestaurantOrder(
      id: doc.id,
      amount: (data['amount'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      discountAmount: data['discountAmount']?.toDouble(),
      distance: data['distance']?.toDouble(),
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => RestaurantOrderItem.fromMap(item as Map<String, dynamic>))
          .toList() ?? [],
      paymentId: data['paymentId'] ?? '',
      promoCode: data['promoCode'],
      restaurantAddress: data['restaurantAddress'] ?? '',
      restaurantLogo: data['restaurantLogo'] ?? '',
      restaurantName: data['restaurantName'] ?? '',
      status: data['status'] ?? 'pending',
      type: data['type'] ?? 'restaurant_order',
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      deliveryFee: data['deliveryFee']?.toDouble(),
      serviceFee: data['serviceFee']?.toDouble(),
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      pickupTime: data['pickupTime'],
    );
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'En préparation'; // Affiché comme en préparation
      case 'preparing':
        return 'En préparation';
      case 'ready':
        return 'Prête à retirer';
      case 'delivering':
        return 'Prête à retirer'; // Click & collect - pas de livraison
      case 'delivered':
        return 'Terminée'; // Click & collect - commande terminée
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Inconnue';
    }
  }

  String get statusIcon {
    switch (status) {
      case 'pending':
        return '⏳';
      case 'confirmed':
        return '✅';
      case 'preparing':
        return '👨‍🍳';
      case 'ready':
        return '📦';
      case 'delivering':
        return '🚗';
      case 'delivered':
        return '✅';
      case 'cancelled':
        return '❌';
      default:
        return '❓';
    }
  }

  bool get isActive => !['delivered', 'cancelled'].contains(status);
}

class RestaurantOrderItem {
  final String id;
  final String? menuId;
  final String name;
  final List<dynamic>? options;
  final int quantity;
  final double totalPrice;
  final String type;
  final double unitPrice;
  final String? updatedAt;
  final List<dynamic>? variants;

  RestaurantOrderItem({
    required this.id,
    this.menuId,
    required this.name,
    this.options,
    required this.quantity,
    required this.totalPrice,
    required this.type,
    required this.unitPrice,
    this.updatedAt,
    this.variants,
  });

  factory RestaurantOrderItem.fromMap(Map<String, dynamic> map) {
    return RestaurantOrderItem(
      id: map['id']?.toString() ?? '',
      menuId: map['menuId']?.toString(),
      name: map['name']?.toString() ?? '',
      options: map['options'] as List<dynamic>?,
      quantity: (map['quantity'] ?? 1) is int ? map['quantity'] : int.tryParse(map['quantity'].toString()) ?? 1,
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      type: map['type']?.toString() ?? 'item',
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      updatedAt: map['updatedAt']?.toString(),
      variants: map['variants'] as List<dynamic>?,
    );
  }
}