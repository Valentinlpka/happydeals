import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_service_page.dart';
import 'package:happy/services/service_service.dart';
import 'package:http/http.dart' as http;

class ServiceListPage extends StatefulWidget {
  final String? professionalId;
  const ServiceListPage({super.key, this.professionalId});

  @override
  _ServiceListPageState createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  final ServiceClientService _serviceService = ServiceClientService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showScrollToTop = false;
  Position? _currentPosition;
  String? _selectedCity;
  bool _isLoading = false;
  List<String> _citySuggestions = [];
  Timer? _debounce;

  // Remplacer par votre clé API Google Places
  static const String _googleApiKey = 'AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _getCurrentLocation();
    _cityController.addListener(_onCitySearchChanged);
  }

  void _onCitySearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _getCitySuggestions(_cityController.text);
    });
  }

  Future<void> _getCitySuggestions(String input) async {
    if (input.isEmpty) {
      setState(() => _citySuggestions = []);
      return;
    }

    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&language=fr&components=country:fr&key=$_googleApiKey');

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        setState(() {
          _citySuggestions = (data['predictions'] as List)
              .map((prediction) => prediction['description'] as String)
              .toList();
        });
      }
    } catch (e) {
      print('Erreur lors de la récupération des suggestions: $e');
    }
  }

  Future<void> _searchByCity(String city) async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$city&key=$_googleApiKey');

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final location = data['results'][0]['geometry']['location'];
        setState(() {
          _currentPosition = Position(
            latitude: location['lat'],
            longitude: location['lng'],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
          _selectedCity = city;
          _cityController.text = city;
          _citySuggestions = [];
        });
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ville non trouvée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erreur lors de la recherche de la ville')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showLocationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Entrez votre ville',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  hintText: 'Ex: Paris',
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
              ),
              if (_citySuggestions.isNotEmpty)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _citySuggestions.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(_citySuggestions[index]),
                        onTap: () => _searchByCity(_citySuggestions[index]),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _searchByCity(_cityController.text),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Rechercher'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Rayon de la Terre en kilomètres

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  void _onScroll() {
    if (_scrollController.offset >= 400) {
      if (!_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      }
    } else {
      if (_showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationBottomSheet();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showLocationBottomSheet();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showLocationBottomSheet();
        return;
      }

      Position position = await Geolocator.getCurrentPosition();

      // Utiliser l'API Google Geocoding pour obtenir le nom de la ville
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_googleApiKey');

      final response = await http.get(url);
      final data = json.decode(response.body);

      String? cityName;
      if (data['status'] == 'OK') {
        for (var component in data['results'][0]['address_components']) {
          final types = component['types'] as List;
          if (types.contains('locality')) {
            cityName = component['long_name'];
            break;
          }
        }
      }

      setState(() {
        _currentPosition = position;
        if (cityName != null) {
          _selectedCity = cityName;
          _cityController.text = cityName;
        }
      });
    } catch (e) {
      print('Erreur de géolocalisation: $e');
      _showLocationBottomSheet();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.grey[50],
            title: const Text(
              'Services',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.location_on, color: Colors.black87),
                onPressed: _showLocationBottomSheet,
              ),
            ],
            floating: true,
            pinned: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: Container(
                color: Colors.grey[50],
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    if (_selectedCity != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          'Localisation : $_selectedCity',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un service...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          StreamBuilder<List<ServiceModel>>(
            stream: widget.professionalId != null
                ? _serviceService
                    .getServicesByProfessional(widget.professionalId!)
                : _searchQuery.isEmpty
                    ? _serviceService.getActiveServices()
                    : _serviceService.searchServices(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Une erreur est survenue',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Veuillez réessayer plus tard',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final services = snapshot.data ?? [];

              if (services.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.category_outlined
                              : Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Aucun service disponible'
                              : 'Aucun résultat trouvé pour "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Grouper les services par professionalId
              Map<String, List<ServiceModel>> servicesByPro = {};
              for (var service in services) {
                if (!servicesByPro.containsKey(service.professionalId)) {
                  servicesByPro[service.professionalId] = [];
                }
                servicesByPro[service.professionalId]!.add(service);
              }

              // Trier les professionnels par distance si la position est disponible
              List<String> sortedProIds = servicesByPro.keys.toList();

              // On ne trie pas si on n'a pas de position
              if (_currentPosition == null) {
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCompanyCard(
                      sortedProIds[index],
                      servicesByPro[sortedProIds[index]]!,
                    ),
                    childCount: sortedProIds.length,
                  ),
                );
              }

              // Si on a une position, on retourne un FutureBuilder pour gérer le tri asynchrone
              return FutureBuilder<List<String>>(
                future: Future.wait(
                  sortedProIds.map((proId) async {
                    final doc = await FirebaseFirestore.instance
                        .collection('companys')
                        .doc(proId)
                        .get();
                    final data = doc.data();
                    if (data != null &&
                        data['latitude'] != null &&
                        data['longitude'] != null) {
                      final distance = _calculateDistance(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        data['latitude'],
                        data['longitude'],
                      );
                      return MapEntry(proId, distance);
                    }
                    return MapEntry(proId, double.infinity);
                  }),
                ).then((entries) {
                  final distances = Map.fromEntries(
                    entries.map((e) => MapEntry(e.key, e.value)),
                  );
                  sortedProIds
                      .sort((a, b) => distances[a]!.compareTo(distances[b]!));
                  return sortedProIds;
                }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Text('Erreur de tri: ${snapshot.error}'),
                      ),
                    );
                  }

                  final sortedIds = snapshot.data ?? sortedProIds;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildCompanyCard(
                        sortedIds[index],
                        servicesByPro[sortedIds[index]]!,
                      ),
                      childCount: sortedIds.length,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              mini: true,
              backgroundColor: Colors.white,
              child: Icon(Icons.keyboard_arrow_up, color: Colors.grey[900]),
            )
          : null,
    );
  }

  Widget _buildCompanyCard(String proId, List<ServiceModel> services) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('companys').doc(proId).get(),
      builder: (context, companySnapshot) {
        if (!companySnapshot.hasData) {
          return const SizedBox.shrink();
        }

        Map<String, dynamic> companyData =
            companySnapshot.data!.data() as Map<String, dynamic>;

        // Déboguer les données de l'entreprise
        print('Données de l\'entreprise $proId:');
        print(
            'Position actuelle: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
        print('Données de localisation entreprise:');
        print('Latitude: ${companyData['latitude']}');
        print('Longitude: ${companyData['longitude']}');
        print('Adresse: ${companyData['adress']}');

        double? distance;
        if (_currentPosition != null &&
            companyData['adress'] != null &&
            companyData['adress'] is Map &&
            companyData['adress']['latitude'] != null &&
            companyData['adress']['longitude'] != null) {
          distance = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            companyData['adress']['latitude'],
            companyData['adress']['longitude'],
          );
          print('Distance calculée: $distance km');
        } else {
          print('Impossible de calculer la distance:');
          print('Position actuelle existe: ${_currentPosition != null}');
          print('Adresse existe: ${companyData['adress'] != null}');
          print('Adresse est une Map: ${companyData['adress'] is Map}');
          if (companyData['adress'] is Map) {
            print(
                'Latitude existe: ${companyData['adress']['latitude'] != null}');
            print(
                'Longitude existe: ${companyData['adress']['longitude'] != null}');
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête de l'entreprise
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsEntreprise(
                      entrepriseId: proId,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Logo de l'entreprise
                      Hero(
                        tag: 'company_logo_$proId',
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 2,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(
                                companyData['logo'] ?? '',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Informations de l'entreprise
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              companyData['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              companyData['category'] ?? '',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            if (distance != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'À ${distance.toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Note et nombre d'avis
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(companyData['averageRating'] ?? 0.0).toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${companyData['numberOfReviews'] ?? 0} avis',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Liste des services
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: services.length,
                itemBuilder: (context, serviceIndex) {
                  final service = services[serviceIndex];
                  return _buildServiceCard(service);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServiceDetailPage(serviceId: service.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image du service
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: service.images.isNotEmpty
                        ? Hero(
                            tag: 'service_image_${service.id}',
                            child: Image.network(
                              service.images[0],
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            color: Colors.grey[100],
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 32,
                              color: Colors.grey[400],
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${service.duration} min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Informations du service
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${service.price.toStringAsFixed(2)}€',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
