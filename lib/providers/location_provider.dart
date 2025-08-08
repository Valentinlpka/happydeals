import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:happy/providers/users_provider.dart';

class LocationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double? _latitude;
  double? _longitude;
  String _address = '';
  double _radius = 15.0;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _frenchCities = [];

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get address => _address;
  double get radius => _radius;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLocation => _latitude != null && _longitude != null;
  bool get hasError => _error != null && _error!.isNotEmpty;

  /// Initialise la localisation en utilisant les données du profil utilisateur
  Future<void> initializeLocation(UserModel userModel) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Charger les villes françaises
      await _loadFrenchCities();
            // Si l'utilisateur a une ville et un code postal, essayer de géocoder
      if (userModel.city.isNotEmpty && userModel.zipCode.isNotEmpty) {
        try {
          final addresses = await geocoding
              .locationFromAddress('${userModel.city}, ${userModel.zipCode}');

          if (addresses.isNotEmpty) {
            _updateLocation(
              latitude: addresses.first.latitude,
              longitude: addresses.first.longitude,
              address: '${userModel.city}, ${userModel.zipCode}',
            );
            debugPrint('Géocodage réussi: ${addresses.first.latitude}, ${addresses.first.longitude}');
            return;
          }
        } catch (e) {
          debugPrint('Erreur de géocodage: $e');
        }
      }
      
      // Si l'utilisateur a une localisation enregistrée, l'utiliser
      if (userModel.latitude != 0.0 && userModel.longitude != 0.0) {
        // Trouver la ville française la plus proche
        final nearestCity = _findNearestCity(userModel.latitude, userModel.longitude);
        
        if (nearestCity != null) {
          final cityName = nearestCity['label'] as String;
          final zipCode = nearestCity['zip_code'] as String;
          final address = '$cityName ($zipCode)';
          
          _updateLocation(
            latitude: userModel.latitude,
            longitude: userModel.longitude,
            address: address,
          );
          debugPrint('Utilisation de la localisation du profil avec ville française: $address');
          return;
        }
      }



      // Si aucune localisation n'est disponible, ne pas essayer la géolocalisation GPS automatiquement
      // L'utilisateur devra utiliser le bouton "Utiliser ma localisation" dans l'interface
      debugPrint('Aucune localisation disponible, l\'utilisateur devra la définir manuellement');
      _setLoading(false);
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation de la localisation: $e');
      _setError('Erreur lors de l\'initialisation de la localisation: $e');
    }
  }

  /// Obtient la localisation actuelle de l'utilisateur (appelé explicitement par l'utilisateur)
  Future<void> useCurrentLocation() async {
    _setLoading(true);
    _clearError();
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Veuillez activer les services de localisation');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Les permissions de localisation sont requises');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('Les permissions de localisation sont définitivement refusées');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      // Charger les villes françaises si pas encore fait
      await _loadFrenchCities();
      
      // Trouver la ville française la plus proche
      final nearestCity = _findNearestCity(position.latitude, position.longitude);
      
      if (nearestCity != null) {
        final cityName = nearestCity['label'] as String;
        final zipCode = nearestCity['zip_code'] as String;
        final address = '$cityName ($zipCode)';
        
        _updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
        );
        debugPrint('Utilisation de la localisation actuelle avec ville française: $address');
      } else {
        // Fallback vers le géocodage inverse si aucune ville française n'est trouvée
        _updateLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        await _reverseGeocode(position.latitude, position.longitude);
        debugPrint('Utilisation de la localisation actuelle avec géocodage inverse: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      debugPrint('Erreur de localisation: $e');
      _setError('Erreur lors de la récupération de la localisation: $e');
    }
  }

  /// Obtient la localisation actuelle de l'utilisateur (méthode privée)
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setError('Veuillez activer les services de localisation');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setError('Les permissions de localisation sont requises');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setError('Les permissions de localisation sont définitivement refusées');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      _updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      // Géocoder l'adresse à partir des coordonnées
      await _reverseGeocode(position.latitude, position.longitude);
      
      debugPrint('Utilisation de la localisation actuelle: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Erreur de localisation: $e');
      _setError('Erreur lors de la récupération de la localisation: $e');
    }
  }

  /// Met à jour la localisation avec une nouvelle adresse
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required String address,
    double radius = 15.0,
  }) async {
    _updateLocation(
      latitude: latitude,
      longitude: longitude,
      address: address,
      radius: radius,
    );

    // Mettre à jour la localisation dans le profil utilisateur
    await _updateUserLocation(latitude, longitude, address);
  }

  /// Met à jour la localisation dans Firestore
  Future<void> _updateUserLocation(double latitude, double longitude, String address) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Extraire la ville et le code postal de l'adresse
      String city = '';
      String zipCode = '';
      
      if (address.isNotEmpty) {
        // Gérer le format "Ville (CodePostal)"
        if (address.contains('(') && address.contains(')')) {
          final parts = address.split('(');
          if (parts.length >= 2) {
            city = parts[0].trim();
            zipCode = parts[1].replaceAll(')', '').trim();
          }
        } else {
          // Gérer le format "Ville, CodePostal"
          final parts = address.split(',');
          if (parts.length >= 2) {
            city = parts[0].trim();
            zipCode = parts[1].trim();
          } else {
            // Si pas de virgule, traiter comme une ville
            city = address.trim();
          }
        }
      }

      await _firestore.collection('users').doc(userId).update({
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'zipCode': zipCode,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Erreur lors de la mise à jour de la localisation: $e');
    }
  }

  /// Géocode une adresse en coordonnées
  Future<void> geocodeAddress(String address) async {
    _setLoading(true);
    _clearError();
    
    try {
      final addresses = await geocoding.locationFromAddress(address);
      if (addresses.isNotEmpty) {
        _updateLocation(
          latitude: addresses.first.latitude,
          longitude: addresses.first.longitude,
          address: address,
        );
        
        // Mettre à jour la localisation dans le profil utilisateur
        await _updateUserLocation(addresses.first.latitude, addresses.first.longitude, address);
      } else {
        _setError('Adresse non trouvée');
      }
    } catch (e) {
      debugPrint('Erreur de géocodage: $e');
      _setError('Erreur lors du géocodage de l\'adresse: $e');
    }
  }

  /// Géocode inverse pour obtenir l'adresse à partir des coordonnées
  Future<void> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final locality = placemark.locality?.trim() ?? '';
        final postalCode = placemark.postalCode?.trim() ?? '';
        final subLocality = placemark.subLocality?.trim() ?? '';
        final administrativeArea = placemark.administrativeArea?.trim() ?? '';
        
        // Construire l'adresse de manière plus robuste
        String address = '';
        
        if (locality.isNotEmpty && postalCode.isNotEmpty) {
          address = '$locality ($postalCode)';
        } else if (locality.isNotEmpty) {
          address = locality;
        } else if (subLocality.isNotEmpty && postalCode.isNotEmpty) {
          address = '$subLocality ($postalCode)';
        } else if (subLocality.isNotEmpty) {
          address = subLocality;
        } else if (administrativeArea.isNotEmpty && postalCode.isNotEmpty) {
          address = '$administrativeArea ($postalCode)';
        } else if (administrativeArea.isNotEmpty) {
          address = administrativeArea;
        } else if (postalCode.isNotEmpty) {
          address = 'Code postal: $postalCode';
        } else {
          // Si aucune information n'est disponible, utiliser les coordonnées
          address = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
        }
        
        _address = address;
        Future.microtask(() => notifyListeners());
      } else {
        _address = 'Position actuelle';
        Future.microtask(() => notifyListeners());
      }
    } catch (e) {
      debugPrint('Erreur de géocodage inverse: $e');
      _address = 'Position actuelle';
      Future.microtask(() => notifyListeners());
    }
  }

  /// Met à jour le rayon de recherche
  void updateRadius(double radius) {
    _radius = radius;
    notifyListeners();
  }

  /// Efface la localisation
  void clearLocation() {
    _latitude = null;
    _longitude = null;
    _address = '';
    _clearError();
  }

  /// Calcule la distance entre deux points
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Vérifie si un point est dans le rayon de recherche
  bool isWithinRadius(double targetLat, double targetLng) {
    if (_latitude == null || _longitude == null) return true;
    
    final distance = calculateDistance(
      _latitude!,
      _longitude!,
      targetLat,
      targetLng,
    );
    
    return distance <= (_radius * 1000); // Convertir en mètres
  }

  /// Méthodes privées pour la gestion de l'état
  void _updateLocation({
    double? latitude,
    double? longitude,
    String? address,
    double? radius,
  }) {
    if (latitude != null) _latitude = latitude;
    if (longitude != null) _longitude = longitude;
    if (address != null) _address = address;
    if (radius != null) _radius = radius;
    _isLoading = false;
    _error = null;
    Future.microtask(() => notifyListeners());
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    Future.microtask(() => notifyListeners());
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    Future.microtask(() => notifyListeners());
  }

  void _clearError() {
    _error = null;
    Future.microtask(() => notifyListeners());
  }

  /// Charge les villes françaises depuis le fichier JSON
  Future<void> _loadFrenchCities() async {
    if (_frenchCities.isNotEmpty) return; // Déjà chargé
    
    try {
      final String jsonString = await rootBundle.loadString('assets/french_cities.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      _frenchCities = List<Map<String, dynamic>>.from(jsonData['cities']);
      debugPrint('Villes françaises chargées: ${_frenchCities.length}');
    } catch (e) {
      debugPrint('Erreur lors du chargement des villes françaises: $e');
    }
  }

  /// Trouve la ville française la plus proche des coordonnées données
  Map<String, dynamic>? _findNearestCity(double latitude, double longitude) {
    if (_frenchCities.isEmpty) return null;
    
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestCity;
    
    for (var city in _frenchCities) {
      try {
        final cityLat = double.parse(city['latitude'].toString().trim().replaceAll(',', '.'));
        final cityLng = double.parse(city['longitude'].toString().trim().replaceAll(',', '.'));
        
        final distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          cityLat,
          cityLng,
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestCity = city;
        }
      } catch (e) {
        debugPrint('Erreur lors du calcul de distance pour ${city['label']}: $e');
      }
    }
    
    if (nearestCity != null) {
      debugPrint('Ville la plus proche trouvée: ${nearestCity['label']} à ${minDistance.toStringAsFixed(2)} mètres');
    }
    
    return nearestCity;
  }
} 