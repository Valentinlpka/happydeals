import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';

class HappyDeal extends Post {
  final String title;
  final String searchText;
  final String productName;
  final String description;
  final String productId;
  final num discountPercentage;
  final num newPrice;
  final num oldPrice;
  final DateTime startDate;
  final DateTime endDate;
  final String photo;
  final List<String> categoryPath;
  final String categoryId;
  final bool isActive;

  HappyDeal({
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.productName,
    required this.description,
    required this.productId,
    required this.discountPercentage,
    required this.startDate,
    required this.endDate,
    required this.photo,
    required this.categoryPath,
    required this.categoryId,
    required this.isActive,
    required this.newPrice,
    required this.oldPrice,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
    required super.companyId,
    required super.id,
  }) : super(type: 'happy_deal');

  factory HappyDeal.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HappyDeal(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      title: data['title'],
      searchText: data['searchText'],
      productName: data['productName'],
      description: data['description'],
      productId: data['productId'],
      discountPercentage: data['discountPercentage'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      companyId: data['companyId'],
      photo: data['photo'],
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
      newPrice: data['newPrice'],
      oldPrice: data['oldPrice'],
      categoryId: data['categoryId'] ?? '',
      categoryPath: List<String>.from(data['categoryPath'] ?? []),
      isActive: data['isActive'] ?? true,
    );
  }

  factory HappyDeal.fromProduct(
    Product product, {
    required String title,
    required String description,
    required num discountPercentage,
    required DateTime startDate,
    required DateTime endDate,
    required String photo,
  }) {
    final newPrice = product.basePrice * (1 - (discountPercentage / 100));

    return HappyDeal(
      id: '', // À générer
      timestamp: DateTime.now(),
      title: title,
      searchText:
          '${title.toLowerCase()} ${product.name.toLowerCase()} $description'
              .toLowerCase(),
      productName: product.name,
      description: description,
      productId: product.id,
      discountPercentage: discountPercentage,
      startDate: startDate,
      endDate: endDate,
      photo: photo,
      categoryPath: product.categoryPath,
      categoryId: product.categoryId,
      isActive: product.isActive,
      newPrice: newPrice,
      oldPrice: product.basePrice,
      companyId: product.merchantId,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'searchText': searchText,
      'description': description,
      'productId': productId,
      'productName': productName,
      'discountPercentage': discountPercentage,
      'newPrice': newPrice,
      'oldPrice': oldPrice,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'companyId': companyId,
      'photo': photo,
      'categoryId': categoryId,
      'categoryPath': categoryPath,
      'isActive': isActive,
    });
    return map;
  }
}
