import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final List<String> categoryPath;
  final String description;
  final String categoryId;
  final double basePrice;
  final double tva;
  final bool isActive;
  final String merchantId;
  final String sellerId;
  final String stripeProductId;
  final String stripePriceId;
  final List<ProductVariant> variants;
  final ProductDiscount? discount;

  Product({
    required this.id,
    required this.name,
    required this.categoryPath,
    required this.description,
    required this.categoryId,
    required this.basePrice,
    this.tva = 20.0,
    required this.isActive,
    required this.merchantId,
    required this.sellerId,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.variants,
    this.discount,
  });

  double get priceHT => basePrice / (1 + (tva / 100));
  double get priceTTC => basePrice;
  double get tvaAmount => priceTTC - priceHT;

  double get finalPrice {
    if (discount != null && discount!.isValid()) {
      return discount!.calculateDiscountedPrice(priceTTC);
    }
    return priceTTC;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryPath': categoryPath,
      'description': description,
      'categoryId': categoryId,
      'basePrice': basePrice,
      'tva': tva,
      'isActive': isActive,
      'merchantId': merchantId,
      'sellerId': sellerId,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'variants': variants.map((v) => v.toMap()).toList(),
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      categoryPath: List<String>.from(data['categoryPath'] ?? []),
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      tva: (data['tva'] ?? 20).toDouble(),
      isActive: data['isActive'] ?? false,
      merchantId: data['merchantId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      stripeProductId: data['stripeProductId'] ?? '',
      stripePriceId: data['stripePriceId'] ?? '',
      variants: (data['variants'] as List<dynamic>? ?? [])
          .map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
          .toList(),
      discount: data['discount'] != null
          ? ProductDiscount.fromMap(data['discount'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ProductVariant {
  final String id;
  final Map<String, String> attributes;
  final double price;
  final int stock;
  final List<String> images;
  final ProductDiscount? discount;
  final String stripePriceId;

  ProductVariant({
    required this.id,
    required this.attributes,
    required this.price,
    required this.stock,
    required this.images,
    this.discount,
    required this.stripePriceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attributes': attributes,
      'price': price,
      'stock': stock,
      'images': images,
      'discount': discount?.toMap(),
      'stripePriceId': stripePriceId,
    };
  }

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      attributes: Map<String, String>.from(map['attributes'] ?? {}),
      price: (map['price'] ?? 0).toDouble(),
      stock: map['stock'] ?? 0,
      images: List<String>.from(map['images'] ?? []),
      discount: map['discount'] != null
          ? ProductDiscount.fromMap(map['discount'])
          : null,
      stripePriceId: map['stripePriceId'] ?? '',
    );
  }
}

class ProductDiscount {
  final String type;
  final double value;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool applyToAllVariants;
  final List<String> appliedVariantIds;
  final bool isActive;

  ProductDiscount({
    required this.type,
    required this.value,
    this.startDate,
    this.endDate,
    this.applyToAllVariants = true,
    this.appliedVariantIds = const [],
    this.isActive = true,
  });

  bool isValid() {
    if (!isActive) return false;

    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;

    return true;
  }

  bool appliesTo(String variantId) {
    return applyToAllVariants || appliedVariantIds.contains(variantId);
  }

  double calculateDiscountedPrice(double originalPrice) {
    if (!isValid()) return originalPrice;

    if (type == 'percentage') {
      return originalPrice * (1 - (value / 100));
    } else {
      return originalPrice - value;
    }
  }

  factory ProductDiscount.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    return ProductDiscount(
      type: map['type'] ?? 'percentage',
      value: (map['value'] ?? 0).toDouble(),
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      applyToAllVariants: map['applyToAllVariants'] ?? true,
      appliedVariantIds: List<String>.from(map['appliedVariantIds'] ?? []),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'value': value,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'applyToAllVariants': applyToAllVariants,
      'appliedVariantIds': appliedVariantIds,
      'isActive': isActive,
    };
  }
}
