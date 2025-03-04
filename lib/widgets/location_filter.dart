import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationFilterBottomSheet extends StatefulWidget {
  final Function(
          double? latitude, double? longitude, double radius, String address)
      onLocationSelected;
  final double? currentLat;
  final double? currentLng;
  final double currentRadius;
  final String currentAddress;

  const LocationFilterBottomSheet({
    super.key,
    required this.onLocationSelected,
    this.currentLat,
    this.currentLng,
    required this.currentRadius,
    required this.currentAddress,
  });

  static Future<void> show({
    required BuildContext context,
    required Function(
            double? latitude, double? longitude, double radius, String address)
        onLocationSelected,
    double? currentLat,
    double? currentLng,
    required double currentRadius,
    required String currentAddress,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: LocationFilterBottomSheet(
            onLocationSelected: onLocationSelected,
            currentLat: currentLat,
            currentLng: currentLng,
            currentRadius: currentRadius,
            currentAddress: currentAddress,
          ),
        ),
      ),
    );
  }

  @override
  _LocationFilterBottomSheetState createState() =>
      _LocationFilterBottomSheetState();
}

class _LocationFilterBottomSheetState extends State<LocationFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  Position? _currentPosition;
  String _selectedAddress = '';
  double _selectedRadius = 5.0;
  final List<double> _radiusOptions = [5, 10, 15, 20, 50, 100];
  List<dynamic> _predictions = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  double? _selectedLat;
  double? _selectedLng;
  bool _isSearching = false;
  List<Map<String, dynamic>> _cities = [];

  @override
  void initState() {
    super.initState();
    _selectedRadius = widget.currentRadius;
    _selectedAddress = widget.currentAddress;
    _selectedLat = widget.currentLat;
    _selectedLng = widget.currentLng;
    _searchController.text =
        widget.currentAddress.isNotEmpty ? widget.currentAddress : '';
    _getCurrentLocation();
    _loadCities();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/french_cities.json');
      final data = json.decode(jsonString);

      // Filtrer les villes avec des coordonnées valides dès le chargement
      final List<Map<String, dynamic>> allCities =
          List<Map<String, dynamic>>.from(data['cities']);
      final List<Map<String, dynamic>> validCities = allCities.where((city) {
        try {
          final latStr =
              city['latitude'].toString().trim().replaceAll(',', '.');
          final lngStr =
              city['longitude'].toString().trim().replaceAll(',', '.');

          final lat = double.parse(latStr);
          final lng = double.parse(lngStr);

          // Vérifier si les coordonnées sont dans des limites raisonnables pour la France métropolitaine
          return lat >= 41.0 && lat <= 52.0 && lng >= -5.0 && lng <= 10.0;
        } catch (e) {
          return false;
        }
      }).toList();

      setState(() {
        _cities = validCities;
      });

      debugPrint('Nombre de villes chargées: ${validCities.length}');
    } catch (e) {
      debugPrint('Erreur lors du chargement des villes: $e');
    }
  }

  String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<List<dynamic>> _getPlacePredictions(String input) async {
    if (input.length < 2) return [];

    final normalizedInput = input.toLowerCase().trim();
    return _cities
        .where((city) =>
            city['label'].toString().toLowerCase().contains(normalizedInput) ||
            city['zip_code'].toString().contains(normalizedInput))
        .take(5)
        .map((city) => {
              'place_id': city['insee_code'],
              'description':
                  '${_capitalizeWords(city['label'])} (${city['zip_code']})',
              'coordinates': [
                double.parse(city['longitude']),
                double.parse(city['latitude'])
              ],
            })
        .toList();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Les services de localisation sont désactivés');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Permission de localisation refusée');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Permission de localisation refusée définitivement');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
          'Position obtenue: ${position.latitude}, ${position.longitude}');
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la position: $e');
    }
  }

  void _handleLocationSelection(double lat, double lng, String address) {
    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
      _selectedAddress = address;
      _searchController.text = address;
      _predictions = [];
    });
  }

  void _resetFilter() {
    setState(() {
      _selectedLat = null;
      _selectedLng = null;
      _selectedAddress = '';
      _searchController.clear();
      _selectedRadius = 5.0;
    });
    widget.onLocationSelected(null, null, _selectedRadius, '');
    Navigator.pop(context);
  }

  void _applyFilter() {
    widget.onLocationSelected(
        _selectedLat, _selectedLng, _selectedRadius, _selectedAddress);
    Navigator.pop(context);
  }

  void _useCurrentLocation() async {
    if (_currentPosition == null) {
      debugPrint('Position actuelle non disponible');
      await _getCurrentLocation();
      if (_currentPosition == null) {
        return;
      }
    }

    try {
      debugPrint('Recherche de la ville la plus proche...');
      double minDistance = double.infinity;
      Map<String, dynamic>? nearestCity;

      // Optimisation : utiliser les coordonnées déjà validées
      for (var city in _cities) {
        final latStr = city['latitude'].toString().trim().replaceAll(',', '.');
        final lngStr = city['longitude'].toString().trim().replaceAll(',', '.');

        final cityLat = double.parse(latStr);
        final cityLng = double.parse(lngStr);

        double distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          cityLat,
          cityLng,
        );

        // Ne logger que les villes vraiment proches (moins de 10km) pour réduire le bruit
        if (distance < minDistance) {
          minDistance = distance;
          nearestCity = city;
          if (distance < 10000) {
            debugPrint(
                'Nouvelle ville proche trouvée: ${city['label']} à ${distance.toStringAsFixed(2)} mètres');
          }
        }
      }

      if (nearestCity != null) {
        debugPrint(
            'Ville la plus proche trouvée: ${nearestCity['label']} à ${minDistance.toStringAsFixed(2)} mètres');

        setState(() {
          _selectedLat = double.parse(
              nearestCity!['latitude'].toString().trim().replaceAll(',', '.'));
          _selectedLng = double.parse(
              nearestCity['longitude'].toString().trim().replaceAll(',', '.'));
          _selectedAddress =
              '${_capitalizeWords(nearestCity['label'])} (${nearestCity['zip_code']})';
          _searchController.text = _selectedAddress;
          _predictions = [];
          _isSearching = false;
        });
      } else {
        debugPrint('Aucune ville proche trouvée');
      }
    } catch (e) {
      debugPrint('Erreur lors de la recherche de la ville la plus proche: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de poignée
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // En-tête
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtre de localisation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                IconButton(
                  onPressed: _resetFilter,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Réinitialiser',
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF4B88DA),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Champ de recherche amélioré
            Container(
              constraints: BoxConstraints(
                maxHeight: _isSearching ? 250 : 60,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        setState(() {
                          if (!hasFocus && _predictions.isEmpty) {
                            _isSearching = false;
                          }
                        });
                      },
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Rechercher une ville...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon:
                              Icon(Icons.search, color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _predictions = [];
                                      _selectedAddress = '';
                                      _selectedLat = null;
                                      _selectedLng = null;
                                      _isSearching = false;
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) async {
                          if (value.length > 2) {
                            final predictions =
                                await _getPlacePredictions(value);
                            setState(() {
                              _predictions = predictions;
                              _isSearching = predictions.isNotEmpty;
                            });
                          } else {
                            setState(() {
                              _predictions = [];
                              _isSearching = false;
                            });
                          }
                        },
                        onTap: () {
                          setState(() {
                            _isSearching = _predictions.isNotEmpty;
                          });
                        },
                      ),
                    ),
                  ),
                  if (_predictions.isNotEmpty)
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _predictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _predictions[index];
                            return InkWell(
                              onTap: () {
                                final coordinates = prediction['coordinates'];
                                _handleLocationSelection(
                                  coordinates[1],
                                  coordinates[0],
                                  prediction['description'],
                                );
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _isSearching = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: index != _predictions.length - 1
                                      ? Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.withOpacity(0.1),
                                          ),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        color: Color(0xFF4B88DA)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        prediction['description'],
                                        style: const TextStyle(fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Rayon de recherche
            const Text(
              'Rayon de recherche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _radiusOptions.length,
                itemBuilder: (context, index) {
                  final radius = _radiusOptions[index];
                  final isSelected = _selectedRadius == radius;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: FilterChip(
                        label: Text('${radius.toInt()} km'),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          if (selected) {
                            setState(() {
                              _selectedRadius = radius;
                            });
                          }
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: const Color(0xFF4B88DA),
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Bouton de position actuelle
            ElevatedButton.icon(
              onPressed: _currentPosition != null ? _useCurrentLocation : null,
              icon: const Icon(Icons.my_location),
              label: const Text('Utiliser ma position'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B88DA),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),
            // Bouton d'application
            ElevatedButton(
              onPressed: _applyFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B88DA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Appliquer le filtre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
