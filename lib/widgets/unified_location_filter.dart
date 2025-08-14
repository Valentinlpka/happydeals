import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:provider/provider.dart';

class UnifiedLocationFilter extends StatefulWidget {
  final VoidCallback? onLocationChanged;

  const UnifiedLocationFilter({
    super.key,
    this.onLocationChanged,
  });

  static Future<void> show({
    required BuildContext context,
    VoidCallback? onLocationChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: UnifiedLocationFilter(
              onLocationChanged: onLocationChanged,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<UnifiedLocationFilter> createState() => _UnifiedLocationFilterState();
}

class _UnifiedLocationFilterState extends State<UnifiedLocationFilter>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  List<dynamic> _predictions = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _cities = [];
  final List<double> _radiusOptions = [5, 10, 15, 20, 50, 100];

  @override
  void initState() {
    super.initState();
    _loadCities();
    _initializeCurrentLocation();

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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _initializeCurrentLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locationProvider.hasLocation) {
        setState(() {
          _searchController.text = locationProvider.address;
        });
      }
    });
  }

  Future<void> _loadCities() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/french_cities.json');
      final data = json.decode(jsonString);

      // Filtrer les villes avec des coordonnées valides dès le chargement
      final List<Map<String, dynamic>> allCities = List<Map<String, dynamic>>.from(data['cities']);
      final List<Map<String, dynamic>> validCities = allCities.where((city) {
        try {
          final latStr = city['latitude'].toString().trim().replaceAll(',', '.');
          final lngStr = city['longitude'].toString().trim().replaceAll(',', '.');

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
              'description': '${_capitalizeWords(city['label'])} (${city['zip_code']})',
              'coordinates': [
                double.parse(city['longitude']),
                double.parse(city['latitude'])
              ],
            })
        .toList();
  }

  void _selectCity(Map<String, dynamic> city) async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    try {
      final address = '${_capitalizeWords(city['label'])} (${city['zip_code']})';
      final latitude = double.parse(city['latitude'].toString().trim().replaceAll(',', '.'));
      final longitude = double.parse(city['longitude'].toString().trim().replaceAll(',', '.'));
      
      // Mettre à jour la localisation de manière persistante
      await locationProvider.updateLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
        radius: locationProvider.radius, // Conserver le rayon actuel
      );
      
      // Mettre à jour le champ de recherche pour afficher la ville sélectionnée
      setState(() {
        _searchController.text = address;
        _predictions = [];
      });
      
      debugPrint('Ville sélectionnée et sauvegardée: $address');
      debugPrint('Coordonnées: $latitude, $longitude');
      
      // Ne pas fermer le bottom sheet, laisser l'utilisateur ajuster le rayon
    } catch (e) {
      debugPrint('Erreur lors de la sélection de la ville: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de la ville: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _useCurrentLocation() async {
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.useCurrentLocation();
      
      if (locationProvider.hasLocation && !locationProvider.hasError) {
        // Mettre à jour le champ de recherche avec l'adresse obtenue
        setState(() {
          _searchController.text = locationProvider.address;
          _predictions = [];
        });
        
        debugPrint('Localisation actuelle utilisée et sauvegardée: ${locationProvider.address}');
        debugPrint('Coordonnées: ${locationProvider.latitude}, ${locationProvider.longitude}');
        
        // Ne pas fermer le bottom sheet, laisser l'utilisateur ajuster le rayon
      } else if (locationProvider.hasError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locationProvider.error!),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'utilisation de la localisation actuelle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la récupération de la localisation: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return FadeTransition(
          opacity: _animation,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
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
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Fermer',
                        style: IconButton.styleFrom(
                          foregroundColor: const Color(0xFF4B88DA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Champ de recherche avec bouton de localisation
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withAlpha(13),
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
                                  _predictions = [];
                                }
                              });
                            },
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: (value) async {
                                if (value.length > 2) {
                                  final predictions = await _getPlacePredictions(value);
                                  setState(() {
                                    _predictions = predictions;
                                  });
                                } else {
                                  setState(() {
                                    _predictions = [];
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'Rechercher une ville...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
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
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton de localisation
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4B88DA),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withAlpha(13),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: locationProvider.hasLocation ? _useCurrentLocation : null,
                          icon: const Icon(Icons.my_location, color: Colors.white),
                          tooltip: 'Utiliser ma position',
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_predictions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withAlpha(13),
                            spreadRadius: 1,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
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
                              _selectCity({
                                'label': prediction['description'].split(' (')[0],
                                'zip_code': prediction['description'].split('(')[1].split(')')[0],
                                'latitude': coordinates[1].toString(),
                                'longitude': coordinates[0].toString(),
                              });
                              _searchFocusNode.unfocus();
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
                                          color: Colors.grey.withAlpha(13),
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, color: Color(0xFF4B88DA)),
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
                        final isSelected = locationProvider.radius == radius;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: FilterChip(
                              label: Text('${radius.toInt()} km'),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                if (selected) {
                                  locationProvider.updateRadius(radius);
                                }
                              },
                              backgroundColor: Colors.grey[100],
                              selectedColor: const Color(0xFF4B88DA),
                              checkmarkColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Bouton de confirmation
                  ElevatedButton(
                    onPressed: locationProvider.hasLocation ? () {
                      Navigator.of(context).pop();
                      widget.onLocationChanged?.call();
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B88DA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirmer la sélection',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
} 