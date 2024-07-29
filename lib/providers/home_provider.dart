import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/company.dart';
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
  double _selectedRadius = 40.0;
  bool _isLoading = false;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  double get selectedRadius => _selectedRadius;
  bool get isLoading => _isLoading;

  final Map<String, Post> _postCache = {};
  final Map<String, Map<String, dynamic>> _companyCache = {};
  final Map<String, dynamic> _queryCache = {};

  static const int _cacheDuration = 15; // minutes
  static const int _queryCacheDuration = 5; // minutes

  Future<void> loadSavedLocation() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('savedAddress');
      final savedLat = prefs.getDouble('savedLat');
      final savedLng = prefs.getDouble('savedLng');
      final lastLocationUpdate = prefs.getInt('lastLocationUpdate');

      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDay = 24 * 60 * 60 * 1000; // 24 heures en millisecondes

      if (savedAddress != null &&
          savedLat != null &&
          savedLng != null &&
          lastLocationUpdate != null &&
          (now - lastLocationUpdate < oneDay)) {
        _currentAddress = savedAddress;
        _currentPosition = Position(
          latitude: savedLat,
          longitude: savedLng,
          timestamp: DateTime.fromMillisecondsSinceEpoch(lastLocationUpdate),
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
        await prefs.setInt('lastLocationUpdate', now);
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

      await _getCurrentLocation();
    } catch (e) {
      print("Erreur lors de l'initialisation de la localisation: $e");
      _currentAddress = "Erreur d'initialisation de la localisation";
    }
    notifyListeners();
  }

  Future<void> applyChanges() async {
    _queryCache.clear(); // Vider le cache des requêtes
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
      _queryCache.clear();
      notifyListeners();
    } else {
      print("Erreur: Latitude ou longitude manquante dans la prédiction");
    }
  }

  void setSelectedRadius(double radius) {
    _selectedRadius = radius;
    notifyListeners();
  }

  Future<List<Company>> fetchCompanies(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      print('Position actuelle non disponible');
      return [];
    }

    final query = FirebaseFirestore.instance
        .collection('companys')
        .orderBy('name')
        .limit(pageSize);

    final snapshot = pageKey == null
        ? await query.get()
        : await query.startAfterDocument(pageKey).get();

    List<Company> companiesInRange = [];

    for (var doc in snapshot.docs) {
      Company company = Company.fromDocument(doc);

      if (await _isCompanyWithinRadius(company)) {
        companiesInRange.add(company);
      }

      if (companiesInRange.length >= pageSize) {
        break;
      }
    }

    return companiesInRange;
  }

  Future<bool> _isCompanyWithinRadius(Company company) async {
    if (_currentPosition == null) return false;

    try {
      String companyAddress =
          '${company.adress.adresse}, ${company.adress.codePostal}, ${company.adress.ville}, France';

      List<Location> locations = await locationFromAddress(companyAddress);
      if (locations.isEmpty) return false;

      Location companyLocation = locations.first;
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        companyLocation.latitude,
        companyLocation.longitude,
      );

      return distance / 1000 <= _selectedRadius;
    } catch (e) {
      print(
          "Erreur lors de la vérification de la distance pour l'entreprise ${company.name}: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPostsWithCompanyData(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      print('Position actuelle non disponible');
      return [];
    }

    final cacheKey = '${pageKey?.id ?? "initial"}_$pageSize';
    if (_queryCache.containsKey(cacheKey)) {
      final cachedResult = _queryCache[cacheKey];
      if (DateTime.now().difference(cachedResult['timestamp']).inMinutes <
          _queryCacheDuration) {
        return cachedResult['data'];
      }
    }

    final postsQuery = FirebaseFirestore.instance
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(pageSize);

    if (pageKey != null) {
      postsQuery.startAfterDocument(pageKey);
    }

    final postsSnapshot = await postsQuery.get();

    final companyRefs = postsSnapshot.docs
        .map((doc) => FirebaseFirestore.instance
            .collection('companys')
            .doc(doc['companyId']))
        .toList();

    final companySnapshots =
        await Future.wait(companyRefs.map((ref) => ref.get()));

    List<Map<String, dynamic>> postsWithCompanyData = [];

    for (int i = 0; i < postsSnapshot.docs.length; i++) {
      final postDoc = postsSnapshot.docs[i];
      final companyDoc = companySnapshots[i];

      final post = _createPostFromDocument(postDoc);
      final companyData = companyDoc.data() as Map<String, dynamic>;

      if (post != null &&
          await _isPostWithinRadius(post.companyId, companyData)) {
        postsWithCompanyData.add({
          'post': post,
          'company': companyData,
        });
      }

      if (postsWithCompanyData.length >= pageSize) {
        break;
      }
    }

    _queryCache[cacheKey] = {
      'timestamp': DateTime.now(),
      'data': postsWithCompanyData,
    };

    return postsWithCompanyData;
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

      return distance / 1000 <= _selectedRadius;
    } catch (e) {
      print("Erreur lors de la vérification de la distance: $e");
      return false;
    }
  }

  Future<void> refreshPosts() async {
    _postCache.clear();
    _queryCache.clear();
    notifyListeners();
  }

  void clearCache() {
    _postCache.clear();
    _companyCache.clear();
    _queryCache.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    addressController.dispose();
    clearCache();
    super.dispose();
  }
}
