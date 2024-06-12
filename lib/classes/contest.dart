import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class Contest extends Post {
  final String title;
  final String description;
  final List<String> gifts;
  final String companyId;
  final String howToParticipate;
  final String conditions;
  final DateTime startDate;
  final DateTime endDate;
  final String giftPhoto;

  Contest({
    required String id,
    required DateTime timestamp,
    required String authorId,
    required this.title,
    required this.description,
    required this.gifts,
    required this.companyId,
    required this.howToParticipate,
    required this.conditions,
    required this.startDate,
    required this.endDate,
    required this.giftPhoto,
    int views = 0,
    int likes = 0,
    List<String> likedBy = const [],
    int commentsCount = 0,
    List<Comment> comments = const [],
  }) : super(
          id: id,
          timestamp: timestamp,
          type: 'contest',
          authorId: authorId,
          views: views,
          likes: likes,
          likedBy: likedBy,
          commentsCount: commentsCount,
          comments: comments,
        );

  factory Contest.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Contest(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      title: data['title'],
      description: data['description'],
      gifts: List<String>.from(data['gifts']),
      companyId: data['companyId'],
      howToParticipate: data['howToParticipate'],
      conditions: data['conditions'],
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      giftPhoto: data['giftPhoto'],
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
      'gifts': gifts,
      'companyId': companyId,
      'howToParticipate': howToParticipate,
      'conditions': conditions,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'giftPhoto': giftPhoto,
    });
    return map;
  }
}
