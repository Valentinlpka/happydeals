import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
    String uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update(userData);
    await loadUserData(); // Reload user data after update
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    String uid = _auth.currentUser!.uid;
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  Future<bool> isProfileComplete() async {
    Map<String, dynamic>? userData = await getCurrentUser();
    return userData?['isProfileComplete'] ?? false;
  }

  Future<void> loadUserData() async {
    if (_auth.currentUser != null) {
      userId = _auth.currentUser!.uid;
    }

    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (userSnapshot.exists) {
        final data = userSnapshot.data() as Map<String, dynamic>;

        _firstName = data['firstName'] ?? '';
        _lastName = data['lastName'] ?? '';
        _profileUrl = data['image_profile'] ?? '';
        followedUsers.clear();
        if (data['followedUsers'] != null) {
          followedUsers.addAll(List<String>.from(data['followedUsers']));
        }
        likedPosts.clear();
        if (data['likedPosts'] != null) {
          likedPosts.addAll(List<String>.from(data['likedPosts']));
        }

        likedCompanies.clear();
        if (data['likedCompanies'] != null) {
          likedCompanies.addAll(List<String>.from(data['likedCompanies']));
        }

        await loadDailyQuote();

        notifyListeners();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> followUser(String userIdToFollow) async {
    if (!followedUsers.contains(userIdToFollow)) {
      followedUsers.add(userIdToFollow);
      notifyListeners();

      try {
        await _firestore.collection('users').doc(userId).update({
          'followedUsers': FieldValue.arrayUnion([userIdToFollow])
        });
      } catch (e) {
        // Revert optimistic update if Firestore update fails
        followedUsers.remove(userIdToFollow);
        notifyListeners();
        print('Error following user: $e');
      }
    }
  }

  Future<void> unfollowUser(String userIdToUnfollow) async {
    if (followedUsers.contains(userIdToUnfollow)) {
      followedUsers.remove(userIdToUnfollow);
      notifyListeners();

      try {
        await _firestore.collection('users').doc(userId).update({
          'followedUsers': FieldValue.arrayRemove([userIdToUnfollow])
        });
      } catch (e) {
        // Revert optimistic update if Firestore update fails
        followedUsers.add(userIdToUnfollow);
        notifyListeners();
        print('Error unfollowing user: $e');
      }
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
      QuerySnapshot quoteSnapshot = await _firestore
          .collection('daily_quotes')
          .where('date',
              isEqualTo: DateTime.now().toIso8601String().split('T')[0])
          .limit(1)
          .get();

      if (quoteSnapshot.docs.isNotEmpty) {
        _dailyQuote = quoteSnapshot.docs.first['quote'];
      } else {
        QuerySnapshot randomQuoteSnapshot =
            await _firestore.collection('daily_quotes').limit(1).get();

        if (randomQuoteSnapshot.docs.isNotEmpty) {
          _dailyQuote = randomQuoteSnapshot.docs.first['quote'];
        } else {
          _dailyQuote = "Aucune citation disponible pour aujourd'hui.";
        }
      }
      notifyListeners();
    } catch (e) {
      _dailyQuote = "Impossible de charger la citation du jour.";
      notifyListeners();
    }
  }

  Future<void> handleCompanyFollow(String companyId) async {
    final userRef = _firestore.collection('users').doc(userId);

    // Mise à jour optimiste de l'état local
    if (likedCompanies.contains(companyId)) {
      likedCompanies.remove(companyId);
    } else {
      likedCompanies.add(companyId);
    }
    notifyListeners();

    // Mise à jour Firestore en arrière-plan
    try {
      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
          throw Exception("User document does not exist!");
        }

        if (likedCompanies.contains(companyId)) {
          transaction.update(userRef, {
            'likedCompanies': FieldValue.arrayUnion([companyId])
          });
        } else {
          transaction.update(userRef, {
            'likedCompanies': FieldValue.arrayRemove([companyId])
          });
        }
      });
    } catch (e) {
      // Annuler la mise à jour optimiste si la transaction Firestore échoue
      if (likedCompanies.contains(companyId)) {
        likedCompanies.remove(companyId);
      } else {
        likedCompanies.add(companyId);
      }
      notifyListeners();
      print('Error handling company follow: $e');
    }
  }

  Future<void> handleLike(Post post) async {
    final postRef = _firestore.collection('posts').doc(post.id);
    final userRef = _firestore.collection('users').doc(userId);

    // Optimistically update the local state
    if (likedPosts.contains(post.id)) {
      likedPosts.remove(post.id);
      post.likes -= 1;
    } else {
      likedPosts.add(post.id);
      post.likes += 1;
    }
    notifyListeners();

    // Firestore update in the background
    try {
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        final userSnapshot = await transaction.get(userRef);

        if (!postSnapshot.exists || !userSnapshot.exists) {
          throw Exception("Document does not exist!");
        }

        final List<String> likedBy = List<String>.from(postSnapshot['likedBy']);
        final int likes = postSnapshot['likes'];

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likes': likes - 1,
          });
          transaction.update(userRef, {
            'likedPosts': FieldValue.arrayRemove([post.id])
          });
        } else {
          likedBy.add(userId);
          transaction.update(postRef, {
            'likedBy': likedBy,
            'likes': likes + 1,
          });
          transaction.update(userRef, {
            'likedPosts': FieldValue.arrayUnion([post.id])
          });
        }
      });
    } catch (e) {
      // Revert the optimistic update if the Firestore transaction fails
      if (likedPosts.contains(post.id)) {
        likedPosts.remove(post.id);
        post.likes -= 1;
      } else {
        likedPosts.add(post.id);
        post.likes += 1;
      }
      notifyListeners();
    }
  }

  Future<void> sharePost(String postId, String userId) async {
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Post not found');
    }

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

    // Mettre à jour le profil de l'utilisateur
    await _firestore.collection('users').doc(userId).update({
      'sharedPosts': FieldValue.arrayUnion([sharedPost.id])
    });

    notifyListeners();
  }
}
