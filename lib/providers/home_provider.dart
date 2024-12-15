// ignore_for_file: empty_catches

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/news.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/share_post.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  Future<List<CombinedItem>> loadUnifiedFeed(
      List<String> likedCompanies, List<String> followedUsers,
      {bool refresh = false}) async {
    if (refresh) {
      _lastDocument = null;
      _hasMoreData = true;
    }

    try {
      if (kDebugMode) {
        print("### Début de loadUnifiedFeed ###");
        print("Nombre d'entreprises likées : ${likedCompanies.length}");
        print("Nombre d'utilisateurs suivis : ${followedUsers.length}");
      }

      final Set<String> addedPostIds = {};
      final List<CombinedItem> combinedItems = [];

      // Chargement paginé des posts
      await Future.wait([
        _loadLikedCompanyPostsPaginated(
            likedCompanies, addedPostIds, combinedItems),
        _loadSharedPostsPaginated(followedUsers, addedPostIds, combinedItems),
      ]);

      combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return combinedItems;
    } catch (e) {
      return [];
    }
  }

  Future<List<CombinedItem>> loadMoreUnifiedFeed(List<String> likedCompanies,
      List<String> followedUsers, CombinedItem? lastItem,
      {int limit = 10}) async {
    if (!_hasMoreData) return [];

    try {
      if (lastItem?.type == 'post') {
        final lastPostData = lastItem?.item as Map<String, dynamic>;
        final lastPost = lastPostData['post'] as Post;
        final lastTimestamp = lastPost.timestamp;

        final List<CombinedItem> allNewItems = [];
        final Set<String> addedPostIds = {};

        // Obtenir les posts des entreprises
        if (likedCompanies.isNotEmpty) {
          var companyQuery = _firestore
              .collection('posts')
              .where('companyId', whereIn: likedCompanies)
              .where('type', isNotEqualTo: 'shared')
              .where('isActive', isEqualTo: true)
              .where('timestamp', isLessThan: lastTimestamp)
              .orderBy('timestamp', descending: true)
              .limit(limit);

          final companyPosts = await companyQuery.get();
          await _processPostsSnapshot(companyPosts, addedPostIds, allNewItems);
        }

        // Obtenir les posts partagés
        if (followedUsers.isNotEmpty) {
          var sharedQuery = _firestore
              .collection('posts')
              .where('sharedBy', whereIn: followedUsers)
              .where('type', isEqualTo: 'shared')
              .where('timestamp', isLessThan: lastTimestamp)
              .orderBy('timestamp', descending: true)
              .limit(limit);

          final sharedPosts = await sharedQuery.get();
          await _processPostsSnapshot(sharedPosts, addedPostIds, allNewItems);
        }

        // Trier par date et prendre les plus récents
        allNewItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (allNewItems.isEmpty) {
          _hasMoreData = false;
          return [];
        }

        // Ne retourner que le nombre demandé d'éléments les plus récents
        return allNewItems.take(limit).toList();
      }
      return [];
    } catch (e) {
      print('Erreur dans loadMoreUnifiedFeed: $e');
      return [];
    }
  }

  Future<void> _loadLikedCompanyPostsPaginated(List<String> likedCompanies,
      Set<String> addedPostIds, List<CombinedItem> combinedItems,
      {DocumentSnapshot? startAfter, int limit = _pageSize}) async {
    if (likedCompanies.isEmpty) return;

    var query = _firestore
        .collection('posts')
        .where('companyId', whereIn: likedCompanies)
        .where('type', isNotEqualTo: 'shared')
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final postsSnapshot = await query.get();
    await _processPostsSnapshot(postsSnapshot, addedPostIds, combinedItems);
  }

  Future<void> _loadSharedPostsPaginated(List<String> followedUsers,
      Set<String> addedPostIds, List<CombinedItem> combinedItems,
      {DocumentSnapshot? startAfter, int limit = _pageSize}) async {
    if (followedUsers.isEmpty) return;

    var query = _firestore
        .collection('posts')
        .where('type', isEqualTo: 'shared')
        .where('sharedBy', whereIn: followedUsers)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final postsSnapshot = await query.get();
    await _processPostsSnapshot(postsSnapshot, addedPostIds, combinedItems);
  }

  Future<void> _processPostsSnapshot(
    QuerySnapshot postsSnapshot,
    Set<String> addedPostIds,
    List<CombinedItem> combinedItems,
  ) async {
    for (var postDoc in postsSnapshot.docs) {
      try {
        final post = _createPostFromDocument(postDoc);
        if (post != null) {
          // ID unique basé sur le type et l'identifiant du post
          String uniqueId = post is SharedPost
              ? '${post.id}_${post.originalPostId}_${postDoc.id}_${post.timestamp}'
              : '${post.id}_${postDoc.id}_${post.timestamp}';

          if (!addedPostIds.contains(uniqueId)) {
            // Ajout au Set pour éviter les doublons
            addedPostIds.add(uniqueId);

            final Map<String, dynamic> postData;

            if (post is SharedPost) {
              final sharedByUserData =
                  await _getSharedByUserData(post.sharedBy);
              final contentData = await _getOriginalContent(post);
              if (contentData == null || sharedByUserData == null) continue;

              postData = {
                'post': post,
                ...contentData,
                'sharedByUser': sharedByUserData,
                'uniqueId': uniqueId, // Ajoutez l'ID unique aux données
              };
            } else {
              final companyDoc = await _firestore
                  .collection('companys')
                  .doc(post.companyId)
                  .get();

              if (!companyDoc.exists) continue;

              postData = {
                'post': post,
                'company': companyDoc.data(),
                'uniqueId': uniqueId, // Ajoutez l'ID unique aux données
              };
            }

            // Ajouter l'élément au tableau final
            combinedItems.add(CombinedItem(postData, post.timestamp, 'post'));
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erreur lors du traitement du post: $e');
        }
        continue;
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchLikedCompanyPostsWithCompanyData(
      List<String> likedCompanies) async {
    try {
      if (likedCompanies.isEmpty) {
        return [];
      }
      final postsQuery = _firestore
          .collection('posts')
          .where('companyId', whereIn: likedCompanies)
          .where('type', isNotEqualTo: 'shared')
          .where('isActive', isEqualTo: true)
          .orderBy('timestamp', descending: true);
      final postsSnapshot = await postsQuery.get();
      List<Map<String, dynamic>> postsWithCompanyData = [];
      for (var postDoc in postsSnapshot.docs) {
        try {
          final post = _createPostFromDocument(postDoc);
          if (post != null) {
            final companyDoc = await _firestore
                .collection('companys')
                .doc(post.companyId)
                .get();
            final companyData = companyDoc.data() as Map<String, dynamic>;
            postsWithCompanyData.add({'post': post, 'company': companyData});
          }
        } catch (e) {
          print('Erreur lors du traitement du post: $e');
        }
      }
      return postsWithCompanyData;
    } catch (e) {
      // Affichage détaillé de l'erreur
      print('Erreur FirebaseException: $e');
      if (e is FirebaseException) {
        print('Code: ${e.code}');
        print('Message: ${e.message}');
        if (e.plugin == 'cloud_firestore') {
          // Extrait l'URL de l'index requis si présent dans le message
          final urlMatch =
              RegExp(r'https://console\.firebase\.google\.com/[^\s]+')
                  .firstMatch(e.message ?? '');
          if (urlMatch != null) {
            print('URL pour créer l\'index: ${urlMatch.group(0)}');
          }
        }
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSharedPostsWithCompanyData(
      List<String> followedUsers) async {
    try {
      // Vérification des utilisateurs suivis
      if (followedUsers.isEmpty) {
        if (kDebugMode) {
          print("Aucun utilisateur suivi, pas de posts partagés à charger");
        }
        return [];
      }

      // Récupération des posts partagés
      final QuerySnapshot postsSnapshot = await _firestore
          .collection('posts')
          .where('type', isEqualTo: 'shared')
          .where('sharedBy', whereIn: followedUsers)
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> postsWithCompanyData = [];

      // Traitement de chaque post
      for (final postDoc in postsSnapshot.docs) {
        try {
          // Création du post partagé
          final SharedPost? sharedPost =
              _createPostFromDocument(postDoc) as SharedPost?;
          if (sharedPost == null) continue;

          // Récupération des données de l'utilisateur qui partage
          final sharedByUserData =
              await _getSharedByUserData(sharedPost.sharedBy);
          if (sharedByUserData == null) continue;

          // Vérification du type de contenu (post ou annonce)
          final contentData = await _getOriginalContent(sharedPost);
          if (contentData != null) {
            postsWithCompanyData.add(contentData
              ..addAll({
                'post': sharedPost,
                'sharedByUser': sharedByUserData,
              }));
          }
        } catch (e) {
          continue;
        }
      }

      return postsWithCompanyData;
    } catch (e) {
      return [];
    }
  }

// Récupère les données de l'utilisateur qui partage
  Future<Map<String, dynamic>?> _getSharedByUserData(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() as Map<String, dynamic>;
    // Debug log

    final result = {
      'firstName': userData['firstName'] ?? '',
      'lastName': userData['lastName'] ?? '',
      'userProfilePicture': userData['image_profile'] ?? '',
    };
    // Debug log
    return result;
  }

// Récupère le contenu original (post ou annonce)
  Future<Map<String, dynamic>?> _getOriginalContent(
      SharedPost sharedPost) async {
    // Vérifier d'abord si c'est un post
    final originalPostDoc = await _firestore
        .collection('posts')
        .doc(sharedPost.originalPostId)
        .get();

    // Si c'est un post
    if (originalPostDoc.exists) {
      return await _handleOriginalPost(sharedPost, originalPostDoc);
    }

    // Si ce n'est pas un post, vérifier si c'est une annonce
    final adDoc =
        await _firestore.collection('ads').doc(sharedPost.originalPostId).get();

    // Si c'est une annonce
    if (adDoc.exists) {
      return await _handleOriginalAd(adDoc);
    }

    return null;
  }

// Traite un post original
  Future<Map<String, dynamic>?> _handleOriginalPost(
      SharedPost sharedPost, DocumentSnapshot originalPostDoc) async {
    final companyDoc =
        await _firestore.collection('companys').doc(sharedPost.companyId).get();

    if (!companyDoc.exists) return null;

    return {
      'company': companyDoc.data() as Map<String, dynamic>,
      'originalContent': originalPostDoc.data(),
      'isAd': false
    };
  }

// Traite une annonce originale
  Future<Map<String, dynamic>> _handleOriginalAd(DocumentSnapshot adDoc) async {
    final adData =
        Map<String, dynamic>.from(adDoc.data() as Map<String, dynamic>);
    adData['id'] = adDoc.id;

    // Récupération des données de l'utilisateur de l'annonce
    final adUserDoc =
        await _firestore.collection('users').doc(adData['userId']).get();

    if (adUserDoc.exists) {
      final adUserData = adUserDoc.data() as Map<String, dynamic>;
      adData['userName'] =
          '${adUserData['firstName']} ${adUserData['lastName']}'.trim();
      adData['userProfilePicture'] = adUserData['image_profile'] ?? '';
    }

    return {
      'company': <String, dynamic>{},
      'originalContent': adData,
      'isAd': true
    };
  }

  Post? _createPostFromDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final String type = data['type'] ?? 'unknown';
      // Ajoutez ce log

      switch (type) {
        case 'job_offer':
          return JobOffer.fromDocument(doc);
        case 'product':
          return ProductPost.fromDocument(doc);
        case 'contest':
          return Contest.fromDocument(doc);
        case 'happy_deal':
          return HappyDeal.fromDocument(doc);
        case 'express_deal':
          return ExpressDeal.fromDocument(doc);
        case 'news':
          return News.fromDocument(doc);
        case 'referral':
          return Referral.fromDocument(doc);
        case 'event':
          return Event.fromDocument(doc);
        case 'shared':
          return SharedPost.fromDocument(doc);
        case 'promo_code':
          return PromoCodePost.fromDocument(doc);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  void notifyLocationChanges() {
    notifyListeners();
  }

  void notifyLocationLoaded() {
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> applyChanges() async {
    notifyListeners();
  }
}
