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
import 'package:happy/classes/service_post.dart';
import 'package:happy/classes/share_post.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime? _lastRefreshTime;
  DateTime? get lastRefreshTime => _lastRefreshTime;
  static const Duration _minRefreshInterval =
      Duration(minutes: 2); // ou autre durée

  static const int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool get hasMoreData => _hasMoreData;

  bool _isLoading = false;
  String? _errorMessage;

  final _feedController = StreamController<List<CombinedItem>>.broadcast();
  Stream<List<CombinedItem>> get feedStream => _feedController.stream;
  List<CombinedItem> _currentFeedItems = [];
  List<CombinedItem> get currentFeedItems => _currentFeedItems;
  bool _isInitialized = false;

  // Ajout d'un singleton pour persister les données
  static final HomeProvider _instance = HomeProvider._internal();
  factory HomeProvider() {
    return _instance;
  }
  HomeProvider._internal();

  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  // Ajoutons une variable pour suivre le dernier timestamp
  DateTime? _lastLoadedTimestamp;

  // Gardons un Set des IDs déjà chargés
  final Set<String> _loadedItemIds = {};

  // Ajout d'un cache pour les données initiales
  static Map<String, dynamic>? _initialDataCache;
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheValidityDuration = Duration(minutes: 5);

  Future<List<CombinedItem>> loadUnifiedFeed(
      List<String> likedCompanies, List<String> followedUsers,
      {bool refresh = false}) async {
    // Vérifier si on peut utiliser le cache
    if (!refresh && _initialDataCache != null && _lastCacheUpdate != null) {
      final timeSinceLastCache = DateTime.now().difference(_lastCacheUpdate!);
      if (timeSinceLastCache < _cacheValidityDuration) {
        return _currentFeedItems;
      }
    }

    // Vérifier si le dernier refresh n'est pas trop récent
    if (refresh && _lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _minRefreshInterval) {
        return _currentFeedItems;
      }
    }

    if (refresh) {
      _lastDocument = null;
      _hasMoreData = true;
      _currentFeedItems.clear();
      _loadedItemIds.clear();
      notifyListeners();
    }

    try {
      if (kDebugMode) {
        print("### Début de loadUnifiedFeed ###");
        print("Nombre d'entreprises likées : ${likedCompanies.length}");
        print("Nombre d'utilisateurs suivis : ${followedUsers.length}");
      }

      final Set<String> addedPostIds = {};
      final List<CombinedItem> combinedItems = [];

      // Optimisation : Charger les données en parallèle avec des limites
      final List<Future<QuerySnapshot>> queries = [];

      // Diviser les entreprises en groupes plus petits
      const int batchSize = 10;
      final List<List<String>> companyBatches = [];

      for (var i = 0; i < likedCompanies.length; i += batchSize) {
        final end = (i + batchSize < likedCompanies.length)
            ? i + batchSize
            : likedCompanies.length;
        companyBatches.add(likedCompanies.sublist(i, end));
      }

      // Créer des requêtes optimisées
      if (likedCompanies.isNotEmpty) {
        for (var batch in companyBatches) {
          queries.add(_firestore
              .collection('posts')
              .where('companyId', whereIn: batch)
              .where('type', isNotEqualTo: 'shared')
              .where('isActive', isEqualTo: true)
              .orderBy('timestamp', descending: true)
              .limit(_pageSize)
              .get());
        }
      }

      if (followedUsers.isNotEmpty) {
        queries.add(_firestore
            .collection('posts')
            .where('type', isEqualTo: 'shared')
            .where('sharedBy', whereIn: followedUsers)
            .orderBy('timestamp', descending: true)
            .limit(_pageSize)
            .get());
      }

      // Exécuter toutes les requêtes en parallèle avec un timeout
      final List<QuerySnapshot> snapshots = await Future.wait(
        queries,
        eagerError: true,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Le chargement a pris trop de temps');
        },
      );

      // Traiter les résultats en parallèle
      await Future.wait(
        snapshots.map((snapshot) =>
            _processPostsSnapshot(snapshot, addedPostIds, combinedItems)),
      );

      // Trier et limiter les résultats
      combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _currentFeedItems = combinedItems.take(_pageSize).toList();

      // Mettre à jour le cache
      _initialDataCache = {
        'items': _currentFeedItems,
        'timestamp': DateTime.now(),
      };
      _lastCacheUpdate = DateTime.now();

      _feedController.add(_currentFeedItems);
      _lastRefreshTime = DateTime.now();

      return _currentFeedItems;
    } catch (e) {
      _feedController.addError(e);
      return [];
    }
  }

  Future<List<CombinedItem>> loadMoreUnifiedFeed(List<String> likedCompanies,
      List<String> followedUsers, CombinedItem? lastItem,
      {int limit = 10}) async {
    if (!_hasMoreData || _isLoading) return [];

    _isLoading = true;
    notifyListeners();

    try {
      if (kDebugMode) {
        print("Chargement de plus de posts...");
        print("Dernier timestamp: ${lastItem?.timestamp}");
        print("Nombre d'entreprises suivies: ${likedCompanies.length}");
      }

      final lastTimestamp = lastItem?.timestamp ?? DateTime.now();
      final List<CombinedItem> allNewItems = [];
      final Set<String> addedPostIds = {};

      // Augmentons la limite par requête pour avoir plus de résultats
      final queryLimit = limit * 2;

      // Charger les posts des entreprises
      for (var i = 0; i < likedCompanies.length; i += 10) {
        final batch = likedCompanies.sublist(
            i, i + 10 < likedCompanies.length ? i + 10 : likedCompanies.length);

        if (kDebugMode) {
          print("Traitement du lot d'entreprises: ${batch.length}");
        }

        var companyQuery = _firestore
            .collection('posts')
            .where('companyId', whereIn: batch)
            .where('type', isNotEqualTo: 'shared')
            .where('isActive', isEqualTo: true)
            .where('timestamp', isLessThan: lastTimestamp)
            .orderBy('timestamp', descending: true)
            .limit(queryLimit);

        final companyPosts = await companyQuery.get();

        if (kDebugMode) {
          print("Posts trouvés pour ce lot: ${companyPosts.docs.length}");
        }

        await _processPostsSnapshot(companyPosts, addedPostIds, allNewItems);
      }

      // Charger les posts partagés
      if (followedUsers.isNotEmpty) {
        var sharedQuery = _firestore
            .collection('posts')
            .where('sharedBy', whereIn: followedUsers)
            .where('type', isEqualTo: 'shared')
            .where('timestamp', isLessThan: lastTimestamp)
            .orderBy('timestamp', descending: true)
            .limit(queryLimit);

        final sharedPosts = await sharedQuery.get();
        await _processPostsSnapshot(sharedPosts, addedPostIds, allNewItems);
      }

      // Trier par date
      allNewItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (kDebugMode) {
        print("Nouveaux items trouvés: ${allNewItems.length}");
      }

      if (allNewItems.isEmpty) {
        _hasMoreData = false;
        notifyListeners();
        return [];
      }

      // Prendre seulement les 10 plus récents pour cette page
      final itemsToAdd = allNewItems.take(limit).toList();

      // Mettre à jour la liste principale
      _currentFeedItems.addAll(itemsToAdd);
      _feedController.add(_currentFeedItems);

      // S'il reste des items, il y a plus de données à charger
      _hasMoreData = allNewItems.length >= limit;

      if (kDebugMode) {
        print("Items ajoutés à la liste: ${itemsToAdd.length}");
        print("Total items dans la liste: ${_currentFeedItems.length}");
        print("Plus de données disponibles: $_hasMoreData");
      }

      return itemsToAdd;
    } catch (e) {
      print('Erreur dans loadMoreUnifiedFeed: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _processPostsSnapshot(
    QuerySnapshot postsSnapshot,
    Set<String> addedPostIds,
    List<CombinedItem> combinedItems,
  ) async {
    // Créer une liste de futures pour le traitement parallèle
    final List<Future<void>> futures = [];

    for (var postDoc in postsSnapshot.docs) {
      futures.add(_processPost(postDoc, addedPostIds, combinedItems));
    }

    // Attendre que tous les posts soient traités
    await Future.wait(futures);
  }

  Future<void> _processPost(
    DocumentSnapshot postDoc,
    Set<String> addedPostIds,
    List<CombinedItem> combinedItems,
  ) async {
    try {
      final post = _createPostFromDocument(postDoc);
      if (post == null) return;

      // Créer un ID unique pour ce post
      final uniqueId = '${post.id}_${post.timestamp.millisecondsSinceEpoch}';

      // Vérifier si on a déjà ce post
      if (addedPostIds.contains(uniqueId) ||
          _loadedItemIds.contains(uniqueId)) {
        return;
      }

      addedPostIds.add(uniqueId);
      _loadedItemIds.add(uniqueId);

      final Map<String, dynamic> postData;

      if (post is SharedPost) {
        final sharedByUserData = await _getSharedByUserData(post.sharedBy);
        final contentData = await _getOriginalContent(post);
        if (contentData == null || sharedByUserData == null) return;

        postData = {
          'post': post,
          ...contentData,
          'sharedByUser': sharedByUserData,
          'uniqueId': uniqueId,
        };
      } else {
        final entityDoc =
            await _firestore.collection('companys').doc(post.companyId).get();

        if (!entityDoc.exists) return;

        postData = {
          'post': post,
          'company': entityDoc.data(),
          'uniqueId': uniqueId,
        };
      }

      combinedItems.add(CombinedItem(postData, post.timestamp, 'post'));
    } catch (e) {
      print('Erreur lors du traitement du post: $e');
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
    final entityDoc =
        await _firestore.collection('companys').doc(sharedPost.companyId).get();

    if (!entityDoc.exists) return null;

    return {
      'company': entityDoc.data() as Map<String, dynamic>,
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
        case 'service':
          return ServicePost.fromDocument(doc);
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

  Future<void> initializeFeed(
      List<String> likedCompanies, List<String> followedUsers) async {
    // Vérifie si on a déjà des données avant de recharger
    if (_isInitialized && _currentFeedItems.isNotEmpty) {
      _feedController.add(_currentFeedItems);
      return;
    }

    try {
      final items = await loadUnifiedFeed(likedCompanies, followedUsers);
      _currentFeedItems = items;
      _feedController.add(_currentFeedItems);
      _isInitialized = true;
    } catch (e) {
      _feedController.addError(e);
    }
  }

  @override
  void dispose() {
    // Ne pas fermer le StreamController pour maintenir l'état
    // _feedController.close();
    super.dispose();
  }

  // Ajoutons une méthode pour obtenir un ID unique pour chaque item
  String _getUniqueItemId(CombinedItem item) {
    if (item.type == 'post') {
      final postData = item.item as Map<String, dynamic>;
      final post = postData['post'] as Post;
      return '${post.id}_${post.timestamp.millisecondsSinceEpoch}';
    }
    return ''; // Pour les autres types si nécessaire
  }
}
