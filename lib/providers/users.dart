import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';

class UserModel with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String userId = "";
  String _firstName = '';
  String _lastName = '';
  String _dailyQuote = '';
  String _profileUrl = '';
  final List<String> likedPosts = [];
  final List<String> likedCompanies = [];
  final List<String> followedUsers = [];

  String get firstName => _firstName;
  String get lastName => _lastName;
  String get dailyQuote => _dailyQuote;
  String get profileUrl => _profileUrl;

  set firstName(String value) {
    _firstName = value;
    notifyListeners();
  }

  set lastName(String value) {
    _lastName = value;
    notifyListeners();
  }

  set profileUrl(String value) {
    _profileUrl = value;
    notifyListeners();
  }

  Future<void> updateUserProfile(Map<String, dynamic> userData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).update(userData);
    await loadUserData();
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<bool> isProfileComplete() async {
    final userData = await getCurrentUser();
    return userData?['isProfileComplete'] ?? false;
  }

  Future<void> loadUserData() async {
    userId = _auth.currentUser?.uid ?? "";
    if (userId.isEmpty) return;

    try {
      final userSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (!userSnapshot.exists) return;

      final data = userSnapshot.data() as Map<String, dynamic>;

      _firstName = data['firstName'] ?? '';
      _lastName = data['lastName'] ?? '';
      _profileUrl = data['image_profile'] ?? '';

      followedUsers.clear();
      followedUsers.addAll(List<String>.from(data['followedUsers'] ?? []));

      likedPosts.clear();
      likedPosts.addAll(List<String>.from(data['likedPosts'] ?? []));

      likedCompanies.clear();
      likedCompanies.addAll(List<String>.from(data['likedCompanies'] ?? []));

      await loadDailyQuote();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> followUser(String userIdToFollow) async {
    if (followedUsers.contains(userIdToFollow)) return;

    followedUsers.add(userIdToFollow);
    notifyListeners();

    try {
      await _firestore.collection('users').doc(userId).update({
        'followedUsers': FieldValue.arrayUnion([userIdToFollow])
      });
    } catch (e) {
      followedUsers.remove(userIdToFollow);
      notifyListeners();
      debugPrint('Error following user: $e');
    }
  }

  Future<void> unfollowUser(String userIdToUnfollow) async {
    if (!followedUsers.contains(userIdToUnfollow)) return;

    followedUsers.remove(userIdToUnfollow);
    notifyListeners();

    try {
      await _firestore.collection('users').doc(userId).update({
        'followedUsers': FieldValue.arrayRemove([userIdToUnfollow])
      });
    } catch (e) {
      followedUsers.add(userIdToUnfollow);
      notifyListeners();
      debugPrint('Error unfollowing user: $e');
    }
  }

  void clearUserData() {
    userId = "";
    _firstName = '';
    _lastName = '';
    _dailyQuote = '';
    _profileUrl = '';
    likedPosts.clear();
    likedCompanies.clear();
    followedUsers.clear();
    notifyListeners();
  }

  Future<void> loadDailyQuote() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final quoteSnapshot = await _firestore
          .collection('daily_quotes')
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (quoteSnapshot.docs.isNotEmpty) {
        _dailyQuote = quoteSnapshot.docs.first['quote'];
      } else {
        final randomQuoteSnapshot =
            await _firestore.collection('daily_quotes').limit(1).get();
        _dailyQuote = randomQuoteSnapshot.docs.isNotEmpty
            ? randomQuoteSnapshot.docs.first['quote']
            : "Aucune citation disponible pour aujourd'hui.";
      }
    } catch (e) {
      _dailyQuote = "Impossible de charger la citation du jour.";
    }
    notifyListeners();
  }

  Future<void> handleCompanyFollow(String companyId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final isCurrentlyLiked = likedCompanies.contains(companyId);

    likedCompanies.toggle(companyId);
    notifyListeners();

    try {
      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists)
          throw Exception("User document does not exist!");

        transaction.update(userRef, {
          'likedCompanies': isCurrentlyLiked
              ? FieldValue.arrayRemove([companyId])
              : FieldValue.arrayUnion([companyId])
        });
      });
    } catch (e) {
      likedCompanies.toggle(companyId);
      notifyListeners();
      debugPrint('Error handling company follow: $e');
    }
  }

  Future<void> handleLike(Post post) async {
    final postRef = _firestore.collection('posts').doc(post.id);
    final userRef = _firestore.collection('users').doc(userId);
    final isCurrentlyLiked = likedPosts.contains(post.id);

    likedPosts.toggle(post.id);
    post.likes += isCurrentlyLiked ? -1 : 1;
    notifyListeners();

    try {
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        final userSnapshot = await transaction.get(userRef);

        if (!postSnapshot.exists || !userSnapshot.exists) {
          throw Exception("Document does not exist!");
        }

        final likedBy = List<String>.from(postSnapshot['likedBy']);
        final likes = postSnapshot['likes'] as int;

        if (isCurrentlyLiked) {
          likedBy.remove(userId);
          transaction.update(postRef, {'likedBy': likedBy, 'likes': likes - 1});
          transaction.update(userRef, {
            'likedPosts': FieldValue.arrayRemove([post.id])
          });
        } else {
          likedBy.add(userId);
          transaction.update(postRef, {'likedBy': likedBy, 'likes': likes + 1});
          transaction.update(userRef, {
            'likedPosts': FieldValue.arrayUnion([post.id])
          });
        }
      });
    } catch (e) {
      likedPosts.toggle(post.id);
      post.likes += isCurrentlyLiked ? 1 : -1;
      notifyListeners();
      debugPrint('Error handling like: $e');
    }
  }

  Future<void> sharePost(String postId, String userId) async {
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) throw Exception('Post not found');

    final originalPost = Post.fromDocument(postDoc);
    final sharedPost = SharedPost(
      id: _firestore.collection('posts').doc().id,
      companyId: originalPost.companyId,
      timestamp: DateTime.now(),
      sharedBy: userId,
      sharedAt: DateTime.now(),
      originalPostId: postId,
    );

    await _firestore
        .collection('posts')
        .doc(sharedPost.id)
        .set(sharedPost.toMap());
    await _firestore.collection('users').doc(userId).update({
      'sharedPosts': FieldValue.arrayUnion([sharedPost.id])
    });

    notifyListeners();
  }
}

extension on List<String> {
  void toggle(String value) {
    if (contains(value)) {
      remove(value);
    } else {
      add(value);
    }
  }
}
