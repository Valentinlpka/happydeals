import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  _CompaniesPageState createState() => _CompaniesPageState();
}

class CustomMarker {
  final latlong.LatLng position;
  final Widget icon;
  final VoidCallback onTap;
  final String id;
  final Company? company;

  CustomMarker({
    required this.position,
    required this.icon,
    required this.onTap,
    required this.id,
    this.company,
  });
}

class _CompaniesPageState extends State<CompaniesPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _searchQuery = '';
  String _selectedCategory = 'Toutes';
  String _selectedCity = 'Toutes';
  List<String> _categories = ['Toutes'];
  List<String> _cities = ['Toutes'];
  bool _showMap = false;
  Position? _currentPosition;
  Company? _selectedCompany;
  Set<CustomMarker> _markers = {};
  final MapController _mapController = MapController();
  bool _isBottomSheetOpen = false;
  List<dynamic> _predictions = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  static const String mapboxAccessToken =
      'pk.eyJ1IjoiaGFwcHlkZWFscyIsImEiOiJjbHo3ZHA5NDYwN2hyMnFzNTdiMWd2Zm92In0.1nmT5Fumjq16InZ3dmG9zQ';
  String _selectedAddress = '';
  double _selectedRadius = 5.0; // en km
  final List<double> _radiusOptions = [5, 10, 15, 20];
  String _sortBy = 'name'; // Nouvelle variable pour le tri
  bool _sortAscending = true; // Nouvelle variable pour l'ordre de tri

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _updateMarkers(); // Mettre à jour les marqueurs quand on change d'onglet
    });
    _loadFilters();
    _getCurrentLocation();

    // Ajoutez ces listeners pour une meilleure gestion du focus
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        setState(() {
          _predictions = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    try {
      final companiesSnapshot = await _firestore.collection('companys').get();
      final Set<String> categories = {};
      final Set<String> cities = {};

      for (var doc in companiesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('categorie')) {
          categories.add(data['categorie'] as String);
        }
        if (data.containsKey('adress') &&
            (data['adress'] as Map<String, dynamic>).containsKey('ville')) {
          final ville = data['adress']['ville'] as String;
          if (ville.isNotEmpty) {
            cities.add(ville);
          }
        }
      }

      setState(() {
        _categories = ['Toutes', ...categories];
        _cities = ['Toutes', ...cities];
      });
    } catch (e) {
      print('Erreur lors du chargement des filtres: $e');
      // Définir des valeurs par défaut en cas d'erreur
      setState(() {
        _categories = ['Toutes'];
        _cities = ['Toutes'];
      });
    }
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
      _updateMarkers();
    } catch (e) {
      debugPrint('Erreur de localisation: $e');
    }
  }

  void _updateMarkers() async {
    if (_currentPosition == null) return;

    // Récupérer le type actuel (company/association) selon l'onglet sélectionné
    final currentType = _tabController.index == 0 ? 'company' : 'association';

    final companies = await _firestore
        .collection('companys')
        .where('type', isEqualTo: currentType) // Filtrer par type
        .get();

    Map<String, List<Company>> locationGroups = {};

    for (var doc in companies.docs) {
      try {
        final company = Company.fromDocument(doc);
        // Appliquer les filtres de catégorie et ville
        if ((_selectedCategory == 'Toutes' ||
                company.categorie == _selectedCategory) &&
            (_selectedCity == 'Toutes' ||
                company.adress.ville == _selectedCity)) {
          final locationKey =
              '${company.adress.latitude},${company.adress.longitude}';
          locationGroups.putIfAbsent(locationKey, () => []).add(company);
        }
      } catch (e) {
        debugPrint('Erreur lors du groupement: $e');
      }
    }

    // Trier les groupes selon les critères de tri actuels
    for (var companies in locationGroups.values) {
      _sortOrganizations(companies);
    }

    Set<CustomMarker> markers = {};

    for (var entry in locationGroups.entries) {
      final companies = entry.value;
      final firstCompany = companies.first;
      final position = latlong.LatLng(
        firstCompany.adress.latitude,
        firstCompany.adress.longitude,
      );

      if (companies.length == 1) {
        markers.add(
          CustomMarker(
            id: firstCompany.id,
            position: position,
            icon: _buildSingleMarkerIcon(firstCompany.logo),
            onTap: () => _showCompaniesBottomSheet([firstCompany]),
            company: firstCompany,
          ),
        );
      } else {
        markers.add(
          CustomMarker(
            id: 'group_${entry.key}',
            position: position,
            icon: _buildGroupMarkerIcon(companies.length),
            onTap: () => _showCompaniesBottomSheet(companies),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  Widget _buildSingleMarkerIcon(String logoUrl) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 2),
        image: DecorationImage(
          image: NetworkImage(logoUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildGroupMarkerIcon(int count) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showCompaniesBottomSheet(List<Company> companies) {
    setState(() => _isBottomSheetOpen = true);

    // Déterminer le type d'organisation selon l'onglet actuel
    final isAssociation = _tabController.index == 1;
    final title = isAssociation
        ? 'Associations à cette adresse (${companies.length})'
        : 'Entreprises à cette adresse (${companies.length})';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.3, 0.6, 0.95],
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: companies.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CompanyCard(companies[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      setState(() => _isBottomSheetOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Annuaire',
        align: Alignment.center,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Entreprises'),
            Tab(text: 'Associations'),
          ],
          indicatorColor: const Color(0xFF0B7FE9),
          labelColor: const Color(0xFF0B7FE9),
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
            },
          ),
          if (!_showMap)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterBottomSheet,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrganizationsList(type: 'company'),
          _buildOrganizationsList(type: 'association'),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              focusColor: Colors.transparent,
              isExpanded: true,
              value: value,
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              icon: const Icon(Icons.arrow_drop_down),
              style: const TextStyle(color: Colors.black87, fontSize: 16),
              dropdownColor: Colors.white,
              // Ajoutez cette propriété pour personnaliser l'apparence de l'élément sélectionné
              selectedItemBuilder: (BuildContext context) {
                return items.map<Widget>((String item) {
                  return Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filtres',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedCategory = 'Toutes';
                            _selectedCity = 'Toutes';
                          });
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFilterDropdown(
                    'Catégorie',
                    _selectedCategory,
                    _categories,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedCategory = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFilterDropdown(
                    'Ville',
                    _selectedCity,
                    _cities,
                    (String? newValue) {
                      if (newValue != null) {
                        setModalState(() {
                          _selectedCity = newValue;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4B88DA),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {});
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Appliquer les filtres',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrganizationsList({required String type}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('companys')
          .where('type', isEqualTo: type)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var organizations = snapshot.data!.docs
            .map((doc) {
              try {
                return Company.fromDocument(doc);
              } catch (e) {
                print('Erreur lors de la conversion du document ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Company>()
            .where((org) =>
                (_selectedCategory == 'Toutes' ||
                    org.categorie == _selectedCategory) &&
                (_selectedCity == 'Toutes' ||
                    org.adress.ville == _selectedCity))
            .toList();

        // Appliquer le tri
        organizations = _sortOrganizations(organizations);

        if (organizations.isEmpty) {
          return Center(
            child: Text(type == 'company'
                ? 'Aucune entreprise trouvée'
                : 'Aucune association trouvée'),
          );
        }

        return Column(
          children: [
            // N'afficher le bouton de tri que si on n'est pas en mode carte
            if (!_showMap)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _showSortMenu,
                      icon: const Icon(Icons.sort),
                      label: Text(
                          'Trier par ${_sortBy == 'name' ? 'nom' : _sortBy == 'city' ? 'ville' : 'catégorie'}'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _showMap
                  ? _buildMap()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: organizations.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: CompanyCard(organizations[index]),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap() {
    if (_currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: latlong.LatLng(
            _currentPosition!.latitude, _currentPosition!.longitude),
        initialZoom: 13,
        onTap: (_, point) => setState(() => _selectedCompany = null),
        interactionOptions: InteractionOptions(
          flags:
              _isBottomSheetOpen ? InteractiveFlag.none : InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxAccessToken',
          additionalOptions: const {
            'accessToken': mapboxAccessToken,
          },
        ),
        MarkerLayer(
          markers: _markers
              .map((marker) => Marker(
                    point: marker.position,
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: marker.onTap,
                      child: marker.icon,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMapControls() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _showSearchBottomSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedAddress.isEmpty
                          ? 'Rechercher une adresse'
                          : _selectedAddress,
                      style: const TextStyle(color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
          ),
        ),
        const SizedBox(width: 8),
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: IconButton(
            icon: const Icon(Icons.radar),
            onPressed: _showRadiusBottomSheet,
          ),
        ),
      ],
    );
  }

  void _showSearchBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Rechercher une adresse...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) async {
                            if (value.length > 2) {
                              final predictions =
                                  await _getPlacePredictions(value);
                              setModalState(() {
                                _predictions = predictions;
                              });
                            } else {
                              setModalState(() {
                                _predictions = [];
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: () {
                          _goToCurrentLocation();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _predictions.isEmpty
                      ? const Center(
                          child: Text(
                              'Commencez à taper pour rechercher une adresse'),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          itemCount: _predictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _predictions[index];
                            return ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(prediction['description']),
                              onTap: () {
                                _searchController.text =
                                    prediction['description'];
                                _searchLocation(prediction['place_id'], true);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      setState(() {
        _predictions = [];
        _searchController.clear();
      });
    });
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition != null) {
      _mapController.move(
        latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        18,
      );

      try {
        final url = Uri.parse(
            'https://api.mapbox.com/geocoding/v5/mapbox.places/${_currentPosition!.longitude},${_currentPosition!.latitude}.json'
            '?access_token=$mapboxAccessToken'
            '&country=fr');

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['features'].isNotEmpty) {
            setState(() {
              _selectedAddress = data['features'][0]['place_name'];
            });
          }
        }
      } catch (e) {
        debugPrint('Erreur lors de la récupération de l\'adresse: $e');
      }
    }
  }

  Future<List<dynamic>> _getPlacePredictions(String input) async {
    if (input.isEmpty) return [];

    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$input.json'
          '?access_token=$mapboxAccessToken'
          '&country=fr'
          '&types=address');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['features']
            .map((feature) => {
                  'place_id': feature['id'],
                  'description': feature['place_name'],
                })
            .toList();
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'autocomplétion: $e');
    }
    return [];
  }

  Future<void> _searchLocation(String query, bool isPlaceId) async {
    try {
      final url = Uri.parse(
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json'
          '?access_token=$mapboxAccessToken'
          '&country=fr');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          final feature = data['features'][0];
          final coordinates = feature['center'];

          setState(() {
            _selectedAddress = feature['place_name'];
            _mapController.move(
              latlong.LatLng(coordinates[1], coordinates[0]),
              18,
            );
            _searchFocusNode.unfocus();
            _predictions = [];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adresse non trouvée'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRadiusBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rayon de recherche',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              _radiusOptions.length,
              (index) => ListTile(
                title: Text('${_radiusOptions[index]} km'),
                trailing: _selectedRadius == _radiusOptions[index]
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedRadius = _radiusOptions[index];
                  });
                  _updateMarkersWithRadius();
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double calculateDistance(latlong.LatLng point1, latlong.LatLng point2) {
    const Distance distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      point1,
      point2,
    );
  }

  void _updateMarkersWithRadius() async {
    if (_currentPosition == null) return;

    final companies = await _firestore.collection('companys').get();
    Map<String, List<Company>> locationGroups = {};
    List<Company> companiesInRadius = []; // Liste pour le bottom sheet

    final center = latlong.LatLng(
      _selectedAddress.isEmpty
          ? _currentPosition!.latitude
          : _mapController.camera.center.latitude,
      _selectedAddress.isEmpty
          ? _currentPosition!.longitude
          : _mapController.camera.center.longitude,
    );

    // Ajuster le zoom en fonction du rayon
    double zoom = 14 - (_selectedRadius / 5); // Formule approximative
    _mapController.move(center, zoom);

    for (var doc in companies.docs) {
      try {
        final company = Company.fromDocument(doc);
        final companyLatLng = latlong.LatLng(
          company.adress.latitude,
          company.adress.longitude,
        );

        final distance = calculateDistance(center, companyLatLng);

        if (distance <= _selectedRadius) {
          final locationKey =
              '${company.adress.latitude},${company.adress.longitude}';
          locationGroups.putIfAbsent(locationKey, () => []).add(company);
          companiesInRadius
              .add(company); // Ajouter à la liste pour le bottom sheet
        }
      } catch (e) {
        debugPrint('Erreur lors du groupement: $e');
      }
    }

    // Créer les marqueurs comme avant
    Set<CustomMarker> markers = {};
    for (var entry in locationGroups.entries) {
      final companies = entry.value;
      final firstCompany = companies.first;
      final position = latlong.LatLng(
        firstCompany.adress.latitude,
        firstCompany.adress.longitude,
      );

      if (companies.length == 1) {
        markers.add(
          CustomMarker(
            id: firstCompany.id,
            position: position,
            icon: _buildSingleMarkerIcon(firstCompany.logo),
            onTap: () => _showCompaniesBottomSheet([firstCompany]),
            company: firstCompany,
          ),
        );
      } else {
        markers.add(
          CustomMarker(
            id: 'group_${entry.key}',
            position: position,
            icon: _buildGroupMarkerIcon(companies.length),
            onTap: () => _showCompaniesBottomSheet(companies),
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
    });

    // Afficher le bottom sheet avec les entreprises trouvées
    if (companiesInRadius.isNotEmpty) {
      _showCompaniesInRadiusBottomSheet(companiesInRadius, _selectedRadius);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune entreprise trouvée dans ce rayon'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCompaniesInRadiusBottomSheet(
      List<Company> companies, double radius) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Entreprises dans un rayon de ${radius.toInt()} km (${companies.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: companies.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CompanyCard(companies[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Méthode pour trier les organisations
  List<Company> _sortOrganizations(List<Company> organizations) {
    switch (_sortBy) {
      case 'name':
        organizations.sort((a, b) => _sortAscending
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
        break;
      case 'city':
        organizations.sort((a, b) => _sortAscending
            ? a.adress.ville.compareTo(b.adress.ville)
            : b.adress.ville.compareTo(a.adress.ville));
        break;
      case 'category':
        organizations.sort((a, b) => _sortAscending
            ? a.categorie.compareTo(b.categorie)
            : b.categorie.compareTo(a.categorie));
        break;
    }
    return organizations;
  }

  // Méthode pour afficher le menu de tri
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Trier par'),
            trailing: IconButton(
              icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () {
                setState(() => _sortAscending = !_sortAscending);
                Navigator.pop(context);
              },
            ),
          ),
          ListTile(
            title: const Text('Nom'),
            leading: Radio<String>(
              value: 'name',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
          ),
          ListTile(
            title: const Text('Ville'),
            leading: Radio<String>(
              value: 'city',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
          ),
          ListTile(
            title: const Text('Catégorie'),
            leading: Radio<String>(
              value: 'category',
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
