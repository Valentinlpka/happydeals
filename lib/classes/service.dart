import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final int duration;
  final String professionalId;
  final List<String> images;
  final bool isActive;
  final String stripeProductId;
  final String stripePriceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
    required this.professionalId,
    required this.images,
    this.isActive = true,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration': duration,
      'professionalId': professionalId,
      'images': images,
      'isActive': isActive,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    return ServiceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      duration: map['duration'] ?? 30,
      professionalId: map['professionalId'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      isActive: map['isActive'] ?? true,
      stripeProductId: map['stripeProductId'] ?? '',
      stripePriceId: map['stripePriceId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
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
