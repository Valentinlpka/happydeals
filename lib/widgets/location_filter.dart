import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  static const String mapboxAccessToken =
      'pk.eyJ1IjoiaGFwcHlkZWFscyIsImEiOiJjbHo3ZHA5NDYwN2hyMnFzNTdiMWd2Zm92In0.1nmT5Fumjq16InZ3dmG9zQ';

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

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Erreur de localisation: $e');
    }
  }

  Future<List<dynamic>> _getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$input.json'
          '?access_token=$mapboxAccessToken'
          '&country=fr'
          '&types=place,address');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['features']
            .map((feature) => {
                  'place_id': feature['id'],
                  'description': feature['place_name'],
                  'coordinates': feature['center'],
                })
            .toList();
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'autocomplétion: $e');
    }
    return [];
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
    if (_currentPosition != null) {
      try {
        final url = Uri.parse(
            'https://api.mapbox.com/geocoding/v5/mapbox.places/${_currentPosition!.longitude},${_currentPosition!.latitude}.json'
            '?access_token=$mapboxAccessToken'
            '&language=fr');

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['features'].isNotEmpty) {
            final address = data['features'][0]['place_name'];
            _handleLocationSelection(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              address,
            );
          }
        }
      } catch (e) {
        debugPrint('Erreur lors de la géocodification inverse: $e');
        _handleLocationSelection(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          'Ma position actuelle',
        );
      }
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
