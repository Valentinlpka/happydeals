import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_service_page.dart';
import 'package:happy/services/service_service.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:provider/provider.dart';

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

  // Variables pour la localisation
  double? _selectedLat;
  double? _selectedLng;
  double _selectedRadius = 20.0;
  String _selectedAddress = '';

  // Remplacer par votre clé API Google Places
  static const String _googleApiKey = 'AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeLocation();
  }

  void _showLocationFilter() async {
    await LocationFilterBottomSheet.show(
      context: context,
      onLocationSelected: (lat, lng, radius, address) {
        setState(() {
          _selectedLat = lat;
          _selectedLng = lng;
          _selectedRadius = radius;
          _selectedAddress = address;
        });
      },
      currentLat: _selectedLat,
      currentLng: _selectedLng,
      currentRadius: _selectedRadius,
      currentAddress: _selectedAddress,
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

  Future<void> _initializeLocation() async {
    final userProvider = Provider.of<UserModel>(context, listen: false);
    if (userProvider.latitude != 0.0 && userProvider.longitude != 0.0) {
      setState(() {
        _selectedLat = userProvider.latitude;
        _selectedLng = userProvider.longitude;
        _selectedAddress = '${userProvider.city}, ${userProvider.zipCode}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
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
                  onPressed: _showLocationFilter,
                ),
              ],
              pinned: true,
              floating: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(80),
                child: Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: [
                      if (_selectedAddress.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            'Localisation : $_selectedAddress',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      TextField(
                        controller: _cityController,
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
          ];
        },
        body: StreamBuilder<List<ServiceModel>>(
          stream: widget.professionalId != null
              ? _serviceService
                  .getServicesByProfessional(widget.professionalId!)
              : _searchQuery.isEmpty
                  ? _serviceService.getActiveServices()
                  : _serviceService.searchServices(_searchQuery),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
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
              );
            }

            final services = snapshot.data ?? [];

            if (services.isEmpty) {
              return Center(
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

            List<String> sortedProIds = servicesByPro.keys.toList();

            if (_selectedLat == null || _selectedLng == null) {
              return ListView.builder(
                itemCount: sortedProIds.length,
                itemBuilder: (context, index) => _buildCompanyCard(
                  sortedProIds[index],
                  servicesByPro[sortedProIds[index]]!,
                ),
              );
            }

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
                      _selectedLat!,
                      _selectedLng!,
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur de tri: ${snapshot.error}'),
                  );
                }

                final sortedIds = snapshot.data ?? sortedProIds;
                return ListView.builder(
                  itemCount: sortedIds.length,
                  itemBuilder: (context, index) => _buildCompanyCard(
                    sortedIds[index],
                    servicesByPro[sortedIds[index]]!,
                  ),
                );
              },
            );
          },
        ),
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

        double? distance;
        if (_selectedLat != null &&
            _selectedLng != null &&
            companyData['adress'] != null &&
            companyData['adress'] is Map &&
            companyData['adress']['latitude'] != null &&
            companyData['adress']['longitude'] != null) {
          distance = _calculateDistance(
            _selectedLat!,
            _selectedLng!,
            companyData['adress']['latitude'],
            companyData['adress']['longitude'],
          );
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
            mainAxisSize: MainAxisSize.min,
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
              // Liste horizontale des services
              SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: services.length,
                  itemBuilder: (context, serviceIndex) {
                    return SizedBox(
                      width: 200,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _buildServiceCard(services[serviceIndex]),
                      ),
                    );
                  },
                ),
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
                  if (service.hasActivePromotion)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[700],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '-${service.discount!['value']}${service.discount!['type'] == 'percentage' ? '%' : '€'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
                  Row(
                    children: [
                      if (service.hasActivePromotion) ...[
                        Text(
                          '${service.price.toStringAsFixed(2)}€',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${service.finalPrice.toStringAsFixed(2)}€',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ] else
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
    _scrollController.dispose();
    super.dispose();
  }
}
