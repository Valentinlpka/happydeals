import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class ExpressDeal extends Post {
  final String basketType;
  final DateTime pickupTime;
  final String content;
  final String companyId;
  final int basketCount;

  ExpressDeal({
    required String id,
    required DateTime timestamp,
    required String authorId,
    required this.basketType,
    required this.pickupTime,
    required this.content,
    required this.companyId,
    required this.basketCount,
    int views = 0,
    int likes = 0,
    List<String> likedBy = const [],
    int commentsCount = 0,
    List<Comment> comments = const [],
  }) : super(
          id: id,
          timestamp: timestamp,
          type: 'express_deal',
          authorId: authorId,
          views: views,
          likes: likes,
          likedBy: likedBy,
          commentsCount: commentsCount,
          comments: comments,
        );

  factory ExpressDeal.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpressDeal(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      basketType: data['basketType'],
      pickupTime: (data['pickupTime'] as Timestamp).toDate(),
      content: data['content'],
      companyId: data['companyId'],
      basketCount: data['basketCount'],
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

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'basketType': basketType,
      'pickupTime': Timestamp.fromDate(pickupTime),
      'content': content,
      'companyId': companyId,
      'basketCount': basketCount,
    });
    return map;
  }
}
