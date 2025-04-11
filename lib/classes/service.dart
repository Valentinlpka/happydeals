import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int tva;
  final int duration;
  final String professionalId;
  final List<String> images;
  final bool isActive;
  final String stripeProductId;
  final String stripePriceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? discount;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.tva,
    required this.duration,
    required this.professionalId,
    required this.images,
    this.isActive = true,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.createdAt,
    required this.updatedAt,
    this.discount,
  });

  bool get hasActivePromotion {
    if (discount == null) return false;

    final startDate = (discount!['startDate'] as Timestamp).toDate();
    final endDate = (discount!['endDate'] as Timestamp).toDate();
    final isActive = discount!['isActive'] as bool;

    return isActive &&
        DateTime.now().isAfter(startDate) &&
        DateTime.now().isBefore(endDate);
  }

  double get finalPrice {
    if (hasActivePromotion) {
      if (discount!['type'] == 'percentage') {
        return price * (1 - (discount!['value'] as num) / 100);
      } else if (discount!['type'] == 'fixed') {
        return price - (discount!['value'] as num);
      }
    }
    return price;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      'tva': tva,
      'professionalId': professionalId,
      'images': images,
      'isActive': isActive,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'discount': discount,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    // Conversion des types numériques
    final price = map['price'] is int
        ? (map['price'] as int).toDouble()
        : (map['price'] ?? 0.0).toDouble();

    final tva =
        map['tva'] is int ? map['tva'] as int : (map['tva'] ?? 0).toInt();

    final duration = map['duration'] is int
        ? map['duration'] as int
        : (map['duration'] ?? 30).toInt();

    // Gestion du discount
    Map<String, dynamic>? discountMap;
    if (map['discount'] != null) {
      final discountData = map['discount'] as Map<String, dynamic>;
      discountMap = {
        'type': discountData['type'] ?? '',
        'value': discountData['value'] is int
            ? (discountData['value'] as int).toDouble()
            : (discountData['value'] ?? 0.0).toDouble(),
        'startDate': discountData['startDate'],
        'endDate': discountData['endDate'],
        'isActive': discountData['isActive'] ?? true,
      };
    }

    return ServiceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      tva: tva,
      description: map['description'] ?? '',
      price: price,
      duration: duration,
      professionalId: map['professionalId'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      isActive: map['isActive'] ?? true,
      stripeProductId: map['stripeProductId'] ?? '',
      stripePriceId: map['stripePriceId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      discount: discountMap,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
