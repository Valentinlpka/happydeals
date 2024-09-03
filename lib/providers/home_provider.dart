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
      return [];
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

  Future<List<CombinedItem>> loadFollowingData(
      List<String> likedCompanies, List<String> followedUsers) async {
    if (likedCompanies.isEmpty && followedUsers.isEmpty) {
      return [];
    }

    final posts =
        await fetchFollowingPostsWithCompanyData(likedCompanies, followedUsers);
    final companies = await fetchFollowingCompanies(likedCompanies);

    final combinedItems = [
      ...posts.map((postData) =>
          CombinedItem(postData, postData['post'].timestamp, 'post')),
      ...companies.map(
          (company) => CombinedItem(company, company.createdAt, 'company')),
    ];

    combinedItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return combinedItems;
  }

  Future<List<Map<String, dynamic>>> fetchFollowingPostsWithCompanyData(
      List<String> likedCompanies, List<String> followedUsers) async {
    List<Map<String, dynamic>> postsWithCompanyData = [];

    // Requête pour les posts des entreprises aimées
    if (likedCompanies.isNotEmpty) {
      final companyPostsQuery = await _firestore
          .collection('posts')
          .where('companyId', whereIn: likedCompanies)
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in companyPostsQuery.docs) {
        await _processPost(doc, postsWithCompanyData);
      }
    }

    // Requête pour les posts partagés par les utilisateurs suivis
    if (followedUsers.isNotEmpty) {
      final sharedPostsQuery = await _firestore
          .collection('posts')
          .where('sharedBy', whereIn: followedUsers)
          .orderBy('timestamp', descending: true)
          .get();

      for (var doc in sharedPostsQuery.docs) {
        await _processPost(doc, postsWithCompanyData);
      }
    }

    // Trier tous les posts par timestamp
    postsWithCompanyData.sort((a, b) =>
        (b['post'] as Post).timestamp.compareTo((a['post'] as Post).timestamp));

    return postsWithCompanyData;
  }

  Future<void> _processPost(DocumentSnapshot doc,
      List<Map<String, dynamic>> postsWithCompanyData) async {
    try {
      final post = Post.fromDocument(doc);
      Map<String, dynamic> postData = {'post': post};

      // Récupérer les données de l'entreprise
      final companyDoc =
          await _firestore.collection('companys').doc(post.companyId).get();
      if (companyDoc.exists) {
        postData['company'] = companyDoc.data();
      }

      // Si c'est un post partagé, récupérer le post original
      if (post is SharedPost) {
        final originalPostDoc =
            await _firestore.collection('posts').doc(post.originalPostId).get();
        if (originalPostDoc.exists) {
          postData['originalPost'] = Post.fromDocument(originalPostDoc);
        }
      }

      // Récupérer les données de l'utilisateur qui a partagé (si applicable)
      if (post.sharedBy != null) {
        final userDoc =
            await _firestore.collection('users').doc(post.sharedBy).get();
        if (userDoc.exists) {
          postData['sharedByUser'] = userDoc.data();
        }
      }

      postsWithCompanyData.add(postData);
    } catch (e) {
      print('Erreur lors du traitement du post ${doc.id}: $e');
    }
  }

  Future<List<Company>> fetchFollowingCompanies(
      List<String> likedCompanies) async {
    final companiesQuery = _firestore
        .collection('companys')
        .where(FieldPath.documentId, whereIn: likedCompanies)
        .orderBy('createdAt', descending: true);
    final companiesSnapshot = await companiesQuery.get();

    return companiesSnapshot.docs
        .map((doc) => Company.fromDocument(doc))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllPostsWithCompanyData() async {
    final postsQuery =
        _firestore.collection('posts').orderBy('timestamp', descending: true);
    final postsSnapshot = await postsQuery.get();

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
          }
        }
      } catch (e) {
        print('Error processing post: $e');
      }
    }

    return postsWithCompanyData;
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
        default:
          print('Type de post non supporté: $type pour le document ${doc.id}');
          return null;
      }
    } catch (e) {
      print(
          'Erreur lors de la création du post à partir du document ${doc.id}: $e');
      print('Données du document: ${doc.data()}');
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
        print("Erreur lors de l'obtention de la position: $e");
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
      print("Erreur d'initialisation de la localisation: $e");
      _handleLocationError("Erreur d'initialisation de la localisation", e);
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
    print("$message: $error");
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
    } catch (e) {
      print("Erreur lors de la sauvegarde de la localisation: $e");
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

    List<Map<String, dynamic>> postsWithCompanyData = [];

    for (var postDoc in postsSnapshot.docs) {
      try {
        final post = _createPostFromDocument(postDoc);
        if (post != null) {
          Map<String, dynamic> postData = {'post': post};

          if (post.sharedBy != null) {
            // C'est un post partagé, récupérez les informations de l'utilisateur qui l'a partagé
            final userDoc =
                await _firestore.collection('users').doc(post.sharedBy).get();
            postData['sharedByUser'] = userDoc.data();
          }

          final companyDoc =
              await _firestore.collection('companys').doc(post.companyId).get();
          final companyData = companyDoc.data() as Map<String, dynamic>;

          if (await _isPostWithinRadius(post.companyId, companyData)) {
            postData['company'] = companyData;
            postsWithCompanyData.add(postData);
          }
        }
      } catch (e) {
        print('Error processing post: $e');
      }
    }

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
