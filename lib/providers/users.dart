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
  String _email = '';
  String _phone = '';
  bool _showEmail = false;
  bool _showPhone = false;
  String _desiredPosition = '';
  String _cvUrl = '';
  String _description = '';
  String _availability = '';
  List<String> _contractTypes = [];
  String _workingHours = '';
  String _industrySector = '';
  List<String> likedPosts = [];
  List<String> likedCompanies = [];
  List<String> followedUsers = [];

  String get firstName => _firstName;
  String get industrySector => _industrySector;
  String get lastName => _lastName;
  String get dailyQuote => _dailyQuote;
  String get profileUrl => _profileUrl;
  String get email => _email;
  String get phone => _phone;
  bool get showEmail => _showEmail;
  bool get showPhone => _showPhone;
  String get desiredPosition => _desiredPosition;
  String get cvUrl => _cvUrl;
  String get description => _description;
  String get availability => _availability;
  List<String> get contractTypes => _contractTypes;
  String get workingHours => _workingHours;

  set firstName(String value) {
    _firstName = value;
    notifyListeners();
  }

  set industrySector(String value) {
    _industrySector = value;
    notifyListeners();
  }

  set lastName(String value) {
    _lastName = value;
    notifyListeners();
  }

  set workingHours(String value) {
    _workingHours = value;
    notifyListeners();
  }

  set profileUrl(String value) {
    _profileUrl = value;
    notifyListeners();
  }

  set email(String value) {
    _email = value;
    notifyListeners();
  }

  set phone(String value) {
    _phone = value;
    notifyListeners();
  }

  set desiredPosition(String value) {
    _desiredPosition = value;
    notifyListeners();
  }

  set cvUrl(String value) {
    _cvUrl = value;
    notifyListeners();
  }

  set description(String value) {
    _description = value;
    notifyListeners();
  }

  set availability(String value) {
    _availability = value;
    notifyListeners();
  }

  set showEmail(bool value) {
    _showEmail = value;
    notifyListeners();
  }

  set showPhone(bool value) {
    _showPhone = value;
    notifyListeners();
  }

  // Ajoutez d'autres setters si nécessaire

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
      _email = data['email'] ?? '';
      _phone = data['phone'] ?? '';
      _showEmail = data['showEmail'] ?? false;
      _showPhone = data['showPhone'] ?? false;
      _desiredPosition = data['desiredPosition'] ?? '';
      _cvUrl = data['cvUrl'] ?? '';
      _description = data['description'] ?? '';
      _availability = data['availability'] ?? '';
      _contractTypes = List<String>.from(data['contractTypes'] ?? []);
      _workingHours = data['workingHours'] ?? '';
      _industrySector = data['industrySector'] ?? '';

      followedUsers = List<String>.from(data['followedUsers'] ?? []);
      likedPosts = List<String>.from(data['likedPosts'] ?? []);
      likedCompanies = List<String>.from(data['likedCompanies'] ?? []);

      await loadDailyQuote();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _updateUserField(String field, dynamic value,
      {bool isArray = false, bool add = true}) async {
    try {
      if (isArray) {
        await _firestore.collection('users').doc(userId).update({
          field: add
              ? FieldValue.arrayUnion([value])
              : FieldValue.arrayRemove([value])
        });
      } else {
        await _firestore.collection('users').doc(userId).update({field: value});
      }
    } catch (e) {
      debugPrint('Error updating $field: $e');
      rethrow;
    }
  }

  Future<void> followUser(String userIdToFollow) async {
    if (followedUsers.contains(userIdToFollow)) return;

    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('users').doc(userId);
      final followedUserRef =
          _firestore.collection('users').doc(userIdToFollow);

      final currentUserDoc = await transaction.get(currentUserRef);
      final followedUserDoc = await transaction.get(followedUserRef);

      if (!currentUserDoc.exists || !followedUserDoc.exists) {
        throw Exception('One or both users do not exist');
      }

      List<String> currentUserFollowing =
          List<String>.from(currentUserDoc.data()?['followedUsers'] ?? []);
      List<String> followedUserFollowers =
          List<String>.from(followedUserDoc.data()?['followers'] ?? []);

      if (!currentUserFollowing.contains(userIdToFollow)) {
        currentUserFollowing.add(userIdToFollow);
        transaction
            .update(currentUserRef, {'followedUsers': currentUserFollowing});
      }

      if (!followedUserFollowers.contains(userId)) {
        followedUserFollowers.add(userId);
        transaction
            .update(followedUserRef, {'followers': followedUserFollowers});
      }
    });

    followedUsers.add(userIdToFollow);
    notifyListeners();
  }

  Future<void> unfollowUser(String userIdToUnfollow) async {
    if (!followedUsers.contains(userIdToUnfollow)) return;

    await _firestore.runTransaction((transaction) async {
      final currentUserRef = _firestore.collection('users').doc(userId);
      final unfollowedUserRef =
          _firestore.collection('users').doc(userIdToUnfollow);

      final currentUserDoc = await transaction.get(currentUserRef);
      final unfollowedUserDoc = await transaction.get(unfollowedUserRef);

      if (!currentUserDoc.exists || !unfollowedUserDoc.exists) {
        throw Exception('One or both users do not exist');
      }

      List<String> currentUserFollowing =
          List<String>.from(currentUserDoc.data()?['followedUsers'] ?? []);
      List<String> unfollowedUserFollowers =
          List<String>.from(unfollowedUserDoc.data()?['followers'] ?? []);

      if (currentUserFollowing.contains(userIdToUnfollow)) {
        currentUserFollowing.remove(userIdToUnfollow);
        transaction
            .update(currentUserRef, {'followedUsers': currentUserFollowing});
      }

      if (unfollowedUserFollowers.contains(userId)) {
        unfollowedUserFollowers.remove(userId);
        transaction
            .update(unfollowedUserRef, {'followers': unfollowedUserFollowers});
      }
    });

    followedUsers.remove(userIdToUnfollow);
    notifyListeners();
  }

  void clearUserData() {
    userId = "";
    _firstName = '';
    _lastName = '';
    _dailyQuote = '';
    _profileUrl = '';
    _email = '';
    _phone = '';
    _showEmail = false;
    _showPhone = false;
    _desiredPosition = '';
    _cvUrl = '';
    _description = '';
    _availability = '';
    _contractTypes = [];
    _workingHours = '';
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

      _dailyQuote = quoteSnapshot.docs.isNotEmpty
          ? quoteSnapshot.docs.first['quote']
          : (await _firestore.collection('daily_quotes').limit(1).get())
                  .docs
                  .isNotEmpty
              ? (await _firestore.collection('daily_quotes').limit(1).get())
                  .docs
                  .first['quote']
              : "Aucune citation disponible pour aujourd'hui.";
    } catch (e) {
      _dailyQuote = "Impossible de charger la citation du jour.";
    }
    notifyListeners();
  }

  Future<void> handleCompanyFollow(String companyId) async {
    final isCurrentlyLiked = likedCompanies.contains(companyId);
    await _updateUserField('likedCompanies', companyId,
        isArray: true, add: !isCurrentlyLiked);
    likedCompanies.toggle(companyId);
    notifyListeners();
  }

  Future<void> handleLike(Post post) async {
    final isCurrentlyLiked = likedPosts.contains(post.id);
    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('posts').doc(post.id);
      final userRef = _firestore.collection('users').doc(userId);

      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) throw Exception("Post does not exist!");

      final likedBy = List<String>.from(postDoc['likedBy'] ?? []);
      final likes = postDoc['likes'] as int? ?? 0;

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

    likedPosts.toggle(post.id);
    post.likes += isCurrentlyLiked ? -1 : 1;
    notifyListeners();
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

extension ListExtension<T> on List<T> {
  void toggle(T value) {
    if (contains(value)) {
      remove(value);
    } else {
      add(value);
    }
  }
}
