import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final DateTime timestamp;
  final String type;
  final String authorId;
  int views;
  int likes;
  List<String> likedBy;
  int commentsCount;
  List<Comment> comments;

  Post({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.authorId,
    this.views = 0,
    this.likes = 0,
    this.likedBy = const [],
    this.commentsCount = 0,
    this.comments = const [],
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Post(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'],
      authorId: data['authorId'],
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

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'authorId': authorId,
      'views': views,
      'likes': likes,
      'likedBy': likedBy,
      'commentsCount': commentsCount,
      'comments': comments.map((comment) => comment.toMap()).toList(),
    };
  }
}

class Comment {
  final String userId;
  final String content;
  final String username;
  final String imageProfile;
  final Timestamp timestamp;

  Comment({
    required this.userId,
    required this.content,
    required this.username,
    required this.imageProfile,
    required this.timestamp,
  });

  factory Comment.fromMap(Map<String, dynamic> data) {
    return Comment(
      timestamp: data['timestamp'] ?? Timestamp.now(),
      userId: data['userId'] ?? 'unknown',
      content: data['content'] ?? '',
      username: data['username'] ?? 'Anonymous',
      imageProfile: data['image_profile'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'username': username,
      'image_profile': imageProfile,
      'timestamp': timestamp,
    };
  }
}
