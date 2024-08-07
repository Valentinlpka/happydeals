import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String companyId;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final String userName;
  final String userPhotoUrl;

  Review({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.userName,
    required this.userPhotoUrl,
  });

  factory Review.fromMap(Map<String, dynamic> data, String id) {
    return Review(
      id: id,
      userId: data['userId'],
      companyId: data['companyId'],
      rating: data['rating'].toDouble(),
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userName: data['userName'],
      userPhotoUrl: data['userPhotoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'companyId': companyId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
    };
  }
}
