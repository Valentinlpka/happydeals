import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeProvider extends ChangeNotifier {
  final TextEditingController addressController = TextEditingController();

  Position? _currentPosition;
  String _currentAddress = "Localisation en cours...";
  double _selectedRadius = 10.0;
  bool _isLoading = false;
  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  double get selectedRadius => _selectedRadius;
  bool get isLoading => _isLoading;

  // Cache pour les posts
  final Map<String, Post> _postCache = {};
  // Cache pour les données des entreprises
  final Map<String, Map<String, dynamic>> _companyCache = {};

  // Durée de validité du cache (en minutes)
  static const int _cacheDuration = 15;

  // Nouvelle méthode pour mettre à jour la localisation à partir d'une prédiction
  Future<void> updateLocationFromPrediction(Prediction prediction) async {
    if (prediction.lat != null && prediction.lng != null) {
      _currentPosition = Position(
        latitude: double.parse(prediction.lat!),
        longitude: double.parse(prediction.lng!),
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _currentAddress = prediction.description ?? "";
      await _saveLocation(_currentAddress, _currentPosition!);
      notifyListeners();
    } else {
      print("Erreur: Latitude ou longitude manquante dans la prédiction");
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      _currentPosition = position;
      _currentAddress = placemarks.isNotEmpty
          ? "${placemarks[0].locality}, ${placemarks[0].country}"
          : "Adresse inconnue";
      addressController.text = _currentAddress;
      await _saveLocation(_currentAddress, position);
      print("Nouvelle position : ${position.latitude}, ${position.longitude}");
      print("Nouvelle adresse : $_currentAddress");
    } catch (e) {
      print("Erreur de localisation: $e");
      _currentAddress = "Impossible d'obtenir la localisation";
      addressController.text = _currentAddress;
    }
    notifyListeners();
  }

  Future<void> loadSavedLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('savedAddress');
      final savedLat = prefs.getDouble('savedLat');
      final savedLng = prefs.getDouble('savedLng');

      if (savedAddress != null && savedLat != null && savedLng != null) {
        _currentAddress = savedAddress;
        _currentPosition = Position(
          latitude: savedLat,
          longitude: savedLng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      } else {
        await _initializeLocation();
      }
    } catch (e) {
      print("Erreur lors du chargement de la localisation sauvegardée: $e");
      _currentAddress = "Erreur de chargement de la localisation";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _currentAddress = "Services de localisation désactivés";
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _currentAddress = "Permission de localisation refusée";
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _currentAddress = "Permissions de localisation refusées définitivement";
        return;
      }

      await getCurrentLocation();
    } catch (e) {
      print("erreur lors de l'initialisation de la localisation ");
      _currentAddress = "Erreur d'initialisation de la localisation";
    }
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      _currentPosition = position;
      _currentAddress = placemarks.isNotEmpty
          ? "${placemarks[0].locality}, ${placemarks[0].country}"
          : "Adresse inconnue";
      await _saveLocation(_currentAddress, position);
    } catch (e) {
      print("Erreur de localisation: $e");
      _currentAddress = "Impossible d'obtenir la localisation";
    }
    notifyListeners();
  }

  Future<void> _saveLocation(String address, Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddress', address);
      await prefs.setDouble('savedLat', position.latitude);
      await prefs.setDouble('savedLng', position.longitude);
    } catch (e) {
      print("Erreur lors de la sauvegarde de la localisation: $e");
    }
  }

  void setSelectedRadius(double radius) {
    _selectedRadius = radius;
    notifyListeners();
  }

  Future<List<Post>> fetchPosts(DocumentSnapshot? pageKey) async {
    if (_currentPosition == null) {
      print('Position actuelle non disponible');
      return [];
    }

    final postsWithCompanyData = await fetchPostsWithCompanyData(pageKey, 10);

    final posts =
        postsWithCompanyData.map((data) => data['post'] as Post).toList();

    print("Nombre de posts trouvés : ${posts.length}");
    return posts;
  }

  Post? _getPostFromCache(String postId) {
    if (_postCache.containsKey(postId)) {
      final cachedPost = _postCache[postId]!;
      if (DateTime.now().difference(cachedPost.timestamp).inMinutes <
          _cacheDuration) {
        return cachedPost;
      } else {
        _postCache.remove(postId);
      }
    }
    return null;
  }

  void _addPostToCache(String postId, Post post) {
    _postCache[postId] = post;
  }

  Future<bool> _isPostWithinRadius(
      String companyId, Map<String, dynamic> companyData) async {
    if (_currentPosition == null) return false;

    try {
      Map<String, dynamic>? addressMap =
          companyData['adress'] as Map<String, dynamic>?;

      if (addressMap == null ||
          !addressMap.containsKey('adresse') ||
          !addressMap.containsKey('code_postal') ||
          !addressMap.containsKey('ville')) {
        return false;
      }

      String companyAddress =
          '${addressMap['adresse']}, ${addressMap['code_postal']}, ${addressMap['ville']}, France';

      List<Location> locations = await locationFromAddress(companyAddress);
      if (locations.isEmpty) return false;

      Location companyLocation = locations.first;
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        companyLocation.latitude,
        companyLocation.longitude,
      );

      bool isWithinRadius = distance / 1000 <= _selectedRadius;
      print(
          "Distance to company: ${distance / 1000} km, Within radius: $isWithinRadius");
      return isWithinRadius;
    } catch (e) {
      print("Erreur lors de la vérification de la distance: $e");
      return false;
    }
  }

  Map<String, dynamic>? _getCompanyFromCache(String companyId) {
    if (_companyCache.containsKey(companyId)) {
      final cachedCompany = _companyCache[companyId]!;
      if (DateTime.now()
              .difference(cachedCompany['timestamp'] as DateTime)
              .inMinutes <
          _cacheDuration) {
        return cachedCompany;
      } else {
        _companyCache.remove(companyId);
      }
    }
    return null;
  }

  void _addCompanyToCache(String companyId, Map<String, dynamic> companyData) {
    companyData['timestamp'] = DateTime.now();
    _companyCache[companyId] = companyData;
  }

  void clearCache() {
    _postCache.clear();
    _companyCache.clear();
    notifyListeners();
  }

  Post? _createPostFromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String type = data['type'] ?? 'unknown';

    try {
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
        default:
          print("Type de post non supporté: $type pour le document ${doc.id}");
          return null;
      }
    } catch (e) {
      print("Erreur lors de la création du post de type $type: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPostsWithCompanyData(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      print('Position actuelle non disponible');
      return [];
    }

    final query = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(pageSize);

    final snapshot = pageKey == null
        ? await query.get()
        : await query.startAfterDocument(pageKey).get();

    List<Map<String, dynamic>> postsWithCompanyData = [];

    for (var doc in snapshot.docs) {
      final postId = doc.id;
      Post? post = _getPostFromCache(postId);

      if (post == null) {
        post = _createPostFromDocument(doc);
        if (post != null) {
          _addPostToCache(postId, post);
        }
      }

      if (post != null) {
        Map<String, dynamic>? companyData =
            await _getCompanyData(post.companyId);

        if (companyData != null &&
            await _isPostWithinRadius(post.companyId, companyData)) {
          postsWithCompanyData.add({
            'post': post,
            'company': companyData,
          });
        }
      }

      if (postsWithCompanyData.length >= pageSize) {
        break;
      }
    }

    print("Nombre de posts trouvés : ${postsWithCompanyData.length}");
    return postsWithCompanyData;
  }

  Future<Map<String, dynamic>?> _getCompanyData(String companyId) async {
    Map<String, dynamic>? companyData = _getCompanyFromCache(companyId);

    if (companyData == null) {
      try {
        DocumentSnapshot companyDoc = await FirebaseFirestore.instance
            .collection('companys')
            .doc(companyId)
            .get();

        if (companyDoc.exists) {
          companyData = companyDoc.data() as Map<String, dynamic>;
          _addCompanyToCache(companyId, companyData);
        }
      } catch (e) {
        print("Erreur lors de la récupération des données de l'entreprise: $e");
      }
    }

    return companyData;
  }

  @override
  void dispose() {
    addressController.dispose();
    clearCache();
    super.dispose();
  }
}
