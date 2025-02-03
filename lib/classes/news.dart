import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:happy/classes/post.dart';

class News extends Post {
  final String title;
  final String searchText;
  final String content;
  final List<String> photos;
  final List<String> videos;

  News({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.content,
    required super.companyId,
    required this.photos,
    required this.videos,
    super.views,
    super.likes,
    super.likedBy,
    super.commentsCount,
    super.comments,
  }) : super(type: 'news');

  factory News.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return News(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'],
      photos: List<String>.from(data['photos'] ?? []),
      videos: List<String>.from(data['videos'] ?? []),
      companyId: data['companyId'] ?? FirebaseAuth.instance.currentUser?.uid,
      searchText: data['searchText'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  factory News.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return News(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'],
      photos: List<String>.from(data['photos'] ?? []),
      videos: List<String>.from(data['videos'] ?? []),
      companyId: data['companyId'] ?? FirebaseAuth.instance.currentUser?.uid,
      searchText: data['searchText'] ?? "",
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
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
      'searchText': searchText,
      'content': content,
      'photos': photos,
      'videos': videos,
      'timestamp': timestamp,
      'companyId': companyId,
    });
    return map;
  }

  Map<String, dynamic> toEditableMap() {
    return {
      'title': title,
      'searchText': searchText,
      'content': content,
      'photos': photos,
      'videos': videos,
      'timestamp': timestamp,
      'companyId': companyId,
    };
  }
}
