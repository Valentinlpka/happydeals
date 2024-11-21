import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';

class ProductPost extends Post {
  final String productId;
  final String name;
  final double price;
  final String description;
  final List<String> images;
  final bool hasActiveHappyDeal;
  final double? discountedPrice;
  final double? discountPercentage;

  ProductPost({
    required super.id,
    required super.companyId, // S'assurer que ce champ est toujours rempli
    required super.timestamp,
    required this.productId,
    required this.name,
    required this.price,
    required this.description,
    required this.images,
    required String sellerId, // Ajouter sellerId comme paramètre requis
    this.hasActiveHappyDeal = false,
    this.discountedPrice,
    this.discountPercentage,
    super.views = 0,
    super.likes = 0,
    super.likedBy = const [],
    super.commentsCount = 0,
    super.comments = const [],
  }) : super(type: 'product');

  factory ProductPost.fromProduct(Product product) {
    if (product.id.isEmpty) {
      throw Exception('Product ID cannot be empty');
    }

    if (product.imageUrl.isEmpty) {
      throw Exception('Product must have at least one image');
    }

    // Utiliser sellerId comme companyId si entrepriseId est vide
    final String companyId = product.entrepriseId.isNotEmpty
        ? product.entrepriseId
        : product.sellerId;

    if (companyId.isEmpty) {
      throw Exception('CompanyId cannot be empty');
    }

    return ProductPost(
      id: FirebaseFirestore.instance.collection('posts').doc().id,
      companyId: companyId, // Utiliser le companyId déterminé ci-dessus
      timestamp: DateTime.now(),
      productId: product.id,
      name: product.name,
      price: product.price,
      description: product.description,
      images: product.imageUrl,
      sellerId: product.sellerId,
      hasActiveHappyDeal: product.hasActiveHappyDeal,
      discountedPrice: product.discountedPrice,
      discountPercentage: product.discountPercentage,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'productId': productId,
      'name': name,
      'price': price,
      'description': description,
      'images': images,
      'hasActiveHappyDeal': hasActiveHappyDeal,
      'discountedPrice': discountedPrice,
      'discountPercentage': discountPercentage,
      'sellerId': companyId, // Ajouter le sellerId dans le map
    });
    return map;
  }

  factory ProductPost.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // S'assurer que nous avons un companyId valide
    final String companyId = data['companyId'] ?? data['sellerId'] ?? '';
    if (companyId.isEmpty) {
      throw Exception('CompanyId is missing in the document');
    }

    return ProductPost(
      id: doc.id,
      companyId: companyId,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      productId: data['productId'] ?? '',
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      images: List<String>.from(data['images'] ?? []),
      sellerId: data['sellerId'] ?? companyId,
      hasActiveHappyDeal: data['hasActiveHappyDeal'] ?? false,
      discountedPrice: data['discountedPrice']?.toDouble(),
      discountPercentage: data['discountPercentage']?.toDouble(),
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
  }
}
