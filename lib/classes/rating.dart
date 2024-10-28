import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String adId;
  final String adTitle;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String conversationId;
  final bool isSellerRating; // true si le vendeur note l'acheteur

  Rating({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.adId,
    required this.adTitle,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.conversationId,
    required this.isSellerRating,
  });

  factory Rating.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Rating(
      id: doc.id,
      fromUserId: data['fromUserId'] ?? '',
      toUserId: data['toUserId'] ?? '',
      adId: data['adId'] ?? '',
      adTitle: data['adTitle'] ?? '',
      rating: (data['rating'] as num).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      conversationId: data['conversationId'] ?? '',
      isSellerRating: data['isSellerRating'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'adId': adId,
      'adTitle': adTitle,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'conversationId': conversationId,
      'isSellerRating': isSellerRating,
    };
  }
}
