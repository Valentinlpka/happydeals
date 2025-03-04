import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final String companyId;
  final String city;
  final List<String> categoryPath;
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
  final Map<String, dynamic> attributes;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.companyId,
    required this.city,
    required this.categoryPath,
    required this.categoryId,
    required this.basePrice,
    this.tva = 20.0,
    required this.isActive,
    required this.merchantId,
    required this.sellerId,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.variants,
    Map<String, dynamic>? attributes,
    this.discount,
  }) : attributes = attributes ?? {};

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
      'description': description,
      'price': price,
      'images': images,
      'companyId': companyId,
      'city': city,
      'categoryPath': categoryPath,
      'categoryId': categoryId,
      'basePrice': basePrice,
      'tva': tva,
      'isActive': isActive,
      'merchantId': merchantId,
      'sellerId': sellerId,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'variants': variants.map((v) => v.toMap()).toList(),
      'attributes': attributes,
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final variants = (data['variants'] as List<dynamic>? ?? [])
        .map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
        .toList();

    // Récupérer les images de la première variante si elle existe
    final List<String> images =
        variants.isNotEmpty ? List<String>.from(variants.first.images) : [];

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['basePrice'] ?? 0.0)
          .toDouble(), // Utiliser basePrice au lieu de price
      images: images, // Utiliser les images de la première variante
      companyId: data['sellerId'] ?? '',
      city: data['city'] ?? '',
      categoryPath: List<String>.from(data['categoryPath'] ?? []),
      categoryId: data['categoryId'] ?? '',
      basePrice: (data['basePrice'] ?? 0).toDouble(),
      tva: (data['tva'] ?? 20).toDouble(),
      isActive: data['isActive'] ?? true,
      merchantId: data['merchantId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      stripeProductId: data['stripeProductId'] ?? '',
      stripePriceId: variants.isNotEmpty ? variants.first.stripePriceId : '',
      variants: variants,
      attributes: data['attributes'] as Map<String, dynamic>? ?? {},
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
