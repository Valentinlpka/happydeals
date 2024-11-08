// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:happy/providers/localisation_service.dart';
import 'package:happy/widgets/web_adress_search.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController addressController = TextEditingController();

  Position? _currentPosition;
  String _currentAddress = "Localisation en cours...";
  double _selectedRadius = 10.0;
  bool _isLoading = false;
  String? _errorMessage;

  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  double get selectedRadius => _selectedRadius;
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  void updateLocation(Position position) {
    _currentPosition = position;
    // Mettre à jour l'adresse et d'autres données liées à la position
    // ...
    notifyListeners();
  }

  Future<List<CombinedItem>> loadUnifiedFeed(
      List<String> likedCompanies, List<String> followedUsers) async {
    try {
      if (kDebugMode) {
        print("### Début de loadUnifiedFeed ###");
        print(
            "Position actuelle : ${_currentPosition?.latitude}, ${_currentPosition?.longitude}");
        print("Adresse actuelle : $_currentAddress");
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
      if (_currentPosition != null) {
        await Future.wait([
          // Posts à proximité
          _loadNearbyPosts(addedPostIds, combinedItems),
          // Entreprises à proximité
          _loadNearbyCompanies(combinedItems),
        ]);
      }

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

  Future<void> _loadNearbyPosts(
      Set<String> addedPostIds, List<CombinedItem> combinedItems) async {
    final nearbyPosts = await fetchNearbyPostsWithCompanyData();
    _addUniquePosts(nearbyPosts, addedPostIds, combinedItems);
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

  Future<void> _loadNearbyCompanies(List<CombinedItem> combinedItems) async {
    final companies = await fetchNearbyCompanies();
    combinedItems.addAll(companies
        .map((company) => CombinedItem(company, company.createdAt, 'company')));
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
      if (_currentPosition == null) {
        print(
            'Position actuelle non disponible pour fetchNearbyPostsWithCompanyData');
        return [];
      }

      final postsQuery = _firestore
          .collection('posts')
          .where('type', isNotEqualTo: 'shared')
          .orderBy('type')
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

            if (!companyDoc.exists) {
              print('Entreprise ${post.companyId} non trouvée');
              continue;
            }

            final companyData = companyDoc.data() as Map<String, dynamic>;

            // Vérification du rayon avec logs
            if (await _isPostWithinRadius(post.companyId, companyData)) {
              if (kDebugMode) {
                print('Post ${post.id} ajouté (dans le rayon)');
              }
              postsWithCompanyData.add({'post': post, 'company': companyData});
            } else if (kDebugMode) {
              print('Post ${post.id} ignoré (hors rayon)');
            }
          }
        } catch (e) {
          print('Erreur lors du traitement d\'un post: $e');
        }
      }

      if (kDebugMode) {
        print('Nombre total de posts trouvés: ${postsWithCompanyData.length}');
      }

      return postsWithCompanyData;
    } catch (e) {
      print('Erreur dans fetchNearbyPostsWithCompanyData: $e');
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
        if (kDebugMode) {
          print("Aucun utilisateur suivi, pas de posts partagés à charger");
        }
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
        final sharedPost = _createPostFromDocument(postDoc) as SharedPost?;
        if (sharedPost == null || sharedPost.originalPostId.isEmpty) {
          continue; // Ignorez les posts sans originalPostId
        }

        // Récupération des informations de l'utilisateur qui a partagé
        final userDoc =
            await _firestore.collection('users').doc(sharedPost.sharedBy).get();
        if (!userDoc.exists) continue;
        final userData = userDoc.data() as Map<String, dynamic>;
        final sharedByUserData = {
          'firstName': userData['firstName'] ?? 'Prénom inconnu',
          'lastName': userData['lastName'] ?? 'Nom inconnu',
          'profileImageUrl': userData['profileImageUrl'] ?? '',
        };

        // Récupération du contenu d'origine (post ou annonce)
        DocumentSnapshot originalContentDoc;
        Map<String, dynamic>? originalContentData;
        Map<String, dynamic>? originalCompanyData;
        bool isAd = false;

        try {
          originalContentDoc = await _firestore
              .collection('posts')
              .doc(sharedPost.originalPostId)
              .get();
          if (originalContentDoc.exists) {
            originalContentData =
                originalContentDoc.data() as Map<String, dynamic>?;
            final companyDoc = await _firestore
                .collection('companys')
                .doc(sharedPost.companyId)
                .get();
            if (companyDoc.exists) {
              originalCompanyData = companyDoc.data() as Map<String, dynamic>;
            }
          } else {
            // Si ce n'est pas un post, vérifiez si c'est une annonce
            originalContentDoc = await _firestore
                .collection('ads')
                .doc(sharedPost.originalPostId)
                .get();
            if (originalContentDoc.exists) {
              originalContentData =
                  originalContentDoc.data() as Map<String, dynamic>?;
              isAd = true;
            }
          }
        } catch (e) {
          print("Erreur lors de la récupération du contenu d'origine : $e");
          continue;
        }

        // Si ni post ni annonce n'a été trouvé, ignorez cet élément
        if (originalContentData == null) continue;

        postsWithCompanyData.add({
          'post': sharedPost,
          'company': originalCompanyData ?? {},
          'sharedByUser': sharedByUserData,
          'originalContent': originalContentData,
          'isAd': isAd,
        });
      }

      return postsWithCompanyData;
    } catch (e) {
      print('Erreur dans fetchSharedPostsWithCompanyData: $e');
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
    try {
      Map<String, dynamic>? addressMap =
          companyData['adress'] as Map<String, dynamic>?;

      // Vérification plus stricte des données d'adresse
      if (addressMap == null ||
          !addressMap.containsKey('latitude') ||
          !addressMap.containsKey('longitude') ||
          addressMap['latitude'] == null ||
          addressMap['longitude'] == null) {
        print(
            'Données d\'adresse invalides pour le post de l\'entreprise $companyId');
        return false;
      }

      // Conversion explicite en double pour éviter les erreurs de type
      double companyLat = (addressMap['latitude'] is int)
          ? (addressMap['latitude'] as int).toDouble()
          : addressMap['latitude'] as double;
      double companyLng = (addressMap['longitude'] is int)
          ? (addressMap['longitude'] as int).toDouble()
          : addressMap['longitude'] as double;

      if (_currentPosition == null) {
        print('Position actuelle non disponible');
        return false;
      }

      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        companyLat,
        companyLng,
      );

      final isInRadius = distance / 1000 <= _selectedRadius;
      if (kDebugMode) {
        print(
            'Distance pour $companyId: ${distance / 1000}km (Rayon: $_selectedRadius km)');
        print('Est dans le rayon: $isInRadius');
      }

      return isInRadius;
    } catch (e) {
      print(
          'Erreur lors de la vérification du rayon pour le post $companyId: $e');
      return false;
    }
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
      Position? position = await _getCurrentPosition();
      if (position == null) {
        throw Exception("Position non disponible");
      }

      final locationData = await LocationService.getLocationFromCoordinates(
        position.latitude,
        position.longitude,
      );

      _updateCurrentLocation(
        locationData['address'],
        locationData['latitude'],
        locationData['longitude'],
        DateTime.now().millisecondsSinceEpoch,
      );

      await _saveLocation(
        locationData['address'],
        Position(
          latitude: locationData['latitude'],
          longitude: locationData['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
      );
    } catch (e) {
      print('Erreur dans _initializeLocation: $e');
      _handleLocationError("Erreur d'initialisation de la localisation", e);
    }
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

  Future<void> updateLocationFromPrediction(Prediction prediction) async {
    try {
      final locationData =
          await LocationService.getLocationFromPrediction(prediction);

      _updateCurrentLocation(
        locationData['address'],
        locationData['latitude'],
        locationData['longitude'],
        DateTime.now().millisecondsSinceEpoch,
      );

      await _saveLocation(
        locationData['address'],
        Position(
          latitude: locationData['latitude'],
          longitude: locationData['longitude'],
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
      );

      notifyListeners();
    } catch (e) {
      print('Erreur lors de la mise à jour de la localisation : $e');
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
