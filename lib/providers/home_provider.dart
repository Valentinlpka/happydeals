// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:collection';

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
import 'package:happy/classes/product.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/service_post.dart';
import 'package:happy/classes/service_promotion.dart';
import 'package:happy/classes/share_post.dart';

class HomeProvider extends ChangeNotifier {
  // Singleton pattern
  static final HomeProvider _instance = HomeProvider._internal();
  factory HomeProvider() => _instance;
  HomeProvider._internal();

  // Constantes
  static const Duration _minRefreshInterval = Duration(minutes: 2);
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static const Duration _companyCacheValidityDuration = Duration(minutes: 30);
  static const int _pageSize = 10;
  static const int _maxCacheSize = 100;
  static const int _batchSize = 10;

  // Services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _feedController = StreamController<List<CombinedItem>>.broadcast();

  // État
  bool _disposed = false;
  DateTime? _lastRefreshTime;
  bool _hasMoreData = true;
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _errorMessage;

  // Cache
  final Map<String, Map<String, dynamic>> _companyCache = {};
  final Map<String, DateTime> _companyCacheTimestamps = {};
  Map<String, dynamic>? _initialDataCache;
  DateTime? _lastCacheUpdate;
  final Set<String> _loadedItemIds = {};
  final List<CombinedItem> _currentFeedItems = [];
  final Queue<String> _cacheQueue = Queue();

  // Getters
  DateTime? get lastRefreshTime => _lastRefreshTime;
  bool get hasMoreData => _hasMoreData;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";
  Stream<List<CombinedItem>> get feedStream => _feedController.stream;
  List<CombinedItem> get currentFeedItems => _currentFeedItems;

  // Méthode optimisée pour obtenir les données d'une entreprise
  Future<Map<String, dynamic>?> getCompanyData(String companyId) async {
    // Vérification du cache
    if (_companyCache.containsKey(companyId)) {
      final cacheTimestamp = _companyCacheTimestamps[companyId];
      if (cacheTimestamp != null &&
          DateTime.now().difference(cacheTimestamp) <
              _companyCacheValidityDuration) {
        return _companyCache[companyId];
      }
    }

    try {
      final companyDoc =
          await _firestore.collection('companys').doc(companyId).get();
      if (!companyDoc.exists) return null;

      final companyData = companyDoc.data() as Map<String, dynamic>;
      _updateCompanyCache(companyId, companyData);
      return companyData;
    } catch (e) {
      debugPrint(
          'Erreur lors de la récupération des données de l\'entreprise: $e');
      return null;
    }
  }

  // Méthode optimisée pour charger le feed unifié
  Future<List<CombinedItem>> loadUnifiedFeed(
    List<String> likedCompanies,
    List<String> followedUsers, {
    bool refresh = false,
  }) async {
    if (!_shouldLoadData(refresh)) {
      return _currentFeedItems;
    }

    try {
      _startLoading(refresh);

      if (likedCompanies.isEmpty && followedUsers.isEmpty) {
        _hasMoreData = false;
        _currentFeedItems.clear();
        if (!_disposed) {
          _feedController.add(_currentFeedItems);
          notifyListeners();
        }
        return [];
      }

      final combinedItems = await _fetchAndProcessData(
        likedCompanies,
        followedUsers,
        refresh,
      );

      _updateFeedState(combinedItems);
      return _currentFeedItems;
    } catch (e) {
      _handleError(e);
      return [];
    } finally {
      _finishLoading();
    }
  }

  // Méthode optimisée pour charger plus de données
  Future<List<CombinedItem>> loadMoreUnifiedFeed(
    List<String> likedCompanies,
    List<String> followedUsers,
    CombinedItem? lastItem, {
    int limit = 10,
  }) async {
    if (!_hasMoreData || _isLoading) return [];

    _isLoading = true;
    notifyListeners();

    try {
      final lastTimestamp = lastItem?.timestamp ?? DateTime.now();
      final allNewItems = await _fetchMoreData(
        likedCompanies,
        followedUsers,
        lastTimestamp,
        limit,
      );

      if (allNewItems.isEmpty) {
        _hasMoreData = false;
        return [];
      }

      _updateFeedWithNewItems(allNewItems, limit);
      return allNewItems.take(limit).toList();
    } catch (e) {
      debugPrint('Erreur dans loadMoreUnifiedFeed: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Méthodes privées d'aide
  bool _shouldLoadData(bool refresh) {
    if (!refresh && _initialDataCache != null && _lastCacheUpdate != null) {
      final timeSinceLastCache = DateTime.now().difference(_lastCacheUpdate!);
      if (timeSinceLastCache < _cacheValidityDuration) {
        return false;
      }
    }

    if (refresh && _lastRefreshTime != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastRefreshTime!);
      if (timeSinceLastRefresh < _minRefreshInterval) {
        return false;
      }
    }

    return true;
  }

  void _startLoading(bool refresh) {
    _isLoading = true;
    if (refresh) {
      _isInitialLoading = true;
      _hasMoreData = true;
      _currentFeedItems.clear();
      _loadedItemIds.clear();
    }
    notifyListeners();
  }

  Future<List<CombinedItem>> _fetchAndProcessData(
    List<String> likedCompanies,
    List<String> followedUsers,
    bool refresh,
  ) async {
    final Set<String> addedPostIds = {};
    final List<CombinedItem> combinedItems = [];
    final List<Future<QuerySnapshot>> queries = [];

    // Créer des requêtes optimisées
    if (likedCompanies.isNotEmpty) {
      final companyBatches = _createBatches(likedCompanies, _batchSize);
      for (var batch in companyBatches) {
        queries.add(_createCompanyQuery(batch));
      }
    }

    if (followedUsers.isNotEmpty) {
      queries.add(_createSharedPostsQuery(followedUsers));
    }

    if (queries.isEmpty) {
      _hasMoreData = false;
      return [];
    }

    final snapshots = await _executeQueries(queries);
    await _processSnapshots(snapshots, addedPostIds, combinedItems);

    return combinedItems;
  }

  List<List<String>> _createBatches(List<String> items, int batchSize) {
    final List<List<String>> batches = [];
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  Future<QuerySnapshot> _createCompanyQuery(List<String> companyIds) {
    return _firestore
        .collection('posts')
        .where('companyId', whereIn: companyIds)
        .where('type', isNotEqualTo: 'shared')
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize)
        .get();
  }

  Future<QuerySnapshot> _createSharedPostsQuery(List<String> followedUsers) {
    return _firestore
        .collection('posts')
        .where('type', isEqualTo: 'shared')
        .where('sharedBy', whereIn: followedUsers)
        .orderBy('timestamp', descending: true)
        .limit(_pageSize)
        .get();
  }

  Future<List<QuerySnapshot>> _executeQueries(
      List<Future<QuerySnapshot>> queries) {
    return Future.wait(
      queries,
      eagerError: true,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Le chargement a pris trop de temps');
      },
    );
  }

  Future<void> _processSnapshots(
    List<QuerySnapshot> snapshots,
    Set<String> addedPostIds,
    List<CombinedItem> combinedItems,
  ) async {
    await Future.wait(
      snapshots.map((snapshot) =>
          _processPostsSnapshot(snapshot, addedPostIds, combinedItems)),
    );
  }

  void _updateFeedState(List<CombinedItem> combinedItems) {
    combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _currentFeedItems.clear();
    _currentFeedItems.addAll(combinedItems.take(_pageSize));

    _initialDataCache = {
      'items': _currentFeedItems,
      'timestamp': DateTime.now(),
    };
    _lastCacheUpdate = DateTime.now();

    if (!_disposed) {
      _feedController.add(_currentFeedItems);
      _lastRefreshTime = DateTime.now();
      _isInitialLoading = false;
      notifyListeners();
    }
  }

  void _handleError(dynamic error) {
    _errorMessage = error.toString();
    _feedController.addError(error);
  }

  void _finishLoading() {
    _isLoading = false;
    _isInitialLoading = false;
    notifyIfNotDisposed();
  }

  void _updateCompanyCache(String companyId, Map<String, dynamic> data) {
    _companyCache[companyId] = data;
    _companyCacheTimestamps[companyId] = DateTime.now();
    _cacheQueue.add(companyId);

    // Limiter la taille du cache
    while (_cacheQueue.length > _maxCacheSize) {
      final oldestId = _cacheQueue.removeFirst();
      _companyCache.remove(oldestId);
      _companyCacheTimestamps.remove(oldestId);
    }
  }

  Future<List<CombinedItem>> _fetchMoreData(
    List<String> likedCompanies,
    List<String> followedUsers,
    DateTime lastTimestamp,
    int limit,
  ) async {
    final Set<String> addedPostIds = {};
    final List<CombinedItem> allNewItems = [];
    final queryLimit = limit * 2;

    // Charger les posts des entreprises
    for (var i = 0; i < likedCompanies.length; i += _batchSize) {
      final batch = likedCompanies.sublist(
        i,
        i + _batchSize < likedCompanies.length
            ? i + _batchSize
            : likedCompanies.length,
      );

      final companyQuery = _firestore
          .collection('posts')
          .where('companyId', whereIn: batch)
          .where('type', isNotEqualTo: 'shared')
          .where('isActive', isEqualTo: true)
          .where('timestamp', isLessThan: lastTimestamp)
          .orderBy('timestamp', descending: true)
          .limit(queryLimit);

      final companyPosts = await companyQuery.get();
      await _processPostsSnapshot(companyPosts, addedPostIds, allNewItems);
    }

    // Charger les posts partagés
    if (followedUsers.isNotEmpty) {
      final sharedQuery = _firestore
          .collection('posts')
          .where('sharedBy', whereIn: followedUsers)
          .where('type', isEqualTo: 'shared')
          .where('timestamp', isLessThan: lastTimestamp)
          .orderBy('timestamp', descending: true)
          .limit(queryLimit);

      final sharedPosts = await sharedQuery.get();
      await _processPostsSnapshot(sharedPosts, addedPostIds, allNewItems);
    }

    allNewItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allNewItems;
  }

  void _updateFeedWithNewItems(List<CombinedItem> allNewItems, int limit) {
    final itemsToAdd = allNewItems.take(limit).toList();
    _currentFeedItems.addAll(itemsToAdd);
    _feedController.add(_currentFeedItems);
    _hasMoreData = allNewItems.length >= limit;
  }

  Future<void> _processPostsSnapshot(
    QuerySnapshot postsSnapshot,
    Set<String> addedPostIds,
    List<CombinedItem> combinedItems,
  ) async {
    // Collecter tous les IDs d'entreprises uniques
    final Set<String> companyIds = {};
    final List<DocumentSnapshot> validPosts = [];

    for (var postDoc in postsSnapshot.docs) {
      final data = postDoc.data() as Map<String, dynamic>;
      if (data['companyId'] != null) {
        companyIds.add(data['companyId'] as String);
      }
      validPosts.add(postDoc);
    }

    // Pré-charger toutes les données d'entreprises en une seule fois
    await Future.wait(companyIds.map((companyId) => getCompanyData(companyId)));

    // Traiter les posts avec les données d'entreprises en cache
    final List<Future<void>> futures = [];
    for (var postDoc in validPosts) {
      futures.add(_processPost(postDoc, addedPostIds, combinedItems));
    }

    await Future.wait(futures);
  }

  // Fonction utilitaire pour valider et nettoyer les URLs d'images
  String _sanitizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return '';
    }

    final trimmedUrl = url.trim();
    
    // Vérifier si l'URL commence par file:///
    if (trimmedUrl.startsWith('file:///')) {
      return '';
    }

    // Vérifier si l'URL est valide (commence par http:// ou https://)
    if (!trimmedUrl.startsWith('http://') && !trimmedUrl.startsWith('https://')) {
      return '';
    }

    return trimmedUrl;
  }

  Future<void> _processPost(
    DocumentSnapshot postDoc,
    Set<String> addedPostIds,
    List<CombinedItem> combinedItems,
  ) async {
    try {
      debugPrint("Début du traitement du post ${postDoc.id}");
      
      // Vérification et conversion sécurisée des données numériques
      final data = postDoc.data() as Map<String, dynamic>;
      _sanitizeNumericValues(data);

      // Nettoyer les URLs d'images
      if (data['images'] is List) {
        data['images'] = (data['images'] as List).map((img) => _sanitizeImageUrl(img?.toString())).where((url) => url.isNotEmpty).toList();
      }
      if (data['image'] != null) {
        data['image'] = _sanitizeImageUrl(data['image']?.toString());
      }
      if (data['companyLogo'] != null) {
        data['companyLogo'] = _sanitizeImageUrl(data['companyLogo']?.toString());
      }

      final post = _createPostFromDocument(postDoc);
      if (post == null) {
        debugPrint("❌ Post null pour le document ${postDoc.id}");
        return;
      }

      final uniqueId = '${post.id}_${post.timestamp.millisecondsSinceEpoch}';
      if (addedPostIds.contains(uniqueId) ||
          _loadedItemIds.contains(uniqueId)) {
        debugPrint("Post déjà ajouté: $uniqueId");
        return;
      }

      addedPostIds.add(uniqueId);
      _loadedItemIds.add(uniqueId);

      final Map<String, dynamic> postData;

      if (post is SharedPost) {
        final sharedByUserData = await _getSharedByUserData(post.sharedBy!);
        final contentData = await _getOriginalContent(post);
        if (contentData == null || sharedByUserData == null) {
          debugPrint("❌ Données manquantes pour le post partagé ${post.id}");
          return;
        }

        postData = {
          'post': post,
          ...contentData,
          'sharedByUser': sharedByUserData,
          'uniqueId': uniqueId,
        };
      } else {
        final companyData = await getCompanyData(post.companyId);
        if (companyData == null) {
          debugPrint("❌ Données d'entreprise manquantes pour ${post.id}");
          return;
        }

        postData = {
          'post': post,
          'company': companyData,
          'uniqueId': uniqueId,
        };
      }

      combinedItems.add(CombinedItem(postData, post.timestamp, 'post'));
      debugPrint("✅ Post ${post.id} traité avec succès");
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors du traitement du post ${postDoc.id}: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _sanitizeNumericValues(Map<String, dynamic> data) {
    // Fonction utilitaire pour convertir en double
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final normalized = value.trim().replaceAll(',', '.');
        return double.tryParse(normalized);
      }
      return null;
    }

    // Fonction utilitaire pour convertir en int
    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    // Liste des champs qui doivent être des nombres
    final numericFields = [
      'price', 'basePrice', 'finalPrice', 'tva',
      'duration', 'views', 'likes', 'commentsCount',
      'sharesCount', 'value', 'stock'
    ];

    // Conversion des champs numériques
    for (var field in numericFields) {
      if (data.containsKey(field)) {
        final value = data[field];
        if (field == 'views' || field == 'likes' || 
            field == 'commentsCount' || field == 'sharesCount' || 
            field == 'stock') {
          data[field] = toInt(value) ?? 0;
        } else {
          data[field] = toDouble(value) ?? 0.0;
        }
      }
    }

    // Traitement des sous-objets
    if (data['variants'] is List) {
      for (var variant in data['variants']) {
        if (variant is Map<String, dynamic>) {
          _sanitizeNumericValues(variant);
        }
      }
    }

    if (data['discount'] is Map<String, dynamic>) {
      _sanitizeNumericValues(data['discount']);
    }
  }

  Post? _createPostFromDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final String type = data['type'] ?? 'unknown';

      // Vérification et conversion des types numériques
      if (data['price'] != null) {
        data['price'] = (data['price'] is int)
            ? (data['price'] as int).toDouble()
            : data['price'];
      }

      if (data['duration'] != null) {
        data['duration'] = (data['duration'] is int)
            ? (data['duration'] as int).toDouble()
            : data['duration'];
      }

      // Vérification et conversion des Timestamp
      if (data['timestamp'] != null) {
        if (data['timestamp'] is String) {
          try {
            data['timestamp'] =
                Timestamp.fromDate(DateTime.parse(data['timestamp']));
          } catch (e) {
            debugPrint('❌ Erreur de conversion du timestamp: $e');
            return null;
          }
        } else if (data['timestamp'] is! Timestamp) {
          debugPrint(
              '❌ Type de timestamp invalide: ${data['timestamp'].runtimeType}');
          return null;
        }
      } else {
        debugPrint('❌ Timestamp manquant');
        return null;
      }

      switch (type) {
        case 'job_offer':
          return JobOffer.fromDocument(doc);
        case 'product':
          return Product.fromFirestore(doc);
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
        case 'service_promotion':
          return ServicePromotion.fromFirestore(doc);
        case 'service':
          return ServicePost.fromDocument(doc);
        default:
          debugPrint('⚠️ Type de post inconnu: $type');
          return null;
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la création du post: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getSharedByUserData(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() as Map<String, dynamic>;
    return {
      'firstName': userData['firstName'] ?? '',
      'lastName': userData['lastName'] ?? '',
      'userProfilePicture': userData['image_profile'] ?? '',
    };
  }

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

  void reset() {
    // Éviter les notifications multiples en regroupant les changements
    _lastRefreshTime = null;
    _hasMoreData = true;
    _isLoading = false;
    _isInitialLoading = true;
    _errorMessage = null;
    _initialDataCache = null;
    _lastCacheUpdate = null;
    _loadedItemIds.clear();
    _currentFeedItems.clear();
    _cacheQueue.clear();
    _companyCache.clear();
    _companyCacheTimestamps.clear();

    // Une seule notification à la fin
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _feedController.close();
    super.dispose();
  }

  void notifyIfNotDisposed() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
