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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Position? _currentPosition;
  String _currentAddress = "Localisation en cours...";
  double _selectedRadius = 40.0;
  bool _isLoading = false;
  String? _errorMessage;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  double get selectedRadius => _selectedRadius;
  bool get isLoading => _isLoading;

  final Map<String, dynamic> _cache = {};
  static const int _cacheDuration = 15; // minutes

  Future<void> loadSavedLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    // Ne pas notifier les listeners ici

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('savedAddress');
      final savedLat = prefs.getDouble('savedLat');
      final savedLng = prefs.getDouble('savedLng');
      final lastLocationUpdate = prefs.getInt('lastLocationUpdate');

      final now = DateTime.now().millisecondsSinceEpoch;
      const oneDay = 24 * 60 * 60 * 1000;

      if (savedAddress != null &&
          savedLat != null &&
          savedLng != null &&
          lastLocationUpdate != null &&
          (now - lastLocationUpdate < oneDay)) {
        _updateCurrentLocation(
            savedAddress, savedLat, savedLng, lastLocationUpdate);
      } else {
        await _initializeLocation();
        await prefs.setInt('lastLocationUpdate', now);
      }
    } catch (e) {
      _handleLocationError(
          "Erreur lors du chargement de la localisation sauvegardée", e);
    } finally {
      _isLoading = false;
      // Ne pas notifier les listeners ici
    }
  }

  void notifyLocationLoaded() {
    notifyListeners();
  }

  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  void _updateCurrentLocation(
      String address, double lat, double lng, int timestamp) {
    _currentAddress = address;
    _currentPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception("Services de localisation désactivés");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permission de localisation refusée");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Permissions de localisation refusées définitivement");
      }

      await _getCurrentLocation();
    } catch (e) {
      _handleLocationError(
          "Erreur lors de l'initialisation de la localisation", e);
    }
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
      _handleLocationError("Erreur de localisation", e);
    }
    notifyListeners();
  }

  void _handleLocationError(String message, dynamic error) {
    _currentAddress = "Erreur de localisation";
  }

  Future<void> _saveLocation(String address, Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddress', address);
      await prefs.setDouble('savedLat', position.latitude);
      await prefs.setDouble('savedLng', position.longitude);
    } catch (e) {
      Text(e.toString());
    }
  }

  Future<void> updateLocationFromPrediction(Prediction prediction) async {
    if (prediction.lat != null && prediction.lng != null) {
      _updateCurrentLocation(
        prediction.description ?? "",
        double.parse(prediction.lat!),
        double.parse(prediction.lng!),
        DateTime.now().millisecondsSinceEpoch,
      );
      await _saveLocation(_currentAddress, _currentPosition!);
      clearCache();
      notifyListeners();
    } else {}
  }

  void setSelectedRadius(double radius) {
    _selectedRadius = radius;
    clearCache();
    notifyListeners();
  }

  Future<List<Company>> fetchCompanies(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      return [];
    }

    final cacheKey = 'companies_${pageKey?.id ?? "initial"}_$pageSize';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey];
    }

    final query =
        _firestore.collection('companys').orderBy('name').limit(pageSize);
    final snapshot = pageKey == null
        ? await query.get()
        : await query.startAfterDocument(pageKey).get();

    List<Company> companiesInRange = [];
    for (var doc in snapshot.docs) {
      Company company = Company.fromDocument(doc);
      if (await _isCompanyWithinRadius(company)) {
        companiesInRange.add(company);
      }
      if (companiesInRange.length >= pageSize) break;
    }

    _cache[cacheKey] = {'data': companiesInRange, 'timestamp': DateTime.now()};
    return companiesInRange;
  }

  Future<List<Map<String, dynamic>>> fetchPostsWithCompanyData(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      return [];
    }

    final cacheKey = 'posts_${pageKey?.id ?? "initial"}_$pageSize';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]['data'];
    }

    final postsQuery = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(pageSize * 2);
    final postsSnapshot = pageKey == null
        ? await postsQuery.get()
        : await postsQuery.startAfterDocument(pageKey).get();

    List<Map<String, dynamic>> postsWithCompanyData = [];
    for (var postDoc in postsSnapshot.docs) {
      try {
        final post = _createPostFromDocument(postDoc);
        if (post != null) {
          final companyDoc =
              await _firestore.collection('companys').doc(post.companyId).get();
          final companyData = companyDoc.data() as Map<String, dynamic>;
          if (await _isPostWithinRadius(post.companyId, companyData)) {
            postsWithCompanyData.add({'post': post, 'company': companyData});
            if (postsWithCompanyData.length >= pageSize) break;
          }
        }
      } catch (e) {}
    }

    _cache[cacheKey] = {
      'data': postsWithCompanyData,
      'timestamp': DateTime.now()
    };
    return postsWithCompanyData;
  }

  bool _isCacheValid(String key) {
    if (_cache.containsKey(key)) {
      final cachedData = _cache[key];
      if (DateTime.now().difference(cachedData['timestamp']).inMinutes <
          _cacheDuration) {
        return true;
      }
    }
    return false;
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
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<bool> _isCompanyWithinRadius(Company company) async {
    return _isWithinRadius(company.adress.latitude, company.adress.longitude);
  }

  Future<bool> _isPostWithinRadius(
      String companyId, Map<String, dynamic> companyData) async {
    Map<String, dynamic>? addressMap =
        companyData['adress'] as Map<String, dynamic>?;
    if (addressMap == null ||
        !addressMap.containsKey('latitude') ||
        !addressMap.containsKey('longitude')) {
      return false;
    }
    bool result =
        await _isWithinRadius(addressMap['latitude'], addressMap['longitude']);
    return result;
  }

  Future<bool> _isWithinRadius(double lat, double lng) async {
    if (_currentPosition == null) return false;
    try {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat,
        lng,
      );
      return distance / 1000 <= _selectedRadius;
    } catch (e) {
      return false;
    }
  }

  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  Future<void> applyChanges() async {
    clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    addressController.dispose();
    clearCache();
    super.dispose();
  }
}
