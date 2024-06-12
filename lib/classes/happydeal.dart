import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class HappyDeal extends Post {
  final String title;
  final String description;
  final List<String> deals;
  final DateTime startDate;
  final DateTime endDate;
  final String companyId;
  final String photo;

  HappyDeal({
    required String id,
    required DateTime timestamp,
    required String authorId,
    required this.title,
    required this.description,
    required this.deals,
    required this.startDate,
    required this.endDate,
    required this.companyId,
    required this.photo,
    int views = 0,
    int likes = 0,
    List<String> likedBy = const [],
    int commentsCount = 0,
    List<Comment> comments = const [],
  }) : super(
          id: id,
          timestamp: timestamp,
          type: 'happy_deal',
          authorId: authorId,
          views: views,
          likes: likes,
          likedBy: likedBy,
          commentsCount: commentsCount,
          comments: comments,
        );

  factory HappyDeal.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HappyDeal(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      title: data['title'],
      description: data['description'],
      deals: List<String>.from(data['deals']),
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
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'title': title,
      'description': description,
      'deals': deals,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'companyId': companyId,
      'photo': photo,
    });
    return map;
  }
}
