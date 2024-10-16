import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double tva;
  final String description;
  final double price;
  final List<String> imageUrl;
  final String sellerId;
  final String entrepriseId;
  final int stock;
  final bool isActive;

  // Nouveaux champs pour le Happy Deal
  final bool hasActiveHappyDeal;
  final double? discountedPrice;
  final double? discountPercentage;
  final DateTime? happyDealStartDate;
  final DateTime? happyDealEndDate;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.tva,
    required this.imageUrl,
    required this.sellerId,
    required this.entrepriseId,
    required this.stock,
    required this.isActive,
    this.hasActiveHappyDeal = false,
    this.discountedPrice,
    this.discountPercentage,
    this.happyDealStartDate,
    this.happyDealEndDate,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      tva: (map['tva'] ?? 0).toDouble(),
      imageUrl: List<String>.from(map['images'] ?? []),
      sellerId: map['merchantId'] ?? '',
      entrepriseId: map['sellerId'] ?? '',
      stock: map['stock'] ?? 0,
      isActive: map['isActive'] ?? false,
      hasActiveHappyDeal: map['hasActiveHappyDeal'] ?? false,
      discountedPrice: map['discountedPrice']?.toDouble(),
      discountPercentage: map['discountPercentage']?.toDouble(),
      happyDealStartDate: map['happyDealStartDate'] != null
          ? (map['happyDealStartDate'] as Timestamp).toDate()
          : null,
      happyDealEndDate: map['happyDealEndDate'] != null
          ? (map['happyDealEndDate'] as Timestamp).toDate()
          : null,
    );
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      tva: (data['tva'] ?? 0).toDouble(),
      imageUrl: List<String>.from(data['images'] ?? []),
      sellerId: data['merchantId'] ?? '',
      entrepriseId: data['sellerId'] ?? '',
      stock: data['stock'] ?? 0,
      isActive: data['isActive'] ?? false,
      hasActiveHappyDeal: data['hasActiveHappyDeal'] ?? false,
      discountedPrice: data['discountedPrice']?.toDouble(),
      discountPercentage: data['discountPercentage']?.toDouble(),
      happyDealStartDate: data['happyDealStartDate'] != null
          ? (data['happyDealStartDate'] as Timestamp).toDate()
          : null,
      happyDealEndDate: data['happyDealEndDate'] != null
          ? (data['happyDealEndDate'] as Timestamp).toDate()
          : null,
    );
  }

  // Nouvelle méthode fromDocument
  factory Product.fromDocument(DocumentSnapshot doc) {
    return Product.fromFirestore(doc);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'tva': tva,
      'images': imageUrl,
      'merchantId': sellerId,
      'entrepriseId': entrepriseId,
      'stock': stock,
      'isActive': isActive,
      'discountPercentage': discountPercentage,
      'happyDealStartDate': happyDealStartDate != null
          ? Timestamp.fromDate(happyDealStartDate!)
          : null,
      'happyDealEndDate': happyDealEndDate != null
          ? Timestamp.fromDate(happyDealEndDate!)
          : null,
    };
  }
}
