import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/widgets/cards/company_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;
import 'package:provider/provider.dart';

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
  List<String> _categories = ['Toutes'];
  bool _showMap = false;
  Position? _currentPosition;
  Company? _selectedCompany;
  Set<CustomMarker> _markers = {};
  MapController? _mapController;
  bool _isBottomSheetOpen = false;
  List<dynamic> _predictions = [];
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  static const String mapboxAccessToken =
      'pk.eyJ1IjoiaGFwcHlkZWFscyIsImEiOiJjbHo3ZHA5NDYwN2hyMnFzNTdiMWd2Zm92In0.1nmT5Fumjq16InZ3dmG9zQ';
  String _selectedAddress = '';
  double _selectedRadius = 20.0;
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      _updateMarkers();
      _loadCategories();
    });
    _loadCategories();
    _initializeLocation();

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
    _mapController = null;
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final companiesSnapshot = await _firestore.collection('companys').get();
      final Set<String> categories = {};

      for (var doc in companiesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('categorie')) {
          categories.add(data['categorie'] as String);
        }
      }

      setState(() {
        _categories = ['Toutes', ...categories];
      });
    } catch (e) {
      print('Erreur lors du chargement des catégories: $e');
      // Définir des valeurs par défaut en cas d'erreur
      setState(() {
        _categories = ['Toutes'];
      });
    }
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);

    // Si l'utilisateur a une localisation enregistrée, l'utiliser
    if (userModel.latitude != 0.0 && userModel.longitude != 0.0) {
      setState(() {
        _selectedLat = userModel.latitude;
        _selectedLng = userModel.longitude;
        _selectedAddress = '${userModel.city}, ${userModel.zipCode}';
      });
      _updateMarkersWithRadius();
    } else {
      // Sinon, essayer d'obtenir la localisation actuelle
      await _getCurrentLocation();
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
    if (!_showMap) return;

    final type = _tabController.index == 0 ? 'company' : 'association';
    final snapshot = await _firestore
        .collection('companys')
        .where('type', isEqualTo: type)
        .get();

    final companies = snapshot.docs
        .map((doc) {
          try {
            return Company.fromDocument(doc);
          } catch (e) {
            print('Erreur lors de la conversion du document ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Company>()
        .where((company) =>
            _selectedCategory == 'Toutes' ||
            company.categorie == _selectedCategory)
        .toList();

    // Grouper les entreprises par localisation
    final Map<String, List<Company>> locationGroups = {};
    for (var company in companies) {
      final locationKey =
          '${company.adress.latitude},${company.adress.longitude}';
      locationGroups.putIfAbsent(locationKey, () => []).add(company);
    }

    final Set<CustomMarker> markers = {};

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
                if (_showMap && _selectedLat != null && _selectedLng != null) {
                  _updateMarkersWithRadius();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _showLocationFilterBottomSheet,
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
                          setState(() {
                            _selectedCategory = 'Toutes';
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Réinitialiser'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Catégories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((category) {
                          final isSelected = _selectedCategory == category;
                          return FilterChip(
                            selected: isSelected,
                            label: Text(category),
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.grey[800],
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            backgroundColor: Colors.grey[200],
                            selectedColor: const Color(0xFF4B88DA),
                            onSelected: (bool selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              Navigator.pop(context);
                            },
                            showCheckmark: false,
                          );
                        }).toList(),
                      ),
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

        final organizations = snapshot.data!.docs
            .map((doc) {
              try {
                return Company.fromDocument(doc);
              } catch (e) {
                print('Erreur lors de la conversion du document ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Company>()
            .where((org) {
              bool matchesCategory = _selectedCategory == 'Toutes' ||
                  org.categorie == _selectedCategory;

              // Filtre de localisation
              if (_selectedLat != null && _selectedLng != null) {
                final distance = calculateDistance(
                  latlong.LatLng(_selectedLat!, _selectedLng!),
                  latlong.LatLng(org.adress.latitude, org.adress.longitude),
                );
                return matchesCategory && distance <= _selectedRadius;
              }

              return matchesCategory;
            })
            .toList();

        if (organizations.isEmpty) {
          return Center(
            child: Text(type == 'company'
                ? 'Aucune entreprise trouvée'
                : 'Aucune association trouvée'),
          );
        }

        return Column(
          children: [
            if (!_showMap && _selectedAddress.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Près de $_selectedAddress',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4B88DA),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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
    if (_selectedLat == null || _selectedLng == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final center = latlong.LatLng(_selectedLat!, _selectedLng!);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: _calculateZoomLevel(_selectedRadius),
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
          tileProvider: CancellableNetworkTileProvider(),
        ),
        // Toujours afficher le cercle de rayon
        CircleLayer(
          circles: [
            CircleMarker(
              point: center,
              radius: _selectedRadius * 1000, // Convertir en mètres
              color: const Color(0x304B88DA), // Couleur bleue semi-transparente
              borderColor: const Color(0xFF4B88DA),
              borderStrokeWidth: 2,
              useRadiusInMeter: true,
            ),
          ],
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

  double _calculateZoomLevel(double radiusInKm) {
    // Formule approximative pour calculer le niveau de zoom en fonction du rayon
    return 14 - (log(radiusInKm) / log(2));
  }

  double calculateDistance(latlong.LatLng point1, latlong.LatLng point2) {
    const Distance distance = Distance();
    return distance(point1, point2) / 1000; // Convertir en kilomètres
  }

  void _updateMarkersWithRadius() async {
    if (_selectedLat == null &&
        _selectedLng == null &&
        _currentPosition == null) return;

    final companies = await _firestore.collection('companys').get();
    Map<String, List<Company>> locationGroups = {};
    List<Company> filteredCompanies = [];

    final center = latlong.LatLng(
      _selectedLat ?? _currentPosition!.latitude,
      _selectedLng ?? _currentPosition!.longitude,
    );

    // Ajuster le zoom en fonction du rayon seulement si la carte est initialisée
    if (_mapController != null && _showMap) {
      _mapController!.move(center, _calculateZoomLevel(_selectedRadius));
    }

    for (var doc in companies.docs) {
      try {
        final company = Company.fromDocument(doc);

        // Vérifier si l'entreprise correspond au type sélectionné (company/association)
        if (company.type !=
            (_tabController.index == 0 ? 'company' : 'association')) {
          continue;
        }

        // Vérifier si l'entreprise correspond à la catégorie sélectionnée
        if (_selectedCategory != 'Toutes' &&
            company.categorie != _selectedCategory) {
          continue;
        }

        final companyLatLng = latlong.LatLng(
          company.adress.latitude,
          company.adress.longitude,
        );

        final distance = calculateDistance(center, companyLatLng);

        if (distance <= _selectedRadius) {
          final locationKey =
              '${company.adress.latitude},${company.adress.longitude}';
          locationGroups.putIfAbsent(locationKey, () => []).add(company);
          filteredCompanies.add(company);
        }
      } catch (e) {
        debugPrint('Erreur lors du groupement: $e');
      }
    }

    // Mettre à jour les marqueurs
    setState(() {
      _markers = locationGroups.entries.map((entry) {
        final companies = entry.value;
        final firstCompany = companies.first;
        final position = latlong.LatLng(
          firstCompany.adress.latitude,
          firstCompany.adress.longitude,
        );

        return CustomMarker(
          position: position,
          id: entry.key,
          company: companies.length == 1 ? firstCompany : null,
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4B88DA), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: companies.length == 1
                  ? ClipOval(
                      child: Image.network(
                        firstCompany.logo,
                        width: 35,
                        height: 35,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.business,
                          color: Color(0xFF4B88DA),
                          size: 20,
                        ),
                      ),
                    )
                  : Text(
                      '${companies.length}',
                      style: const TextStyle(
                        color: Color(0xFF4B88DA),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          onTap: () {
            if (companies.length == 1) {
              setState(() => _selectedCompany = firstCompany);
              _showCompanyDetails(firstCompany);
            } else {
              _showCompaniesAtLocation(companies);
            }
          },
        );
      }).toSet();
    });

    // Toujours afficher la liste des entreprises filtrées quand une localisation est sélectionnée
    if (filteredCompanies.isEmpty) {
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

  void _showLocationFilterBottomSheet() async {
    await LocationFilterBottomSheet.show(
      context: context,
      onLocationSelected: (lat, lng, radius, address) {
        setState(() {
          _selectedLat = lat;
          _selectedLng = lng;
          _selectedRadius = radius;
          _selectedAddress = address;
        });

        // Mettre à jour les marqueurs et la carte
        _updateMarkersWithRadius();
      },
      currentLat: _selectedLat,
      currentLng: _selectedLng,
      currentRadius: _selectedRadius,
      currentAddress: _selectedAddress,
    );
  }

  void _showCompanyDetails(Company company) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CompanyCard(company),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompaniesAtLocation(List<Company> companies) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  '${companies.length} entreprises à cette adresse',
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
}
