import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class Referral extends Post {
  final String title;
  final String description;
  final String sponsorBenefit;
  final String refereeBenefit;
  final String companyId;
  final String image;

  Referral({
    required String id,
    required DateTime timestamp,
    required String authorId,
    required this.title,
    required this.description,
    required this.sponsorBenefit,
    required this.refereeBenefit,
    required this.companyId,
    required this.image,
    int views = 0,
    int likesCount = 0,
    List<String> likedBy = const [],
    int commentsCount = 0,
    List<Comment> comments = const [],
  }) : super(
          id: id,
          timestamp: timestamp,
          type: 'referral',
          authorId: authorId,
          views: views,
          likes: likesCount,
          likedBy: likedBy,
          commentsCount: commentsCount,
          comments: comments,
        );

  factory Referral.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Referral(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      title: data['title'],
      description: data['description'],
      sponsorBenefit: data['sponsorBenefit'],
      refereeBenefit: data['refereeBenefit'],
      companyId: data['companyId'],
      image: data['image'],
      views: data['views'] ?? 0,
      likesCount: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      commentsCount: data['commentsCount'] ?? 0,
      comments: (data['comments'] as List<dynamic>?)
              ?.map((commentData) => Comment.fromMap(commentData))
              .toList() ??
          [],
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'description': description,
      'sponsorBenefit': sponsorBenefit,
      'refereeBenefit': refereeBenefit,
      'companyId': companyId,
      'image': image,
    });
    return map;
  }
}
