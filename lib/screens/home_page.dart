import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/widgets/postwidget.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final String currentUserId =
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  Position? _currentPosition;
  String _currentAddress = "Localisation en cours...";
  double _selectedRadius = 10.0;
  final TextEditingController _searchController = TextEditingController();

  final PagingController<DocumentSnapshot?, Post> _pagingController =
      PagingController(firstPageKey: null);

  static const _pageSize = 10;

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pagingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _currentAddress = "Services de localisation désactivés");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _currentAddress = "Permission de localisation refusée");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _currentAddress =
          "Permissions de localisation refusées définitivement");
      return;
    }

    _getCurrentLocation();
  }

  Future<void> _saveLocation(String address, Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedAddress', address);
    await prefs.setDouble('savedLat', position.latitude);
    await prefs.setDouble('savedLng', position.longitude);
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        _currentAddress = placemarks.isNotEmpty
            ? "${placemarks[0].locality}, ${placemarks[0].country}"
            : "Adresse inconnue";
        _searchController.text = _currentAddress;
      });
      _saveLocation(_currentAddress, position);
      _pagingController.refresh();
    } catch (e) {
      print("Erreur de localisation: $e");
      setState(() => _currentAddress = "Impossible d'obtenir la localisation");
    }
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentAddress =
          prefs.getString('savedAddress') ?? "Localisation en cours...";
      final savedLat = prefs.getDouble('savedLat');
      final savedLng = prefs.getDouble('savedLng');
      if (savedLat != null && savedLng != null) {
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
        _searchController.text = _currentAddress;
      }
    });
    if (_currentPosition == null) {
      _initializeLocation();
    } else {
      _pagingController.refresh();
    }
  }

  Future<void> _fetchPage(DocumentSnapshot? pageKey) async {
    if (_isDisposed) return;
    try {
      Query query = FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (pageKey != null) {
        query = query.startAfterDocument(pageKey);
      }

      QuerySnapshot snapshot = await query.get();

      List<Post> newPosts = [];
      for (var doc in snapshot.docs) {
        Post? post = _createPostFromDocument(doc);
        if (post != null && await _isPostWithinRadius(post.companyId)) {
          newPosts.add(post);
        }
      }

      final isLastPage = newPosts.length < _pageSize;
      if (_isDisposed) return;
      if (isLastPage) {
        _pagingController.appendLastPage(newPosts);
      } else {
        final nextPageKey = snapshot.docs.last;
        _pagingController.appendPage(newPosts, nextPageKey);
      }
    } catch (error) {
      if (_isDisposed) return;
      _pagingController.error = error;
    }
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

  Future<bool> _isPostWithinRadius(String companyId) async {
    if (_currentPosition == null) return true;

    try {
      DocumentSnapshot companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(companyId)
          .get();

      if (!companyDoc.exists) return false;

      Map<String, dynamic> companyData =
          companyDoc.data() as Map<String, dynamic>;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildSearchBar(),
                    _buildRadiusSelector(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: PagedSliverList<DocumentSnapshot?, Post>(
                pagingController: _pagingController,
                builderDelegate: PagedChildBuilderDelegate<Post>(
                  noItemsFoundIndicatorBuilder: (context) {
                    return const Center(
                        child: Text(
                            textAlign: TextAlign.center,
                            'Aucun post à proximité, veuillez changer votre localisation'));
                  },
                  itemBuilder: (context, post, index) =>
                      FutureBuilder<Map<String, dynamic>>(
                    future: _getCompanyData(post.companyId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Text(
                            'Erreur de chargement des données de l\'entreprise');
                      }

                      Map<String, dynamic> companyData = snapshot.data!;

                      return PostWidget(
                        key: Key(post.id),
                        post: post,
                        companyCategorie: companyData['categorie'] ?? '',
                        companyName: companyData['name'] ?? '',
                        companyLogo: companyData['logo'] ?? '',
                        currentUserId: currentUserId,
                        onView: () {
                          // Logique d'affichage
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Ajoutez cette méthode pour gérer le rafraîchissement
  Future<void> _handleRefresh() async {
    _pagingController.refresh();
    await _getCurrentLocation();
  }

  Widget _buildHeader() {
    return Consumer<UserModel>(
      builder: (context, usersProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(usersProvider.profileUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Salut ${usersProvider.firstName}!",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      usersProvider.dailyQuote,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: _searchController,
        googleAPIKey: "AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc",
        inputDecoration: const InputDecoration(
          hintText: "Rechercher une ville",
          prefixIcon: Icon(Icons.location_on),
          border: InputBorder.none,
        ),
        debounceTime: 800,
        countries: const ["fr"],
        isLatLngRequired: true,
        getPlaceDetailWithLatLng: (Prediction prediction) {
          _updateLocationFromPrediction(prediction);
        },
        itemClick: (Prediction prediction) {
          _searchController.text = prediction.description ?? "";
          _searchController.selection = TextSelection.fromPosition(
              TextPosition(offset: _searchController.text.length));
        },
      ),
    );
  }

  void _updateLocationFromPrediction(Prediction prediction) async {
    if (prediction.lat != null && prediction.lng != null) {
      Position newPosition = Position(
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
      setState(() {
        _currentPosition = newPosition;
        _currentAddress = prediction.description ?? "";
        _searchController.text = _currentAddress;
      });
      _saveLocation(_currentAddress, newPosition);
      _pagingController.refresh();
    } else {
      print("Erreur: Latitude ou longitude manquante dans la prédiction");
    }
  }

  Widget _buildRadiusSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Rayon: ", style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<double>(
            value: _selectedRadius,
            items: [5.0, 10.0, 15.0, 20.0, 50.0].map((double value) {
              return DropdownMenuItem<double>(
                  value: value, child: Text('$value km'));
            }).toList(),
            onChanged: (newValue) {
              setState(() => _selectedRadius = newValue!);
              _pagingController.refresh();
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getCompanyData(String companyId) async {
    DocumentSnapshot companyDoc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();

    return companyDoc.data() as Map<String, dynamic>;
  }
}
