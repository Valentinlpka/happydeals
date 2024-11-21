import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
import 'package:happy/providers/localisation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final int _pageSize = 10;

  Position? _currentPosition;
  String _currentAddress = "Localisation en cours...";
  bool _isLoading = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  String? _errorMessage;

  // Getters
  Position? get currentPosition => _currentPosition;
  String get currentAddress => _currentAddress;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;
  bool get hasError => _errorMessage != null;
  String get errorMessage =>
      _errorMessage ?? "Une erreur inconnue est survenue";

  // État du feed
  final List<CombinedItem> _feedItems = [];
  List<CombinedItem> get feedItems => _feedItems;

  void _handleLocationError(String message, dynamic error) {
    print('$message: $error');
    // Vous pouvez ajouter ici une logique pour afficher un message à l'utilisateur
    // Par exemple avec un SnackBar ou un Dialog
  }

  Future<void> initializeFeed({
    required List<String> followedCompanyIds,
    required List<String> followedUserIds,
  }) async {
    try {
      _isLoading = true;
      _feedItems.clear();
      _lastDocument = null;
      _hasMoreData = true;
      notifyListeners();

      await loadNextPage(
        followedCompanyIds: followedCompanyIds,
        followedUserIds: followedUserIds,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadNextPage({
    required List<String> followedCompanyIds,
    required List<String> followedUserIds,
  }) async {
    if (!_hasMoreData || _isLoading) return;

    try {
      _isLoading = true;
      notifyListeners();

      // Création de la requête de base
      Query baseQuery =
          _firestore.collection('posts').orderBy('timestamp', descending: true);

      // Ajout des filtres pour les entreprises et utilisateurs suivis
      baseQuery = baseQuery.where('creatorId',
          whereIn: [...followedCompanyIds, ...followedUserIds]);

      // Pagination
      if (_lastDocument != null) {
        baseQuery = baseQuery.startAfterDocument(_lastDocument!);
      }

      baseQuery = baseQuery.limit(_pageSize);

      // Exécution de la requête
      final QuerySnapshot querySnapshot = await baseQuery.get();

      if (querySnapshot.docs.isEmpty) {
        _hasMoreData = false;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Traitement des résultats
      List<CombinedItem> newItems =
          await Future.wait(querySnapshot.docs.map((doc) async {
        final postData = doc.data() as Map<String, dynamic>;
        final creatorId = postData['creatorId'] as String;

        // Récupération des données du créateur (entreprise ou utilisateur)
        final creatorDoc = await _firestore
            .collection(
                followedCompanyIds.contains(creatorId) ? 'companys' : 'users')
            .doc(creatorId)
            .get();

        return CombinedItem({
          'post': _createPostFromDocument(doc),
          'creator': creatorDoc.data(),
          'creatorType':
              followedCompanyIds.contains(creatorId) ? 'company' : 'user',
        }, postData['timestamp'].toDate(), 'post');
      }));

      _feedItems.addAll(newItems);
      _lastDocument = querySnapshot.docs.last;
      _hasMoreData = querySnapshot.docs.length == _pageSize;
    } catch (e) {
      print('Erreur lors du chargement du feed: $e');
      _errorMessage = "Erreur lors du chargement du contenu";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFeed({
    required List<String> followedCompanyIds,
    required List<String> followedUserIds,
  }) async {
    _feedItems.clear();
    _lastDocument = null;
    _hasMoreData = true;
    _errorMessage = null;
    notifyListeners();

    await loadNextPage(
      followedCompanyIds: followedCompanyIds,
      followedUserIds: followedUserIds,
    );
  }

  // Méthodes helper existantes (_createPostFromDocument, etc.)
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
        case 'product': // Ajout du case pour les produits
          return ProductPost.fromDocument(doc);
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
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

  // Méthodes de gestion de la localisation
  void updateLocation(Position position) {
    _currentPosition = position;
    notifyListeners();
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

      Future<void> saveLocation(String address, Position position) async {
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

      await saveLocation(
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
}
