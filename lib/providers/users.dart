import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';

class UserModel with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String userId = "";
  String _firstName = '';
  String _lastName = '';
  String _dailyQuote = '';
  String _profileUrl = '';
  final List<String> likedPosts = [];

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

        likedPosts.clear();
        if (data['likedPosts'] != null) {
          likedPosts.addAll(List<String>.from(data['likedPosts']));
        }

        await loadDailyQuote();

        notifyListeners();
      }
    } catch (e) {}
  }

  void clearUserData() {
    userId = "";
    _firstName = '';
    _lastName = '';
    _dailyQuote = '';
    _profileUrl = '';
    likedPosts.clear();
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
}
