import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/post.dart';

class JobOffer extends Post {
  final String jobTitle;
  final String city;
  final String description;
  final String missions;
  final String profile;
  final String benefits;
  final String whyJoin;
  final List<String> keywords;
  final String companyId;

  JobOffer({
    required String id,
    required DateTime timestamp,
    required String authorId,
    required this.jobTitle,
    required this.city,
    required this.description,
    required this.missions,
    required this.profile,
    required this.benefits,
    required this.whyJoin,
    required this.keywords,
    required this.companyId,
    int views = 0,
    int likes = 0,
    List<String> likedBy = const [],
    int commentsCount = 0,
    List<Comment> comments = const [],
  }) : super(
          id: id,
          timestamp: timestamp,
          type: 'job_offer',
          authorId: authorId,
          views: views,
          likes: likes,
          likedBy: likedBy,
          commentsCount: commentsCount,
          comments: comments,
        );

  factory JobOffer.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobOffer(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      authorId: data['authorId'],
      jobTitle: data['job_title'],
      city: data['city'],
      description: data['description'],
      missions: data['missions'],
      profile: data['profile'],
      benefits: data['benefits'],
      whyJoin: data['why_join'],
      keywords: List<String>.from(data['keywords']),
      companyId: data['companyId'],
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
      'job_title': jobTitle,
      'city': city,
      'description': description,
      'missions': missions,
      'profile': profile,
      'benefits': benefits,
      'why_join': whyJoin,
      'keywords': keywords,
      'companyId': companyId,
    });
    return map;
  }
}
