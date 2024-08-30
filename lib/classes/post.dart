import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/share_post.dart';

class Post {
  final String companyId;
  final String id;
  final DateTime timestamp;
  final String type;
  int views;
  int likes;
  List<String> likedBy;
  int commentsCount;
  List<Comment> comments;
  final String? sharedBy; // ID de l'utilisateur qui a partagé le post
  final DateTime? sharedAt; // Date de partage
  final String? originalPostId; // ID du post original si c'est un partage

  Post({
    required this.id,
    required this.companyId,
    required this.timestamp,
    required this.type,
    this.views = 0,
    this.likes = 0,
    this.likedBy = const [],
    this.commentsCount = 0,
    this.comments = const [],
    this.sharedBy,
    this.sharedAt,
    this.originalPostId,
  });

  factory Post.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'unknown';
    final String? originalPostId = data['originalPostId'];

    if (originalPostId != null) {
      // C'est un post partagé, créons un "SharedPost"
      return SharedPost.fromDocument(doc);
    }

    switch (type) {
      case 'job_offer':
        return JobOffer.fromDocument(doc);
      case 'contest':
        return Contest.fromDocument(doc);
      case 'happy_deal':
        return HappyDeal.fromDocument(doc);
      case 'express_deal':
        return ExpressDeal.fromDocument(doc);
      case 'referral':
        return Referral.fromDocument(doc);
      case 'event':
        return Event.fromDocument(doc);
      default:
        throw Exception('Unsupported post type: $type');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId, // Ajoutez cette ligne

      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'views': views,
      'likes': likes,
      'likedBy': likedBy,
      'commentsCount': commentsCount,
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'sharedBy': sharedBy,
      'sharedAt': sharedAt != null ? Timestamp.fromDate(sharedAt!) : null,
      'originalPostId': originalPostId,
    };
  }
}

Future<void> sharePost(String postId, String userId) async {
  final postDoc =
      await FirebaseFirestore.instance.collection('posts').doc(postId).get();
  if (!postDoc.exists) {
    throw Exception('Post not found');
  }

  final originalPost = Post.fromDocument(postDoc);
  final sharedPost = Post(
    id: FirebaseFirestore.instance.collection('posts').doc().id,
    companyId: originalPost.companyId,
    timestamp: DateTime.now(),
    type: originalPost.type,
    sharedBy: userId,
    sharedAt: DateTime.now(),
    originalPostId: postId,
  );

  await FirebaseFirestore.instance
      .collection('posts')
      .doc(sharedPost.id)
      .set(sharedPost.toMap());

  // Mettre à jour le profil de l'utilisateur
  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'sharedPosts': FieldValue.arrayUnion([sharedPost.id])
  });
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
