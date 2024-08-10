import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/combined_item.dart';
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

  Future<List<CombinedItem>> loadAllData() async {
    await loadSavedLocation();
    notifyLocationChanges();

    if (_currentPosition == null) {
      throw Exception(
          "La position de l'utilisateur n'a pas pu être déterminée.");
    }

    final posts = await fetchAllPostsWithCompanyData();
    final companies = await fetchAllCompanies();

    final combinedItems = [
      ...posts.map((postData) =>
          CombinedItem(postData, postData['post'].timestamp, 'post')),
      ...companies.map(
          (company) => CombinedItem(company, company.createdAt, 'company')),
    ];

    combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return combinedItems;
  }

  Future<List<Map<String, dynamic>>> fetchAllPostsWithCompanyData() async {
    final postsQuery =
        _firestore.collection('posts').orderBy('timestamp', descending: true);
    final postsSnapshot = await postsQuery.get();

    List<Map<String, dynamic>> postsWithCompanyData = [];

    for (var postDoc in postsSnapshot.docs) {
      try {
        final postData = postDoc.data();
        final post = _createPostFromDocument(postDoc);
        if (post != null) {
          final companyDoc =
              await _firestore.collection('companys').doc(post.companyId).get();
          final companyData = companyDoc.data() as Map<String, dynamic>;
          if (await _isPostWithinRadius(post.companyId, companyData)) {
            postsWithCompanyData.add({'post': post, 'company': companyData});
          }
        }
      } catch (e) {
        print('Error processing post: $e');
      }
    }

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
          print('Unsupported post type: $type');
          return null;
      }
    } catch (e) {
      print('Error creating post from document: $e');
      return null;
    }
  }

  Future<List<Company>> fetchAllCompanies() async {
    final companiesQuery = _firestore
        .collection('companys')
        .orderBy('createdAt', descending: true);
    final companiesSnapshot = await companiesQuery.get();

    List<Company> companiesInRange = [];

    for (var doc in companiesSnapshot.docs) {
      Company company = Company.fromDocument(doc);
      if (await _isCompanyWithinRadius(company)) {
        companiesInRange.add(company);
      }
    }

    return companiesInRange;
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
    return _isWithinRadius(addressMap['latitude'], addressMap['longitude']);
  }

  void notifyLocationChanges() {
    notifyListeners();
  }

  Future<bool> _isWithinRadius(double lat, double lng) async {
    if (_currentPosition == null) return false;
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
    return distance / 1000 <= _selectedRadius;
  }

  Future<void> loadSavedLocation() async {
    _isLoading = true;
    _errorMessage = null;

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
    }
  }

  void setSelectedRadius(double radius) {
    _selectedRadius = radius;
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

  Future<Map<String, dynamic>> fetchCompanies(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      return {'data': <Company>[], 'lastDocument': null};
    }

    Query query = _firestore.collection('companys');

    // Utiliser un champ qui existe sûrement dans tous les documents, comme 'id' ou 'createdAt'
    query = query.orderBy('createdAt', descending: true);

    if (pageKey != null) {
      // Vérifier si le pageKey est un document d'entreprise
      if (pageKey.reference.parent.id == 'companys') {
        query = query.startAfterDocument(pageKey);
      } else {
        // Si ce n'est pas une entreprise, commencer depuis le début
        // mais limiter le nombre de résultats pour maintenir la pagination
        query = query.limit(pageSize);
      }
    } else {
      query = query.limit(pageSize);
    }

    final snapshot = await query.get();

    List<Company> companiesInRange = [];
    DocumentSnapshot? lastDocument;

    for (var doc in snapshot.docs) {
      Company company = Company.fromDocument(doc);
      if (await _isCompanyWithinRadius(company)) {
        companiesInRange.add(company);
      }
      lastDocument = doc;
      if (companiesInRange.length >= pageSize) {
        break;
      }
    }

    return {
      'data': companiesInRange,
      'lastDocument': lastDocument,
    };
  }

  Future<List<Map<String, dynamic>>> fetchPostsWithCompanyData(
      DocumentSnapshot? pageKey, int pageSize) async {
    if (_currentPosition == null) {
      return [];
    }

    Query postsQuery =
        _firestore.collection('posts').orderBy('timestamp', descending: true);

    if (pageKey != null) {
      postsQuery = postsQuery.startAfterDocument(pageKey);
    }

    postsQuery = postsQuery.limit(pageSize * 5);

    final postsSnapshot = await postsQuery.get();

    final cacheKey = 'posts_${pageKey?.id ?? "initial"}_$pageSize';
    if (_isCacheValid(cacheKey)) {
      return _cache[cacheKey]['data'];
    }

    List<Map<String, dynamic>> postsWithCompanyData = [];
    Map<String, int> postTypeCounts = {};

    for (var postDoc in postsSnapshot.docs) {
      try {
        final post = _createPostFromDocument(postDoc);
        if (post != null) {
          final companyDoc =
              await _firestore.collection('companys').doc(post.companyId).get();
          final companyData = companyDoc.data() as Map<String, dynamic>;
          if (await _isPostWithinRadius(post.companyId, companyData)) {
            postsWithCompanyData.add({'post': post, 'company': companyData});
            postTypeCounts[post.type] = (postTypeCounts[post.type] ?? 0) + 1;

            print(
                'Added post of type: ${post.type}. Total count: ${postTypeCounts[post.type]}');

            // Vérifier si nous avons au moins un post de chaque type et que nous avons atteint pageSize
            if (postTypeCounts.isNotEmpty &&
                postsWithCompanyData.length >= pageSize) {
              break;
            }
          }
        }
      } catch (e) {
        print('Error processing post: $e');
      }
    }

    print('Final post type counts: $postTypeCounts');

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
