import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/news.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/classes/promo_code_post.dart';
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
  final String? comment;
  List<String> viewedBy = [];

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
    this.comment,
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
      case 'product':
        return ProductPost.fromDocument(doc);
      case 'news':
        return News.fromDocument(doc);
      case 'promo_code':
        return PromoCodePost.fromDocument(doc);

      default:
        throw Exception('Unsupported post type: $type');
    }
  }

  static Post fromMap(Map<String, dynamic> map, String id) {
    return Post(
      id: id,
      companyId: map['companyId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      type: map['type'] ?? 'unknown',
      views: map['views'] ?? 0,
      likes: map['likes'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      commentsCount: map['commentsCount'] ?? 0,
      sharedBy: map['sharedBy'],
      sharedAt: map['sharedAt'] != null
          ? (map['sharedAt'] as Timestamp).toDate()
          : null,
      originalPostId: map['originalPostId'],
      comment: map['comment'],
    )..viewedBy = List<String>.from(map['viewedBy'] ?? []);
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
      'comment': comment,
      'viewedBy': viewedBy,
    };
  }

  Future<void> incrementViews() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final postRef = FirebaseFirestore.instance.collection('posts').doc(id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) return;

        final viewedBy = List<String>.from(postDoc.data()?['viewedBy'] ?? []);

        if (!viewedBy.contains(currentUser.uid)) {
          transaction.update(postRef, {
            'views': FieldValue.increment(1),
            'viewedBy': FieldValue.arrayUnion([currentUser.uid]),
          });

          // Mise à jour locale
          views++;
          this.viewedBy.add(currentUser.uid);
        }
      });
    } catch (e) {
      print('Erreur lors de l\'incrémentation des vues: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(String userId) async {
    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(id);

      if (likedBy.contains(userId)) {
        await postRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        likes--;
        likedBy.remove(userId);
      } else {
        await postRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        likes++;
        likedBy.add(userId);
      }
    } catch (e) {
      print('Erreur lors de la gestion du like: $e');
      rethrow;
    }
  }

  Future<void> incrementCommentsCount() async {
    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(id);
      await postRef.update({
        'commentsCount': FieldValue.increment(1),
      });
      commentsCount++;
    } catch (e) {
      print('Erreur lors de l\'incrémentation des commentaires: $e');
      rethrow;
    }
  }

  Future<void> decrementCommentsCount() async {
    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(id);
      await postRef.update({
        'commentsCount': FieldValue.increment(-1),
      });
      commentsCount--;
    } catch (e) {
      print('Erreur lors de la décrémentation des commentaires: $e');
      rethrow;
    }
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
