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
  final String? discountType;
  final Map<String, dynamic>? companyAddress;

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
    this.discountType,
    required super.companyName,
    required super.companyLogo,
    this.companyAddress,
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
    
    // Conversion sécurisée des timestamps
    DateTime? startDate;
    if (data['startDate'] != null) {
      if (data['startDate'] is Timestamp) {
        startDate = (data['startDate'] as Timestamp).toDate();
      } else if (data['startDate'] is String) {
        startDate = DateTime.tryParse(data['startDate']);
      }
    }
    
    DateTime? endDate;
    if (data['endDate'] != null) {
      if (data['endDate'] is Timestamp) {
        endDate = (data['endDate'] as Timestamp).toDate();
      } else if (data['endDate'] is String) {
        endDate = DateTime.tryParse(data['endDate']);
      }
    }

    // Conversion sécurisée de categoryPath
    List<String> categoryPath = [];
    if (data['categoryPath'] != null) {
      if (data['categoryPath'] is List) {
        categoryPath = List<String>.from(
          (data['categoryPath'] as List).map((item) => item.toString())
        );
      } else if (data['categoryPath'] is String) {
        categoryPath = [data['categoryPath'].toString()];
      }
    }

    // Conversion sécurisée des valeurs numériques
    num discountPercentage = 0;
    if (data['discountPercentage'] != null) {
      if (data['discountPercentage'] is num) {
        discountPercentage = data['discountPercentage'];
      } else if (data['discountPercentage'] is String) {
        discountPercentage = num.tryParse(data['discountPercentage']) ?? 0;
      }
    }

    return HappyDeal(
      id: doc.id,
      timestamp: data['timestamp'] is Timestamp 
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      title: data['title']?.toString() ?? '',
      searchText: data['searchText']?.toString() ?? '',
      productName: data['productName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      productId: data['productId']?.toString() ?? '',
      discountPercentage: discountPercentage,
      startDate: startDate ?? DateTime.now(),
      endDate: endDate ?? DateTime.now().add(const Duration(days: 7)),
      companyId: data['companyId']?.toString() ?? '',
      photo: data['photo']?.toString() ?? '',
      views: (data['views'] is num) ? (data['views'] as num).toInt() : 0,
      likes: (data['likes'] is num) ? (data['likes'] as num).toInt() : 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: (data['commentsCount'] is num) ? (data['commentsCount'] as num).toInt() : 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
      newPrice: (data['newPrice'] is num) ? data['newPrice'] : 0,
      oldPrice: (data['oldPrice'] is num) ? data['oldPrice'] : 0,
      categoryId: data['categoryId']?.toString() ?? '',
      categoryPath: categoryPath,
      isActive: data['isActive'] ?? true,
      discountType: data['discountType']?.toString(),
      companyName: data['companyName']?.toString() ?? '',
      companyLogo: data['companyLogo']?.toString() ?? '',
      companyAddress: data['companyAddress'] as Map<String, dynamic>?,
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
      companyName: product.companyName,
      companyLogo: product.companyLogo,
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
      'discountType': discountType,
      'companyName': companyName,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress,
    });
    return map;
  }
}
