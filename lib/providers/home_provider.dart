// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/combined_item.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product_post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/classes/share_post.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController addressController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  Future<List<CombinedItem>> loadUnifiedFeed(
      List<String> likedCompanies, List<String> followedUsers) async {
    try {
      if (kDebugMode) {
        print("### Début de loadUnifiedFeed ###");
        print("Nombre d'entreprises likées : ${likedCompanies.length}");
        print("Nombre d'utilisateurs suivis : ${followedUsers.length}");
      }

      final Set<String> addedPostIds = {};
      final List<CombinedItem> combinedItems = [];

      // 1. Charger d'abord les posts qui ne dépendent pas de la position
      await Future.wait([
        // Posts des entreprises likées
        _loadLikedCompanyPosts(likedCompanies, addedPostIds, combinedItems),
        // Posts partagés
        _loadSharedPosts(followedUsers, addedPostIds, combinedItems),
      ]);

      // 2. Charger les posts qui dépendent de la position

      // Trier tous les éléments par date
      combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (kDebugMode) {
        print("Nombre total d'éléments chargés : ${combinedItems.length}");
      }

      return combinedItems;
    } catch (e) {
      print('Erreur dans loadUnifiedFeed: $e');
      return [];
    }
  }

  Future<void> _loadLikedCompanyPosts(List<String> likedCompanies,
      Set<String> addedPostIds, List<CombinedItem> combinedItems) async {
    final likedPosts =
        await fetchLikedCompanyPostsWithCompanyData(likedCompanies);
    _addUniquePosts(likedPosts, addedPostIds, combinedItems);
  }

  Future<void> _loadSharedPosts(List<String> followedUsers,
      Set<String> addedPostIds, List<CombinedItem> combinedItems) async {
    if (followedUsers.isEmpty) {
      if (kDebugMode) {
        print("Pas d'utilisateurs suivis, ignorant les posts partagés");
      }
      return;
    }

    if (kDebugMode) {
      print("Chargement des posts partagés...");
    }

    final sharedPosts = await fetchSharedPostsWithCompanyData(followedUsers);
    _addUniquePosts(sharedPosts, addedPostIds, combinedItems);

    if (kDebugMode) {
      print("${sharedPosts.length} posts partagés chargés");
    }
  }

  void _addUniquePosts(List<Map<String, dynamic>> posts,
      Set<String> addedPostIds, List<CombinedItem> combinedItems) {
    for (var postData in posts) {
      final post = postData['post'] as Post;
      String uniqueId = post is SharedPost
          ? '${post.id}_${post.originalPostId}_${postData['isAd'] ? 'ad' : 'post'}'
          : post.id;

      if (!addedPostIds.contains(uniqueId)) {
        addedPostIds.add(uniqueId);
        combinedItems.add(CombinedItem(postData, post.timestamp, 'post'));
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
        } catch (e) {}
      }

      return postsWithCompanyData;
    } catch (e) {
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
          print('Erreur lors du traitement du post partagé: $e');
          continue;
        }
      }

      return postsWithCompanyData;
    } catch (e) {
      print('Erreur dans fetchSharedPostsWithCompanyData: $e');
      return [];
    }
  }

// Récupère les données de l'utilisateur qui partage
  Future<Map<String, dynamic>?> _getSharedByUserData(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return null;

    final userData = userDoc.data() as Map<String, dynamic>;
    print('User Data from Firestore: $userData'); // Debug log

    final result = {
      'firstName': userData['firstName'] ?? '',
      'lastName': userData['lastName'] ?? '',
      'userProfilePicture': userData['image_profile'] ?? '',
    };
    print('Returned User Data: $result'); // Debug log
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
      print('Type de post: $type'); // Ajoutez ce log

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
        case 'referral':
          return Referral.fromDocument(doc);
        case 'event':
          return Event.fromDocument(doc);
        case 'shared':
          return SharedPost.fromDocument(doc);
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

  Future<void> _checkAndRequestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Permission de localisation refusée");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Rediriger l'utilisateur vers les paramètres
      await Geolocator.openAppSettings();
      throw Exception(
          "Permissions de localisation refusées définitivement. Veuillez les activer dans les paramètres.");
    }
  }

  Future<bool> _requestLocationService() async {
    // Sur Android, vous pouvez utiliser cette méthode pour ouvrir les paramètres de localisation
    if (Platform.isAndroid) {
      await Geolocator.openLocationSettings();
      // Attendre un peu pour laisser l'utilisateur activer le service
      await Future.delayed(const Duration(seconds: 2));
      return await Geolocator.isLocationServiceEnabled();
    }
    return false;
  }

  Future<Position?> _getCurrentPosition() async {
    if (kIsWeb) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return null;
        }

        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10));
        return position;
      } catch (e) {
        print('Erreur géolocalisation : $e');
        return null;
      }
    } else {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        return await Geolocator.getLastKnownPosition();
      }
    }
  }

  Future<String> _getAddressFromPosition(Position position) async {
    try {
      print('Tentative de conversion des coordonnées en adresse...');
      print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');

      const apiKey =
          'AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc'; // Utilisez la même clé que pour Places
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey&language=fr&result_type=locality',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        // Parcourir les composants d'adresse pour trouver la ville
        final components = data['results'][0]['address_components'];
        String? city;
        String? country;

        for (var component in components) {
          final types = component['types'] as List;
          if (types.contains('locality')) {
            city = component['long_name'];
          } else if (types.contains('country')) {
            country = component['long_name'];
          }
        }

        if (city != null) {
          return country != null ? '$city, $country' : city;
        }
      }

      // Si on ne trouve pas la ville, essayer avec placemarkFromCoordinates comme fallback
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        if (place.locality?.isNotEmpty ?? false) {
          return place.country?.isNotEmpty ?? false
              ? '${place.locality}, ${place.country}'
              : place.locality!;
        }
      }

      return 'Position (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})';
    } catch (e) {
      print('Erreur lors de la conversion des coordonnées en adresse: $e');
      return 'Position (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})';
    }
  }

  void _handleLocationError(String message, dynamic error) {
    print('$message: $error');
    // Vous pouvez ajouter ici une logique pour afficher un message à l'utilisateur
    // Par exemple avec un SnackBar ou un Dialog
  }

  Future<void> _saveLocation(String address, Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddress', address);
      await prefs.setDouble('savedLat', position.latitude);
      await prefs.setDouble('savedLng', position.longitude);
      // Ne pas recharger les données ici
    } catch (e) {
      print('Erreur lors de la sauvegarde de la localisation : $e');
    }
  }

  Future<void> applyChanges() async {
    notifyListeners();
  }

  @override
  void dispose() {
    addressController.dispose();
    super.dispose();
  }
}
