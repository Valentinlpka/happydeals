import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/restaurant.dart';

enum RestaurantSortBy {
  distance,
  rating,
  preparationTime,
  averagePrice,
  popularity,
}

class RestaurantFilters {
  final List<String> categories;
  final double? minRating;
  final double? maxDistance;
  final bool openNow;
  final bool hasPromotions;
  final double? minPrice;
  final double? maxPrice;
  final int? maxPreparationTime;

  RestaurantFilters({
    this.categories = const [],
    this.minRating,
    this.maxDistance,
    this.openNow = false,
    this.hasPromotions = false,
    this.minPrice,
    this.maxPrice,
    this.maxPreparationTime,
  });

  RestaurantFilters copyWith({
    List<String>? categories,
    double? minRating,
    double? maxDistance,
    bool? openNow,
    bool? hasPromotions,
    double? minPrice,
    double? maxPrice,
    int? maxPreparationTime,
  }) {
    return RestaurantFilters(
      categories: categories ?? this.categories,
      minRating: minRating ?? this.minRating,
      maxDistance: maxDistance ?? this.maxDistance,
      openNow: openNow ?? this.openNow,
      hasPromotions: hasPromotions ?? this.hasPromotions,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      maxPreparationTime: maxPreparationTime ?? this.maxPreparationTime,
    );
  }

  bool get hasActiveFilters {
    return categories.isNotEmpty ||
        minRating != null ||
        maxDistance != null ||
        openNow ||
        hasPromotions ||
        minPrice != null ||
        maxPrice != null ||
        maxPreparationTime != null;
  }
}

class RestaurantProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Restaurant> _restaurants = [];
  List<Restaurant> _filteredRestaurants = [];
  List<String> _availableCategories = [];
  Position? _userPosition;
  
  bool _isLoading = false;
  bool _isLocationLoading = false;
  String _searchQuery = '';
  RestaurantFilters _filters = RestaurantFilters();
  RestaurantSortBy _sortBy = RestaurantSortBy.distance;
  String? _error;

  // Getters
  List<Restaurant> get restaurants => _filteredRestaurants;
  List<String> get availableCategories => _availableCategories;
  Position? get userPosition => _userPosition;
  bool get isLoading => _isLoading;
  bool get isLocationLoading => _isLocationLoading;
  String get searchQuery => _searchQuery;
  RestaurantFilters get filters => _filters;
  RestaurantSortBy get sortBy => _sortBy;
  String? get error => _error;
  bool get hasLocation => _userPosition != null;

  // Initialisation
  Future<void> initialize() async {
    await Future.wait([
      _requestLocationPermission(),
      fetchRestaurants(),
      _fetchAvailableCategories(),
    ]);
  }

  // Gestion de la localisation
  Future<void> _requestLocationPermission() async {
    _isLocationLoading = true;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Les services de localisation sont désactivés');
        _isLocationLoading = false;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Les permissions de localisation sont refusées');
          _isLocationLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Les permissions de localisation sont définitivement refusées');
        _isLocationLoading = false;
        notifyListeners();
        return;
      }

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      debugPrint('Position obtenue: ${_userPosition?.latitude}, ${_userPosition?.longitude}');
      
      // Recalculer les distances
      _calculateDistances();
      _applySortingAndFilters();
      
    } catch (e) {
      debugPrint('Erreur lors de l\'obtention de la position: $e');
      _error = 'Impossible d\'obtenir votre position';
    } finally {
      _isLocationLoading = false;
      notifyListeners();
    }
  }

  // Récupération des restaurants
  Future<void> fetchRestaurants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('companys')
          .where('categorie', isEqualTo: 'Restauration')
          .get();

      _restaurants = querySnapshot.docs
          .map((doc) => Restaurant.fromFirestore(doc))
          .toList();

      _calculateDistances();
      _applySortingAndFilters();

      _error = null;
      debugPrint('${_restaurants.length} restaurants récupérés');
    } catch (e) {
      debugPrint('Erreur lors de la récupération des restaurants: $e');
      _error = 'Impossible de charger les restaurants';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Récupération des catégories disponibles
  Future<void> _fetchAvailableCategories() async {
    try {
      final querySnapshot = await _firestore
          .collection('companys')
          .where('categorie', isEqualTo: 'Restauration')
          .get();

      final categories = <String>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final category = data['categorie'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      _availableCategories = categories.toList()..sort();
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur lors de la récupération des catégories: $e');
    }
  }

  // Calcul des distances
  void _calculateDistances() {
    if (_userPosition == null) return;

    for (final restaurant in _restaurants) {
      restaurant.distance = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        restaurant.address.latitude,
        restaurant.address.longitude,
      ) / 1000; // Convertir en kilomètres
    }
  }

  // Recherche
  void search(String query) {
    _searchQuery = query.toLowerCase();
    _applySortingAndFilters();
  }

  // Filtres
  void updateFilters(RestaurantFilters newFilters) {
    _filters = newFilters;
    _applySortingAndFilters();
  }

  void clearFilters() {
    _filters = RestaurantFilters();
    _applySortingAndFilters();
  }

  // Tri
  void updateSorting(RestaurantSortBy sortBy) {
    _sortBy = sortBy;
    _applySortingAndFilters();
  }

  // Application des filtres et du tri
  void _applySortingAndFilters() {
    var filtered = List<Restaurant>.from(_restaurants);

    // Application de la recherche
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((restaurant) {
        return restaurant.name.toLowerCase().contains(_searchQuery) ||
            restaurant.description.toLowerCase().contains(_searchQuery) ||
            restaurant.category.toLowerCase().contains(_searchQuery) ||
            restaurant.tags.any((tag) => tag.toLowerCase().contains(_searchQuery));
      }).toList();
    }

    // Application des filtres
    filtered = filtered.where((restaurant) {
      // Filtre par catégorie
      if (_filters.categories.isNotEmpty &&
          !_filters.categories.contains(restaurant.category)) {
        return false;
      }

      // Filtre par note minimale
      if (_filters.minRating != null &&
          restaurant.rating < _filters.minRating!) {
        return false;
      }

      // Filtre par distance maximale
      if (_filters.maxDistance != null &&
          restaurant.distance != null &&
          restaurant.distance! > _filters.maxDistance!) {
        return false;
      }

      // Filtre ouvert maintenant
      if (_filters.openNow && !restaurant.isOpen) {
        return false;
      }

      // Filtre prix minimum
      if (_filters.minPrice != null &&
          restaurant.averageOrderValue < _filters.minPrice!) {
        return false;
      }

      // Filtre prix maximum
      if (_filters.maxPrice != null &&
          restaurant.averageOrderValue > _filters.maxPrice!) {
        return false;
      }

      // Filtre temps de préparation maximum
      if (_filters.maxPreparationTime != null &&
          restaurant.preparationTime > _filters.maxPreparationTime!) {
        return false;
      }

      return true;
    }).toList();

    // Application du tri
    filtered.sort((a, b) {
      switch (_sortBy) {
        case RestaurantSortBy.distance:
          if (a.distance == null && b.distance == null) return 0;
          if (a.distance == null) return 1;
          if (b.distance == null) return -1;
          return a.distance!.compareTo(b.distance!);
        
        case RestaurantSortBy.rating:
          return b.rating.compareTo(a.rating);
        
        case RestaurantSortBy.preparationTime:
          return a.preparationTime.compareTo(b.preparationTime);
        
        case RestaurantSortBy.averagePrice:
          return a.averageOrderValue.compareTo(b.averageOrderValue);
        
        case RestaurantSortBy.popularity:
          return b.totalReviews.compareTo(a.totalReviews);
      }
    });

    _filteredRestaurants = filtered;
    notifyListeners();
  }

  // Actualisation
  Future<void> refresh() async {
    await fetchRestaurants();
  }

  // Récupérer un restaurant par ID
  Future<Restaurant?> getRestaurantById(String id) async {
    try {
      final doc = await _firestore.collection('companys').doc(id).get();
      if (doc.exists) {
        return Restaurant.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la récupération du restaurant $id: $e');
      return null;
    }
  }

  // Nettoyer les ressources
} 