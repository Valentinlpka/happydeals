import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';

class ProductPost extends Post {
  final String productId;
  final String name;
  final String description;
  final String categoryId;
  final double basePrice;
  final List<ProductVariant> variants;
  final String merchantId;

  ProductPost({
    required super.id,
    required super.companyId,
    required super.timestamp,
    required this.productId,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.basePrice,
    required this.variants,
    required this.merchantId,
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
      categoryId: product.categoryId,
      basePrice: product.basePrice,
      variants: product.variants,
      merchantId: product.merchantId,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'productId': productId,
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'basePrice': basePrice,
      'variants': variants.map((v) => v.toMap()).toList(),
      'merchantId': merchantId,
    });
    return map;
  }

  factory ProductPost.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductPost(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      productId: data['productId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      basePrice: (data['basePrice'] ?? 0.0).toDouble(),
      variants: (data['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      merchantId: data['merchantId'] ?? '',
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
