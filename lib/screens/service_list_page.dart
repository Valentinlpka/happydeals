import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/config/app_router.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/services/service_service.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:provider/provider.dart';

class ServiceListPage extends StatefulWidget {
  final String? professionalId;
  const ServiceListPage({super.key, this.professionalId});

  @override
  State<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage>
    with AutomaticKeepAliveClientMixin {
  final ServiceClientService _serviceService = ServiceClientService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Map<String, Map<String, dynamic>> _companyCache = {};
  List<ServiceModel>? _cachedServices;

  String _searchQuery = '';
  bool _showScrollToTop = false;

  @override
  bool get wantKeepAlive => true;

  double? _selectedLat;
  double? _selectedLng;
  double _selectedRadius = 20.0;
  String _selectedAddress = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeLocation();
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

  void _onScroll() {
    setState(() {
      _showScrollToTop = _scrollController.offset >= 400;
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (_selectedAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _selectedAddress,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
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
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ],
      ),
    );
  }

  Map<String, List<ServiceModel>> _groupServicesByProfessional(
      List<ServiceModel> services) {
    final Map<String, List<ServiceModel>> grouped = {};
    for (final service in services) {
      grouped.putIfAbsent(service.professionalId, () => []).add(service);
    }
    return grouped;
  }

  Widget _buildCompanySection(String proId, List<ServiceModel> services) {
    if (_companyCache.containsKey(proId)) {
      final companyData = _companyCache[proId]!;
      final distance = _getCompanyDistance(companyData);
      return _buildCompanySectionContent(
          companyData, proId, services, distance);
    }

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection('companys').doc(proId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        _companyCache[proId] = companyData;

        final distance = _getCompanyDistance(companyData);
        return _buildCompanySectionContent(
            companyData, proId, services, distance);
      },
    );
  }

  Widget _buildCompanySectionContent(
    Map<String, dynamic> companyData,
    String proId,
    List<ServiceModel> services,
    double? distance,
  ) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          _buildCompanyHeader(companyData, proId, distance),
          const Divider(height: 1),
          _buildServicesCarousel(services),
        ],
      ),
    );
  }

  double? _getCompanyDistance(Map<String, dynamic> companyData) {
    if (_selectedLat == null || _selectedLng == null) return null;

    final address = companyData['adress'] as Map<String, dynamic>?;
    if (address == null) return null;

    final lat = address['latitude'] as double?;
    final lng = address['longitude'] as double?;
    if (lat == null || lng == null) return null;

    return _calculateDistance(_selectedLat!, _selectedLng!, lat, lng);
  }

  Widget _buildCompanyHeader(
      Map<String, dynamic> companyData, String proId, double? distance) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsEntreprise(entrepriseId: proId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildCompanyLogo(companyData['logo'], proId),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyData['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (distance != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'À ${distance.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildRatingWidget(companyData),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyLogo(String? logoUrl, String proId) {
    return Hero(
      tag: 'company_logo_$proId',
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[200]!),
          image: logoUrl != null
              ? DecorationImage(
                  image: NetworkImage(logoUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: logoUrl == null
            ? Icon(Icons.business, color: Colors.grey[400])
            : null,
      ),
    );
  }

  Widget _buildRatingWidget(Map<String, dynamic> companyData) {
    final rating = (companyData['averageRating'] ?? 0.0).toDouble();
    final reviews = companyData['numberOfReviews'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(
          '$reviews avis',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildServicesCarousel(List<ServiceModel> services) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        itemCount: services.length,
        itemBuilder: (context, index) {
          return SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildServiceCard(services[index]),
            ),
          );
        },
      ),
    );
  }

  void _navigateToServiceDetail(ServiceModel service) {
    Navigator.pushNamed(
      context,
      AppRouter.serviceDetails,
      arguments: service.id,
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
        onTap: () => _navigateToServiceDetail(service),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildServiceImage(service),
                  if (service.hasActivePromotion) _buildPromotionBadge(service),
                  _buildDurationBadge(service),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  _buildPriceWidget(service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceImage(ServiceModel service) {
    if (service.images.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child:
            Icon(Icons.image_not_supported_outlined, color: Colors.grey[400]),
      );
    }

    return Hero(
      tag: 'service_image_${service.id}',
      child: Image.network(
        service.images[0],
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[100],
            child: Icon(Icons.error_outline, color: Colors.grey[400]),
          );
        },
      ),
    );
  }

  Widget _buildPromotionBadge(ServiceModel service) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red[700],
          borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildDurationBadge(ServiceModel service) {
    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${service.duration} min',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceWidget(ServiceModel service) {
    if (service.hasActivePromotion) {
      return Row(
        children: [
          Text(
            '${service.price.toStringAsFixed(2)}€',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${service.finalPrice.toStringAsFixed(2)}€',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Text(
      '${service.price.toStringAsFixed(2)}€',
      style: TextStyle(
        color: Colors.blue[700],
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Services',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.location_on,
              color: _selectedLat != null ? Colors.blue[700] : Colors.black87,
            ),
            onPressed: () => LocationFilterBottomSheet.show(
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
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ServiceModel>>(
        stream: _getServicesStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snapshot.data ?? [];
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _buildSearchBar(),
              ),
              if (services.isEmpty)
                SliverFillRemaining(
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
                              : 'Aucun résultat pour "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final servicesByPro =
                          _groupServicesByProfessional(services);
                      final proId = servicesByPro.keys.elementAt(index);
                      return _buildCompanySection(proId, servicesByPro[proId]!);
                    },
                    childCount: _groupServicesByProfessional(services).length,
                  ),
                ),
            ],
          );
        },
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

  Stream<List<ServiceModel>> _getServicesStream() {
    if (_cachedServices != null &&
        _searchQuery.isEmpty &&
        widget.professionalId == null) {
      return Stream.value(_cachedServices!);
    }

    if (widget.professionalId != null) {
      return _serviceService.getServicesByProfessional(widget.professionalId!);
    }
    return _searchQuery.isEmpty
        ? _serviceService.getActiveServices()
        : _serviceService.searchServices(_searchQuery);
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Une erreur est survenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
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
