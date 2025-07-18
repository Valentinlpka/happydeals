import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/attribute_config.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/technical_detail.dart';

class Product extends Post {
  final String name;
  final String description;
  final String? additionalInfo;
  final double price;
  final List<String> _images; // Renommé en _images pour utiliser le getter
  final String city;
  final List<String> categoryPath;
  final String categoryId;
  final double basePrice;
  final double tva;
  final bool isActive;
  final String merchantId;
  final String sellerId;
  final String stripeProductId;
  final String pickupType;
  final String pickupAddress;
  final String pickupPostalCode;
  final String pickupCity;
  final double pickupLatitude;
  final double pickupLongitude;
  final String stripePriceId;
  final List<TechnicalDetail> technicalDetails;
  final List<String> keywords;
  final List<ProductVariant> variants;
  final ProductDiscount? discount;
  final Map<String, dynamic> attributes;
  final List<AttributeConfig> attributesConfig;
  double? distance;

  // Getter pour les images qui prend en compte les variantes
  List<String> get images {
    if (_images.isNotEmpty) return _images;
    
    // Si pas d'images principales, on prend les images des variantes
    final variantImages = variants.expand((v) => v.images).toList();
    return variantImages.isNotEmpty ? variantImages : [];
  }

  Product({
    required super.id,
    required super.companyId,
    required this.name,
    required this.description,
    this.additionalInfo,
    required this.price,
    required List<String> images,
    required this.keywords,
    required this.technicalDetails,
    required this.city,
    required this.categoryPath,
    required this.categoryId,
    required this.pickupType,
    required this.pickupAddress,
    required this.pickupPostalCode,
    required this.pickupCity,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.basePrice,
    this.tva = 20.0,
    required this.isActive,
    required this.merchantId,
    required this.sellerId,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.variants,
    required super.companyName,
    required super.companyLogo,
    Map<String, dynamic>? attributes,
    List<AttributeConfig>? attributesConfig,
    this.discount,
    this.distance,
    DateTime? timestamp,
    super.updatedAt,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    List<Map<String, dynamic>> comments = const [],
  }) : _images = images,
       attributes = attributes ?? {},
       attributesConfig = attributesConfig ?? [],
       super(
         timestamp: timestamp ?? DateTime.now(),
         type: 'product',
         comments: comments.map((c) => Comment.fromMap(c)).toList(),
       );

  double get priceHT => basePrice / (1 + (tva / 100));
  double get priceTTC => basePrice;
  double get tvaAmount => priceTTC - priceHT;

  double get finalPrice {
    if (discount != null && discount!.isValid()) {
      return discount!.calculateDiscountedPrice(priceTTC);
    }
    return priceTTC;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'additionalInfo': additionalInfo,
      'price': price,
      'images': _images,
      'companyId': companyId,
      'city': city,
      'keywords': keywords,
      'categoryPath': categoryPath,
      'pickupType': pickupType,
      'pickupAddress': pickupAddress,
      'pickupPostalCode': pickupPostalCode,
      'pickupCity': pickupCity,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'categoryId': categoryId,
      'basePrice': basePrice,
      'technicalDetails': technicalDetails.map((t) => t.toMap()).toList(),
      'tva': tva,
      'isActive': isActive,
      'merchantId': merchantId,
      'sellerId': sellerId,
      'stripeProductId': stripeProductId,
      'stripePriceId': stripePriceId,
      'variants': variants.map((v) => v.toMap()).toList(),
      'attributes': attributes,
      'attributesConfig': attributesConfig.map((a) => a.toMap()).toList(),
      'companyName': companyName,
      'companyLogo': companyLogo,
      'discount': discount?.toMap(),
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    debugPrint("Conversion du document ${doc.id}");

    // Fonction utilitaire pour convertir en double
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Remplacer la virgule par un point si nécessaire
        final normalizedValue = value.replaceAll(',', '.');
        return double.tryParse(normalizedValue) ?? 0.0;
      }
      debugPrint('❌ Impossible de convertir en double: $value (type: ${value.runtimeType})');
      return 0.0;
    }

    // Fonction pour gérer additionalInfo qui peut être une String ou une List
    String? parseAdditionalInfo(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is List) return value.isEmpty ? null : value.join('\n');
      return null;
    }

    try {
      debugPrint("Traitement des données pour le document ${doc.id}");
    return Product(
      id: doc.id,
        companyId: data['companyId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
        additionalInfo: parseAdditionalInfo(data['additionalInfo']),
        price: parseDouble(data['price'] ?? data['basePrice']),
        images: List<String>.from(data['images'] ?? []),
        keywords: List<String>.from(data['keywords'] ?? []),
        technicalDetails: (data['technicalDetails'] as List<dynamic>?)
            ?.map((t) => TechnicalDetail.fromMap(t as Map<String, dynamic>))
            .toList() ?? [],
        city: data['pickupCity'] ?? '',
      categoryPath: List<String>.from(data['categoryPath'] ?? []),
      categoryId: data['categoryId'] ?? '',
      pickupType: data['pickupType'] ?? '',
      pickupAddress: data['pickupAddress'] ?? '',
      pickupPostalCode: data['pickupPostalCode'] ?? '',
      pickupCity: data['pickupCity'] ?? '',
        pickupLatitude: parseDouble(data['pickupLatitude']),
        pickupLongitude: parseDouble(data['pickupLongitude']),
        basePrice: parseDouble(data['basePrice']),
        tva: parseDouble(data['tva']),
        isActive: data['isActive'] ?? true,
      merchantId: data['merchantId'] ?? '',
        sellerId: data['companyId'] ?? '',
      stripeProductId: data['stripeProductId'] ?? '',
        stripePriceId: data['stripePriceId'] ?? '',
        variants: (data['variants'] as List<dynamic>?)
            ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
            .toList() ?? [],
        companyName: data['companyName'] ?? '',
        companyLogo: data['companyLogo'] ?? '',
        discount: data['discount'] == null || data['discount'] == false
            ? null
            : ProductDiscount.fromMap(data['discount'] as Map<String, dynamic>),
      attributes: data['attributes'] as Map<String, dynamic>? ?? {},
        attributesConfig: (data['attributesConfig'] as List<dynamic>?)
            ?.map((a) => AttributeConfig.fromMap(a as Map<String, dynamic>))
            .toList() ?? [],
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        views: (data['views'] ?? 0).toInt(),
        likes: (data['likes'] ?? 0).toInt(),
        likedBy: List<String>.from(data['likedBy'] ?? []),
        commentsCount: (data['commentsCount'] ?? 0).toInt(),
        comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
    );
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors de la conversion du document ${doc.id}: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

class ProductVariant {
  final String id;
  final Map<String, String> attributes;
  final double price;
  final int stock;
  final String stripePriceId;
  final List<String> images;
  final ProductDiscount? discount;

  ProductVariant({
    required this.id,
    required this.attributes,
    required this.price,
    required this.stock,
    required this.stripePriceId,
    required this.images,
    this.discount,
  });

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      id: map['id'] ?? '',
      attributes: Map<String, String>.from(
        (map['attributes'] ?? {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      ),
      price: (map['price'] ?? 0.0).toDouble(),
      stock: (map['stock'] ?? 0).toInt(),
      stripePriceId: map['stripePriceId'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      discount: map['discount'] == null || map['discount'] == false
          ? null
          : ProductDiscount.fromMap(map['discount'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'attributes': attributes,
      'price': price,
      'stock': stock,
      'stripePriceId': stripePriceId,
      'images': images,
      'discount': discount?.toMap(),
    };
  }

  double get finalPrice {
    if (discount != null && discount!.isValid()) {
      return discount!.calculateDiscountedPrice(price);
    }
    return price;
  }
}

class ProductDiscount {
  final String type;
  final double value;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  ProductDiscount({
    required this.type,
    required this.value,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  factory ProductDiscount.fromMap(Map<String, dynamic> map) {
    // Conversion sécurisée des dates
    DateTime getDateTime(dynamic timestamp) {
      if (timestamp == null) return DateTime.now();
      
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp is DateTime) {
        return timestamp;
      } else if (timestamp is Map<String, dynamic>) {
        if (timestamp.containsKey('_seconds')) {
          final seconds = timestamp['_seconds'] as int;
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
      return DateTime.now();
    }

    return ProductDiscount(
      type: map['type'] ?? 'percentage',
      value: (map['value'] ?? 0.0).toDouble(),
      startDate: getDateTime(map['startDate']),
      endDate: getDateTime(map['endDate']),
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
    if (!isActive) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  double calculateDiscountedPrice(double originalPrice) {
    if (!isValid()) return originalPrice;
    
    if (type == 'percentage') {
      return originalPrice * (1 - value / 100);
    } else {
      return originalPrice - value;
    }
  }
}
