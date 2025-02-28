import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_service_page.dart';
import 'package:happy/services/service_service.dart';

class ServiceListPage extends StatefulWidget {
  final String? professionalId;
  const ServiceListPage({super.key, this.professionalId});

  @override
  _ServiceListPageState createState() => _ServiceListPageState();
}

class _ServiceListPageState extends State<ServiceListPage> {
  final ServiceClientService _serviceService = ServiceClientService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
            floating: true,
            pinned: true,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
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
                    fillColor: Colors.grey[100],
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

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    String proId = servicesByPro.keys.elementAt(index);
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('companys')
                          .doc(proId)
                          .get(),
                      builder: (context, companySnapshot) {
                        if (!companySnapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        Map<String, dynamic> companyData = companySnapshot.data!
                            .data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                          ],
                                        ),
                                      ),
                                      // Note et nombre d'avis
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
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
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.75,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                ),
                                itemCount: servicesByPro[proId]!.length,
                                itemBuilder: (context, serviceIndex) {
                                  final service =
                                      servicesByPro[proId]![serviceIndex];
                                  return _buildServiceCard(service);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  childCount: servicesByPro.length,
                ),
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
    _scrollController.dispose();
    super.dispose();
  }
}
