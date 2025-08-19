import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/providers/location_provider.dart';

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
  
  bool _isLoading = false;
  String _searchQuery = '';
  RestaurantFilters _filters = RestaurantFilters();
  RestaurantSortBy _sortBy = RestaurantSortBy.distance;
  String? _error;

  // Getters
  List<Restaurant> get restaurants => _filteredRestaurants;
  List<String> get availableCategories => _availableCategories;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  RestaurantFilters get filters => _filters;
  RestaurantSortBy get sortBy => _sortBy;
  String? get error => _error;

  // Initialisation
  Future<void> initialize() async {
    await fetchRestaurants();
  }

  // Récupération des restaurants
  Future<void> fetchRestaurants() async {
    _setLoading(true);
    _clearError();

    try {
      final snapshot = await _firestore.collection('companys').where('categorie', isEqualTo: 'Restauration').get();
      final restaurants = <Restaurant>[];
      final categories = <String>{};

      for (var doc in snapshot.docs) {
        try {
          final restaurant = Restaurant.fromFirestore(doc);
          restaurants.add(restaurant);
          
   
          if (restaurant.subCategory.isNotEmpty) {
            categories.add(restaurant.subCategory);
          }
        } catch (e) {
          debugPrint('Erreur lors du parsing du restaurant ${doc.id}: $e');
        }
      }

      _restaurants = restaurants;
      _availableCategories = categories.toList();
      
      _applySortingAndFilters(null);
      
    } catch (e) {
      debugPrint('Erreur lors de la récupération des restaurants: $e');
      _setError('Erreur lors de la récupération des restaurants');
    } finally {
      _setLoading(false);
    }
  }

  // Calcul des distances en utilisant le LocationProvider
  void _calculateDistances(LocationProvider locationProvider) {
    if (!locationProvider.hasLocation) return;

    for (var restaurant in _restaurants) {
      final distance = _calculateDistance(
        locationProvider.latitude!,
        locationProvider.longitude!,
        restaurant.address.latitude,
        restaurant.address.longitude,
      );
      restaurant.distance = distance;
    }
  }

  // Calcul de distance entre deux points
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // en km
  }

  // Application du tri et des filtres
  void _applySortingAndFilters(LocationProvider? locationProvider) {
    var filtered = List<Restaurant>.from(_restaurants);

    // Calculer les distances si on a une localisation
    if (locationProvider != null && locationProvider.hasLocation) {
      _calculateDistances(locationProvider);
    }

    // Appliquer les filtres
    if (_filters.categories.isNotEmpty) {
      filtered = filtered.where((restaurant) {
        return _filters.categories.contains(restaurant.category) ||
               _filters.categories.contains(restaurant.subCategory);
      }).toList();
    }

    if (_filters.minRating != null) {
      filtered = filtered.where((restaurant) => 
          restaurant.rating >= _filters.minRating!).toList();
    }

    if (_filters.maxDistance != null && locationProvider?.hasLocation == true) {
      filtered = filtered.where((restaurant) => 
          restaurant.distance != null && restaurant.distance! <= _filters.maxDistance!).toList();
    }

    if (_filters.minPrice != null) {
      filtered = filtered.where((restaurant) => 
          restaurant.averageOrderValue >= _filters.minPrice!).toList();
    }

    if (_filters.maxPrice != null) {
      filtered = filtered.where((restaurant) => 
          restaurant.averageOrderValue <= _filters.maxPrice!).toList();
    }

    if (_filters.maxPreparationTime != null) {
      filtered = filtered.where((restaurant) => 
          restaurant.preparationTime <= _filters.maxPreparationTime!).toList();
    }

    if (_filters.openNow) {
      filtered = filtered.where((restaurant) => restaurant.isOpen).toList();
    }

    if (_filters.hasPromotions) {
      // Logique pour les restaurants avec promotions
      // À implémenter selon vos besoins
    }

    // Appliquer la recherche
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((restaurant) {
        return restaurant.name.toLowerCase().contains(query) ||
               restaurant.description.toLowerCase().contains(query) ||
               restaurant.category.toLowerCase().contains(query) ||
               restaurant.subCategory.toLowerCase().contains(query) ||
               restaurant.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    // Appliquer le tri
    switch (_sortBy) {
      case RestaurantSortBy.distance:
        if (locationProvider?.hasLocation == true) {
          filtered.sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
        }
        break;
      case RestaurantSortBy.rating:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case RestaurantSortBy.preparationTime:
        filtered.sort((a, b) => a.preparationTime.compareTo(b.preparationTime));
        break;
      case RestaurantSortBy.averagePrice:
        filtered.sort((a, b) => a.averageOrderValue.compareTo(b.averageOrderValue));
        break;
      case RestaurantSortBy.popularity:
        filtered.sort((a, b) => b.numberOfReviews.compareTo(a.numberOfReviews));
        break;
    }

    _filteredRestaurants = filtered;
    notifyListeners();
  }

  // Méthode publique pour appliquer les filtres avec le LocationProvider
  void applyFiltersWithLocation(LocationProvider locationProvider) {
    _applySortingAndFilters(locationProvider);
  }

  // Recherche
  void search(String query) {
    _searchQuery = query;
    _applySortingAndFilters(null);
  }

  // Mise à jour des filtres
  void updateFilters(RestaurantFilters filters) {
    _filters = filters;
    _applySortingAndFilters(null);
  }

  // Mise à jour du tri
  void updateSorting(RestaurantSortBy sortBy) {
    _sortBy = sortBy;
    _applySortingAndFilters(null);
  }

  // Effacer les filtres
  void clearFilters() {
    _filters = RestaurantFilters();
    _applySortingAndFilters(null);
  }

  // Actualiser
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

  // Méthodes privées
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }
} 