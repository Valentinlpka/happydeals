import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class HappyDeal extends Post {
  final String title;
  final String searchText;

  final String productName;
  final String description;
  final String productId; // Référence au produit existant
  final num discountPercentage; // Pourcentage de réduction
  final num newPrice; // Pourcentage de réduction
  final num oldPrice; // Pourcentage de réduction
  final DateTime startDate;
  final DateTime endDate;
  final String photo;

  HappyDeal(
      {required super.timestamp,
      required this.title,
      required this.searchText,
      required this.productName,
      required this.newPrice,
      required this.oldPrice,
      required this.description,
      required this.productId,
      required this.discountPercentage,
      required this.startDate,
      required this.endDate,
      required this.photo,
      super.views,
      super.likes,
      super.likedBy,
      super.commentsCount,
      super.comments,
      required super.companyId,
      required super.id})
      : super(type: 'happy_deal');

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
    });
    return map;
  }

  Map<String, dynamic> toEditableMap() {
    return {
      'title': title,
      'searchText': searchText,
      'description': description,
      'productId': productId,
      'newPrice': newPrice,
      'productName': productName,
      'oldPrice': oldPrice,
      'discountPercentage': discountPercentage,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'photo': photo,
    };
  }
}
