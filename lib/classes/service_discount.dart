import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceDiscount {
  final String type;
  final double value;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  ServiceDiscount({
    required this.type,
    required this.value,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  factory ServiceDiscount.fromMap(Map<String, dynamic> map) {
    return ServiceDiscount(
      type: map['type'] ?? '',
      value: (map['value'] ?? 0.0).toDouble(),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
    };
  }

  bool isValid() {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }
}

class Service {
  final String id;
  final String companyId;
  final String name;
  final String description;
  final List<String> images;
  final double price;
  final double priceHT;
  final int tva;
  final int duration;
  final bool isActive;
  final ServiceDiscount? discount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Service({
    required this.id,
    required this.companyId,
    required this.name,
    required this.description,
    required this.images,
    required this.price,
    required this.priceHT,
    required this.tva,
    required this.duration,
    required this.isActive,
    this.discount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Service.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Service(
      id: doc.id,
      companyId: data['companyId'] as String,
      name: data['name'] as String,
      description: data['description'] as String,
      images: List<String>.from(data['images'] ?? []),
      price: (data['price'] as num).toDouble(),
      priceHT: (data['priceHT'] as num).toDouble(),
      tva: (data['tva'] as num).toInt(),
      duration: (data['duration'] as num).toInt(),
      isActive: data['isActive'] as bool,
      discount: data['discount'] != null
          ? ServiceDiscount.fromMap(data['discount'] as Map<String, dynamic>)
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
