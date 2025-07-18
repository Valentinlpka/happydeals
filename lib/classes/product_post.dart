import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/attribute_config.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/classes/technical_detail.dart';

class ProductPost extends Post {
  final String productId;
  final String name;
  final String description;
  final String? additionalInfo;
  final List<String> images;
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
  final List<TechnicalDetail> technicalDetails;
  final List<String> keywords;
  final String pickupType;
  final String pickupAddress;
  final String pickupPostalCode;
  final String pickupCity;
  final double pickupLatitude;
  final double pickupLongitude;
  final ProductDiscount? discount;
  final Map<String, dynamic> attributes;
  final List<AttributeConfig> attributesConfig;

  double get priceHT => basePrice / (1 + (tva / 100));
  double get priceTTC => basePrice;
  double get tvaAmount => priceTTC - priceHT;

  double get finalPrice {
    if (discount != null && discount!.isValid()) {
      return discount!.calculateDiscountedPrice(priceTTC);
    }
    return priceTTC;
  }

  ProductPost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    super.updatedAt,
    required this.productId,
    required this.name,
    required this.description,
    this.additionalInfo,
    required this.images,
    required this.categoryPath,
    required this.categoryId,
    required this.basePrice,
    required this.tva,
    required this.isActive,
    required this.merchantId,
    required this.sellerId,
    required this.stripeProductId,
    required this.stripePriceId,
    required this.variants,
    required this.technicalDetails,
    required this.keywords,
    required this.pickupType,
    required this.pickupAddress,
    required this.pickupPostalCode,
    required this.pickupCity,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required super.companyName,
    required super.companyLogo,
    this.discount,
    Map<String, dynamic>? attributes,
    List<AttributeConfig>? attributesConfig,
    super.views = 0,
    super.likes = 0,
    super.likedBy = const [],
    super.commentsCount = 0,
    super.comments = const [],
  }) : attributes = attributes ?? {},
       attributesConfig = attributesConfig ?? [],
       super(type: 'product');

  factory ProductPost.fromProduct(Product product) {
    if (product.id.isEmpty) {
      throw Exception('Product ID cannot be empty');
    }

    if (product.variants.isEmpty) {
      throw Exception('Product must have at least one variant');
    }

    return ProductPost(
      id: FirebaseFirestore.instance.collection('posts').doc().id,
      companyId: product.sellerId,
      timestamp: DateTime.now(),
      productId: product.id,
      name: product.name,
      description: product.description,
      additionalInfo: product.additionalInfo,
      images: product.images,
      categoryPath: product.categoryPath,
      categoryId: product.categoryId,
      basePrice: product.basePrice,
      tva: product.tva,
      isActive: product.isActive,
      merchantId: product.merchantId,
      sellerId: product.sellerId,
      stripeProductId: product.stripeProductId,
      stripePriceId: product.stripePriceId,
      variants: product.variants,
      technicalDetails: product.technicalDetails,
      keywords: product.keywords,
      pickupType: product.pickupType,
      pickupAddress: product.pickupAddress,
      pickupPostalCode: product.pickupPostalCode,
      pickupCity: product.pickupCity,
      pickupLatitude: product.pickupLatitude,
      pickupLongitude: product.pickupLongitude,
      companyName: product.companyName,
      companyLogo: product.companyLogo,
      discount: product.discount,
      attributes: product.attributes,
      attributesConfig: product.attributesConfig,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'productId': productId,
      'name': name,
      'description': description,
      'additionalInfo': additionalInfo,
      'images': images,
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
      'technicalDetails': technicalDetails.map((t) => t.toMap()).toList(),
      'keywords': keywords,
      'pickupType': pickupType,
      'pickupAddress': pickupAddress,
      'pickupPostalCode': pickupPostalCode,
      'pickupCity': pickupCity,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'companyName': companyName,
      'companyLogo': companyLogo,
      'discount': discount?.toMap(),
      'attributes': attributes,
      'attributesConfig': attributesConfig.map((a) => a.toMap()).toList(),
    });
    return map;
  }

  Product toProduct() {
    return Product(
      id: productId,
      name: name,
      description: description,
      additionalInfo: additionalInfo,
      price: basePrice,
      images: images,
      keywords: keywords,
      companyId: companyId,
      technicalDetails: technicalDetails,
      city: pickupCity,
      categoryPath: categoryPath,
      categoryId: categoryId,
      pickupType: pickupType,
      pickupAddress: pickupAddress,
      pickupPostalCode: pickupPostalCode,
      pickupCity: pickupCity,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      basePrice: basePrice,
      tva: tva,
      isActive: isActive,
      merchantId: merchantId,
      sellerId: sellerId,
      stripeProductId: stripeProductId,
      stripePriceId: stripePriceId,
      variants: variants,
      companyName: companyName,
      companyLogo: companyLogo,
      discount: discount,
      attributes: attributes,
      attributesConfig: attributesConfig,
    );
  }

  factory ProductPost.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    debugPrint("Conversion du document ${doc.id}");

    // Conversion sécurisée des commentaires
    List<Comment> convertComments(List<dynamic>? commentsList) {
      if (commentsList == null) return [];
      return commentsList.map((c) {
        if (c is Map<String, dynamic>) {
          return Comment.fromMap(c);
        }
        return Comment.fromMap({});
      }).toList();
    }

    // Conversion sécurisée des coordonnées géographiques
    double pickupLat = 0.0;
    if (data['pickupLatitude'] != null) {
      if (data['pickupLatitude'] is num) {
        pickupLat = (data['pickupLatitude'] as num).toDouble();
      } else if (data['pickupLatitude'] is String) {
        pickupLat = double.tryParse(data['pickupLatitude']) ?? 0.0;
      }
    }

    double pickupLng = 0.0;
    if (data['pickupLongitude'] != null) {
      if (data['pickupLongitude'] is num) {
        pickupLng = (data['pickupLongitude'] as num).toDouble();
      } else if (data['pickupLongitude'] is String) {
        pickupLng = double.tryParse(data['pickupLongitude']) ?? 0.0;
      }
    }

    // Conversion des timestamps
    final timestamp = Post.convertTimestamp(data['timestamp']) ?? DateTime.now();
    final updatedAt = Post.convertTimestamp(data['updatedAt']);
    debugPrint("Timestamps convertis - timestamp: $timestamp, updatedAt: $updatedAt");

    // Récupération des variants
    final variants = (data['variants'] as List<dynamic>?)
            ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
            .toList() ??
        [];

    // Récupération des images avec fallback sur les variants
    List<String> images = List<String>.from(data['images'] ?? []);
    debugPrint('ProductPost - Images principales: $images');
    
    if (images.isEmpty && variants.isNotEmpty && variants.first.images.isNotEmpty) {
      debugPrint('ProductPost - Pas d\'images principales, utilisation des images de la variante: ${variants.first.images}');
      images = List<String>.from(variants.first.images);
    }
    
    debugPrint('ProductPost - Images finales: $images');

    return ProductPost(
      id: doc.id,
      companyId: data['companyId']?.toString() ?? '',
      timestamp: timestamp,
      updatedAt: updatedAt,  // Ajout du champ updatedAt
      productId: data['productId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      additionalInfo: data['additionalInfo']?.toString(),
      images: images,  // Utilisation des images récupérées
      categoryPath: List<String>.from(data['categoryPath'] ?? []),
      categoryId: data['categoryId']?.toString() ?? '',
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      tva: (data['tva'] ?? 20.0).toDouble(),
      isActive: data['isActive'] ?? true,
      merchantId: data['merchantId']?.toString() ?? '',
      sellerId: data['sellerId']?.toString() ?? '',
      stripeProductId: data['stripeProductId']?.toString() ?? '',
      stripePriceId: data['stripePriceId']?.toString() ?? '',
      variants: variants,
      technicalDetails: (data['technicalDetails'] as List<dynamic>?)
              ?.map((t) => TechnicalDetail.fromMap(t as Map<String, dynamic>))
              .toList() ??
          [],
      keywords: List<String>.from(data['keywords'] ?? []),
      pickupType: data['pickupType']?.toString() ?? 'company',
      pickupAddress: data['pickupAddress']?.toString() ?? '',
      pickupPostalCode: data['pickupPostalCode']?.toString() ?? '',
      pickupCity: data['pickupCity']?.toString() ?? '',
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      companyName: data['companyName']?.toString() ?? '',
      companyLogo: data['companyLogo']?.toString() ?? '',
      discount: data['discount'] != null
          ? ProductDiscount.fromMap(data['discount'] as Map<String, dynamic>)
          : null,
      attributes: data['attributes'] as Map<String, dynamic>? ?? {},
      attributesConfig: (data['attributesConfig'] as List<dynamic>?)
              ?.map((a) => AttributeConfig.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
      views: (data['views'] ?? 0).toInt(),
      likes: (data['likes'] ?? 0).toInt(),
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: (data['commentsCount'] ?? 0).toInt(),
      comments: convertComments(data['comments'] as List<dynamic>?),
    );
  }
}
