import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> imageUrl;
  final String sellerId;
  final int stock;
  final bool isActive;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.sellerId,
    required this.stock,
    required this.isActive,
  });

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: List<String>.from(map['images'] ?? []),
      sellerId: map['merchantId'] ?? '',
      stock: map['stock'] ?? 0,
      isActive: map['isActive'] ?? false,
    );
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: List<String>.from(data['images'] ?? []),
      sellerId: data['merchantId'] ?? '',
      stock: data['stock'] ?? 0,
      isActive: data['isActive'] ?? false,
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
      'images': imageUrl,
      'merchantId': sellerId,
      'stock': stock,
      'isActive': isActive,
    };
  }
}
