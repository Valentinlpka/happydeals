import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:happy/classes/post.dart';

class News extends Post {
  final String title;
  final String searchText;
  final String content;
  final List<String> photos;
  final List<String> videos;
  final String? articleUrl;
  final ArticlePreview? articlePreview;

  News({
    required super.id,
    required super.timestamp,
    required this.title,
    required this.searchText,
    required this.content,
    required super.companyId,
    required this.photos,
    required this.videos,
    this.articleUrl,
    this.articlePreview,
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
      articleUrl: data['articleUrl'],
      articlePreview: data['articlePreview'] != null
          ? ArticlePreview.fromMap(data['articlePreview'])
          : null,
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
      articleUrl: data['articleUrl'],
      articlePreview: data['articlePreview'] != null
          ? ArticlePreview.fromMap(data['articlePreview'])
          : null,
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
      'articlePreview': articlePreview?.toMap(),
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
      'articlePreview': articlePreview?.toMap(),
      'content': content,
      'photos': photos,
      'videos': videos,
      'timestamp': timestamp,
      'companyId': companyId,
      'articleUrl': articleUrl,
    };
  }
}

class ArticlePreview {
  final String? title;
  final String? description;
  final String? image;
  final String? url;

  ArticlePreview({
    this.title,
    this.description,
    this.image,
    this.url,
  });

  factory ArticlePreview.fromMap(Map<String, dynamic> map) {
    return ArticlePreview(
      title: map['title'],
      description: map['description'],
      image: map['image'],
      url: map['url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'image': image,
      'url': url,
    };
  }
}
