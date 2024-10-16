// ignore_for_file: empty_catches

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
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
import 'package:happy/classes/share_post.dart';
import 'package:happy/widgets/web_adress_search.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController addressController = TextEditingController();

  Position? _currentPosition;
  String _currentAddress = "Localisation en cours...";
  double _selectedRadius = 40.0;
  bool _isLoading = false;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  double get selectedRadius => _selectedRadius;
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  Future<List<CombinedItem>> loadUnifiedFeed(
      List<String> likedCompanies, List<String> followedUsers) async {
    try {
      if (kDebugMode) {
        print("### Début de loadUnifiedFeed ###");
      }

      await loadSavedLocation();

      if (_currentPosition == null) {
        throw Exception("Position actuelle non disponible");
      }

      final Set<String> addedPostIds = {};
      final List<CombinedItem> combinedItems = [];

      final nearbyPosts = await fetchNearbyPostsWithCompanyData();
      _addUniquePosts(nearbyPosts, addedPostIds, combinedItems);

      final likedCompanyPosts =
          await fetchLikedCompanyPostsWithCompanyData(likedCompanies);
      _addUniquePosts(likedCompanyPosts, addedPostIds, combinedItems);

      final sharedPosts = await fetchSharedPostsWithCompanyData(followedUsers);
      _addUniquePosts(sharedPosts, addedPostIds, combinedItems);

      final companies = await fetchNearbyCompanies();
      combinedItems.addAll(companies.map(
          (company) => CombinedItem(company, company.createdAt, 'company')));

      combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return combinedItems;
    } catch (e) {
      return [];
    }
  }

  void _addUniquePosts(List<Map<String, dynamic>> posts,
      Set<String> addedPostIds, List<CombinedItem> combinedItems) {
    for (var postData in posts) {
      final post = postData['post'] as Post;
      String uniqueId =
          post is SharedPost ? '${post.id}_${post.originalPostId}' : post.id;
      if (!addedPostIds.contains(uniqueId)) {
        addedPostIds.add(uniqueId);
        combinedItems.add(CombinedItem(postData, post.timestamp, 'post'));
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchNearbyPostsWithCompanyData() async {
    try {
      final postsQuery = _firestore
          .collection('posts')
          .where('type',
              isNotEqualTo: 'shared') // Exclure les posts de type 'shared'
          .orderBy('type') // Nécessaire pour utiliser isNotEqualTo
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
            if (await _isPostWithinRadius(post.companyId, companyData)) {
              postsWithCompanyData.add({'post': post, 'company': companyData});
            }
          }
        } catch (e) {}
      }

      return postsWithCompanyData;
    } catch (e) {
      return [];
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
      if (followedUsers.isEmpty) {
        return [];
      }

      final postsQuery = _firestore
          .collection('posts')
          .where('type', isEqualTo: 'shared')
          .where('sharedBy', whereIn: followedUsers)
          .orderBy('timestamp', descending: true);
      final postsSnapshot = await postsQuery.get();

      List<Map<String, dynamic>> postsWithCompanyData = [];

      for (var postDoc in postsSnapshot.docs) {
        try {
          final sharedPost = _createPostFromDocument(postDoc) as SharedPost?;
          if (sharedPost == null) {
            continue;
          }

          final companyDoc = await _firestore
              .collection('companys')
              .doc(sharedPost.companyId)
              .get();
          if (!companyDoc.exists) {
            continue;
          }
          final companyData = companyDoc.data() as Map<String, dynamic>;

          final userDoc = await _firestore
              .collection('users')
              .doc(sharedPost.sharedBy)
              .get();
          if (!userDoc.exists) {
            continue;
          }
          final userData = userDoc.data() as Map<String, dynamic>;

          final sharedByUserData = {
            'firstName': userData['firstName'] ?? 'Prénom inconnu',
            'lastName': userData['lastName'] ?? 'Nom inconnu',
            'profileImageUrl': userData['profileImageUrl'] ?? '',
          };

          final originalPostDoc = await _firestore
              .collection('posts')
              .doc(sharedPost.originalPostId)
              .get();
          if (!originalPostDoc.exists) {
            continue;
          }
          final originalPost = _createPostFromDocument(originalPostDoc);
          if (originalPost == null) {
            continue;
          }

          final originalCompanyDoc = await _firestore
              .collection('companys')
              .doc(originalPost.companyId)
              .get();
          if (!originalCompanyDoc.exists) {
            continue;
          }
          final originalCompanyData =
              originalCompanyDoc.data() as Map<String, dynamic>;

          postsWithCompanyData.add({
            'post': sharedPost,
            'company': companyData,
            'sharedByUser': sharedByUserData,
            'originalPost': originalPost,
            'originalCompany': originalCompanyData,
          });
        } catch (e) {}
      }

      return postsWithCompanyData;
    } catch (e) {
      return [];
    }
  }

  Future<List<Company>> fetchNearbyCompanies() async {
    try {
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
    } catch (e) {
      return [];
    }
  }

  Post? _createPostFromDocument(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final String type = data['type'] ?? 'unknown';

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
        case 'shared':
          return SharedPost.fromDocument(doc);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> showLocationSelectionBottomSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildLocationBottomSheet(context),
    );
  }

  Widget _buildLocationBottomSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Sélectionnez votre ville",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildAddressSearch(context),
          const SizedBox(height: 20),
          ElevatedButton(
            child: const Text("Confirmer"),
            onPressed: () {
              Navigator.of(context).pop();
              notifyListeners();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSearch(BuildContext context) {
    if (kIsWeb) {
      return WebAddressSearch(
        homeProvider: this,
        onLocationUpdated: () {
          notifyListeners();
        },
      );
    } else {
      return GooglePlaceAutoCompleteTextField(
        textEditingController: addressController,
        googleAPIKey: "AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc",
        inputDecoration: const InputDecoration(
          hintText: "Rechercher une ville",
          alignLabelWithHint: true,
          icon: Padding(
            padding: EdgeInsets.only(left: 10.0),
            child: Icon(Icons.location_on),
          ),
          isCollapsed: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
          border: InputBorder.none,
        ),
        debounceTime: 800,
        countries: const ["fr"],
        isLatLngRequired: true,
        seperatedBuilder: const Divider(color: Colors.black12, height: 2),
        getPlaceDetailWithLatLng: (Prediction prediction) async {
          await updateLocationFromPrediction(prediction);
        },
        itemClick: (Prediction prediction) {
          addressController.text = prediction.description ?? "";
        },
      );
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

      if (savedAddress != null && savedLat != null && savedLng != null) {
        _updateCurrentLocation(savedAddress, savedLat, savedLng,
            DateTime.now().millisecondsSinceEpoch);
      } else {
        await _initializeLocation();
      }
    } catch (e) {
      _handleLocationError(
          "Erreur lors du chargement de la localisation sauvegardée", e);
    } finally {
      _isLoading = false;
      notifyListeners();
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

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        // Essayez d'obtenir la dernière position connue si la position actuelle échoue
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        throw Exception("Impossible d'obtenir la position");
      }

      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String address = placemarks.isNotEmpty
          ? "${placemarks[0].locality}, ${placemarks[0].country}"
          : "Adresse inconnue";

      _updateCurrentLocation(address, position.latitude, position.longitude,
          DateTime.now().millisecondsSinceEpoch);
      await _saveLocation(address, position);
    } catch (e) {
      _handleLocationError("Erreur d'initialisation de la localisation", e);
    }
  }

  void _handleLocationError(String message, dynamic error) {
    _currentAddress = "Localisation non disponible";
    _currentPosition = null;
    _errorMessage =
        "Impossible d'obtenir la localisation automatiquement. Veuillez entrer votre localisation manuellement.";
    notifyListeners();
  }

  Future<void> _saveLocation(String address, Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('savedAddress', address);
      await prefs.setDouble('savedLat', position.latitude);
      await prefs.setDouble('savedLng', position.longitude);
    } catch (e) {}
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
      notifyListeners();
    } else {}
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
