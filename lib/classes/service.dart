import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceDiscount {
  final String type;
  final double value;
  final Timestamp? startDate;
  final Timestamp? endDate;
  final bool isActive;
  final String? promotionPostId;

  ServiceDiscount({
    required this.type,
    required this.value,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.promotionPostId,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
      'promotionPostId': promotionPostId,
    };
  }

  factory ServiceDiscount.fromMap(Map<String, dynamic> map) {
    return ServiceDiscount(
      type: map['type'] ?? 'percentage',
      value: (map['value'] is int) 
          ? (map['value'] as int).toDouble() 
          : (map['value'] ?? 0.0).toDouble(),
      startDate: map['startDate'],
      endDate: map['endDate'],
      isActive: map['isActive'] ?? true,
      promotionPostId: map['promotionPostId'],
    );
  }
}

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
  final DateTime timestamp;
  final DateTime updatedAt;
  final ServiceDiscount? discount;
  final String companyName;
  final String companyLogo;
  final Map<String, dynamic> companyAddress;
  final String executionLocation;
  final double? travelRadius;
  final int minParticipants;
  final int maxParticipants;
  final String cancellationPolicy;
  final String? cancellationPolicyOther;
  final List<String> providedEquipment;
  final List<String> keywords;
  final String? additionalInfo;
  final String categoryId;
  final List<String> categoryPath;

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
    required this.timestamp,
    required this.updatedAt,
    this.discount,
    required this.companyName,
    required this.companyLogo,
    required this.companyAddress,
    this.executionLocation = 'on_site',
    this.travelRadius,
    this.minParticipants = 1,
    this.maxParticipants = 1,
    this.cancellationPolicy = 'no_cancellation',
    this.cancellationPolicyOther,
    this.providedEquipment = const [],
    this.keywords = const [],
    this.additionalInfo,
    this.categoryId = '',
    this.categoryPath = const [],
  });

  bool get hasActivePromotion {
    if (discount == null) return false;

    final startDate = discount!.startDate?.toDate();
    final endDate = discount!.endDate?.toDate();
    final isActive = discount!.isActive;

    return isActive &&
        (startDate == null || DateTime.now().isAfter(startDate)) &&
        (endDate == null || DateTime.now().isBefore(endDate));
  }

  double get finalPrice {
    if (hasActivePromotion) {
      if (discount!.type == 'percentage') {
        return price * (1 - discount!.value / 100);
      } else if (discount!.type == 'fixed') {
        return price - discount!.value;
      }
    }
    return price;
  }

  double get discountPercentage {
    if (!hasActivePromotion) return 0;
    if (discount!.type == 'percentage') {
      return discount!.value;
    } else {
      return (discount!.value / price) * 100;
    }
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
      'timestamp': timestamp,
      'updatedAt': updatedAt,
      'discount': discount?.toMap(),
      'companyName': companyName,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress,
      'executionLocation': executionLocation,
      'travelRadius': travelRadius,
      'minParticipants': minParticipants,
      'maxParticipants': maxParticipants,
      'cancellationPolicy': cancellationPolicy,
      'cancellationPolicyOther': cancellationPolicyOther,
      'providedEquipment': providedEquipment,
      'keywords': keywords,
      'additionalInfo': additionalInfo,
      'categoryId': categoryId,
      'categoryPath': categoryPath,
    };
  }

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final price = map['price'] is int
        ? (map['price'] as int).toDouble()
        : (map['price'] ?? 0.0).toDouble();

    final tva =
        map['tva'] is int ? map['tva'] as int : (map['tva'] ?? 0).toInt();

    final duration = map['duration'] is int
        ? map['duration'] as int
        : (map['duration'] ?? 30).toInt();

    ServiceDiscount? discount;
    if (map['discount'] != null) {
      discount = ServiceDiscount.fromMap(map['discount'] as Map<String, dynamic>);
    }

    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return ServiceModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      tva: tva,
      description: map['description'] ?? '',
      price: price,
      duration: duration,
      professionalId: map['companyId'] ?? map['professionalId'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      isActive: map['isActive'] ?? true,
      stripeProductId: map['stripeProductId'] ?? '',
      stripePriceId: map['stripePriceId'] ?? '',
      timestamp: parseTimestamp(map['timestamp'] ?? map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      discount: discount,
      companyName: map['companyName'] ?? '',
      companyLogo: map['companyLogo'] ?? '',
      companyAddress: Map<String, dynamic>.from(map['companyAddress'] ?? {}),
      executionLocation: map['executionLocation'] ?? 'on_site',
      travelRadius: (map['travelRadius'] ?? 0.0).toDouble(),
      minParticipants: map['minParticipants'] ?? 1,
      maxParticipants: map['maxParticipants'] ?? 1,
      cancellationPolicy: map['cancellationPolicy'] ?? 'no_cancellation',
      cancellationPolicyOther: map['cancellationPolicyOther'],
      providedEquipment: List<String>.from(map['providedEquipment'] ?? []),
      keywords: List<String>.from(map['keywords'] ?? []),
      additionalInfo: map['additionalInfo'],
      categoryId: map['categoryId'] ?? '',
      categoryPath: List<String>.from(map['categoryPath'] ?? []),
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
