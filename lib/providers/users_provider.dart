import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/share_post.dart';
import 'package:rxdart/rxdart.dart';

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
  String _uniqueCode = '';
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
  double _totalSavings = 0.0;

  double get totalSavings => roundAmount(_totalSavings);
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

  String get uniqueCode => _uniqueCode;

  double roundAmount(double amount) {
    return (amount * 100).round() / 100;
  }

  set firstName(String value) {
    _firstName = value;
    notifyListeners();
  }

  set uniqueCode(String value) {
    _uniqueCode = value;
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

  // Méthode pour calculer et mettre à jour le total des économies
  Future<void> calculateAndUpdateTotalSavings() async {
    if (userId.isEmpty) return;

    try {
      double total = 0;

      // Calculer les économies des commandes
      final ordersQuery = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in ordersQuery.docs) {
        final data = doc.data();
        final happyDealSavings = (data['happyDealSavings'] ?? 0.0) as num;
        final discountAmount = (data['discountAmount'] ?? 0.0) as num;
        total += happyDealSavings + discountAmount;
      }

      // Calculer les économies des réservations
      final reservationsQuery = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in reservationsQuery.docs) {
        final data = doc.data();
        final originalPrice = (data['originalPrice'] ?? 0.0) * 2 as num;
        total += originalPrice; // 50% d'économie sur les Deal Express
      }
      // Mettre à jour dans Firestore et localement
      total = roundAmount(total);
      await _firestore.collection('users').doc(userId).update({
        'totalSavings': total,
      });

      _totalSavings = total;
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating total savings: $e');
    }
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
      _uniqueCode = data['uniqueCode'] ?? '';
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
      await calculateAndUpdateTotalSavings();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Stream<double> get totalSavingsStream {
    if (userId.isEmpty) return Stream.value(0);

    final ordersStream = _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .snapshots();

    final reservationsStream = _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .snapshots();

    return Rx.combineLatest2(
      ordersStream,
      reservationsStream,
      (QuerySnapshot orders, QuerySnapshot reservations) {
        double total = 0;

        // Calculer les économies des commandes
        for (var doc in orders.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final happyDealSavings = (data['happyDealSavings'] ?? 0.0) as num;
          final discountAmount = (data['discountAmount'] ?? 0.0) as num;
          total += happyDealSavings + discountAmount;
        }

        // Calculer les économies des réservations
        for (var doc in reservations.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final originalPrice = (data['originalPrice'] ?? 0.0) as num;
          total += originalPrice;
        }

        _totalSavings = roundAmount(total);
        notifyListeners();
        return total;
      },
    );
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

  Future<void> removeFollower(String followerId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final currentUserRef = _firestore.collection('users').doc(userId);
        final followerRef = _firestore.collection('users').doc(followerId);

        final currentUserDoc = await transaction.get(currentUserRef);
        final followerDoc = await transaction.get(followerRef);

        if (!currentUserDoc.exists || !followerDoc.exists) {
          throw Exception('One or both users do not exist');
        }

        List<String> currentUserFollowers =
            List<String>.from(currentUserDoc.data()?['followers'] ?? []);
        List<String> followerFollowing =
            List<String>.from(followerDoc.data()?['followedUsers'] ?? []);

        if (currentUserFollowers.contains(followerId)) {
          currentUserFollowers.remove(followerId);
          transaction
              .update(currentUserRef, {'followers': currentUserFollowers});
        }

        if (followerFollowing.contains(userId)) {
          followerFollowing.remove(userId);
          transaction.update(followerRef, {'followedUsers': followerFollowing});
        }
      });

      notifyListeners();
    } catch (e) {
      rethrow;
    }
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

  Future<void> sharePost(String postId, String userId,
      {String? comment}) async {
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
      comment: comment, // Ajout du commentaire
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

  Future<void> updateSharedPostComment(String postId, String newComment) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'comment': newComment,
      });
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSharedPost(String postId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Supprimer le post
        transaction.delete(_firestore.collection('posts').doc(postId));

        // Supprimer la référence du post dans le document de l'utilisateur
        transaction.update(_firestore.collection('users').doc(userId), {
          'sharedPosts': FieldValue.arrayRemove([postId])
        });
      });

      notifyListeners();
    } catch (e) {
      rethrow;
    }
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
