import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/geo_point.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/location_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/troc-et-echange/ad_card.dart';
import 'package:happy/screens/troc-et-echange/ad_creation_page.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/screens/troc-et-echange/my_ad_page.dart';
import 'package:happy/screens/troc-et-echange/saved_ads_page.dart';
import 'package:happy/utils/location_utils.dart';
import 'package:happy/widgets/current_location_display.dart';
import 'package:happy/widgets/unified_location_filter.dart';
import 'package:provider/provider.dart';

class AdListPage extends StatefulWidget {
  const AdListPage({super.key});

  @override
  State<AdListPage> createState() => _AdListPageState();
}

class ActiveFilter {
  final String type;
  final String value;
  final String displayText;

  ActiveFilter({
    required this.type,
    required this.value,
    required this.displayText,
  });
}

class _AdListPageState extends State<AdListPage>
    with SingleTickerProviderStateMixin {
  final List<ActiveFilter> _activeFiltersList = [];
  final List<String> _exchangeTypes = ['Article', 'Temps et Compétences'];
  final List<Ad> _ads = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  Map<String, dynamic> _activeFilters = {};
  String? selectedType;
  String? selectedCategory;
  String? selectedSubCategory;
  String? selectedCondition;
  String? selectedBrand;
  RangeValues priceRange = const RangeValues(0, 1000);
  // Variables pour la localisation (maintenant gérées par LocationProvider)

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadMoreAds();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
    
    // Écouter les changements de localisation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.addListener(_onLocationChanged);
    });
  }

  void _onLocationChanged() {
    if (mounted) {
      setState(() {
        // Vider la liste et recharger avec les nouveaux critères
        _ads.clear();
        _lastDocument = null;
        _hasMore = true;
        _isLoading = false;
      });
      // Recharger les annonces avec les nouveaux critères
      _loadMoreAds();
    }
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await locationProvider.initializeLocation(userModel);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<LocationProvider, UserModel>(
      builder: (context, locationProvider, userModel, child) {
        final userLocation = locationProvider.hasLocation
            ? GeoPoint(locationProvider.latitude!, locationProvider.longitude!)
            : (userModel.latitude != 0 && userModel.longitude != 0
                ? GeoPoint(userModel.latitude, userModel.longitude)
                : null);

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(locationProvider),
                  SliverToBoxAdapter(child: _buildQuickActions()),
                  SliverToBoxAdapter(
                    child: CurrentLocationDisplay(
                      onLocationChanged: () {
                        setState(() {
                          // Vider la liste et recharger avec les nouveaux critères
                          _ads.clear();
                          _lastDocument = null;
                          _hasMore = true;
                          _isLoading = false;
                        });
                        // Recharger les annonces avec les nouveaux critères
                        _loadMoreAds();
                      },
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildFilterChips()),
                  SliverPadding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= _ads.length) {
                            if (_hasMore && !_isLoading) {
                              _loadMoreAds();
                            }
                            return null;
                          }
                          final ad = _ads[index];
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: AdCard(
                              ad: ad,
                              onTap: () => _navigateToAdDetail(ad),
                              onSaveTap: () => _toggleSaveAd(ad),
                              userLocation: userLocation,
                            ),
                          );
                        },
                        childCount: _ads.length,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Chargement...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_ads.isEmpty && !_isLoading)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune annonce trouvée',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Modifiez vos filtres ou créez une nouvelle annonce',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(LocationProvider locationProvider) {
    return SliverAppBar(
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: Colors.grey[300],
          height: 1.0,
        ),
      ),
      backgroundColor: Colors.grey[50],
      floating: false,
      pinned: true,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.location_on,
                color: locationProvider.hasLocation 
                    ? Colors.blue[700] 
                    : Colors.black87,
              ),
              onPressed: _showLocationFilterBottomSheet,
            ),
            if (locationProvider.hasLocation)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.filter_list, color: Colors.black87),
              if (_activeFiltersList.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue[700],
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _activeFiltersList.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: _showFilterBottomSheet,
        ),
      ],
      flexibleSpace: const FlexibleSpaceBar(
        title: Text(
          'Troc & Échanges',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showLocationFilterBottomSheet() async {
    await UnifiedLocationFilter.show(
      context: context,
      onLocationChanged: () {
        setState(() {
          // Vider la liste et recharger avec les nouveaux critères
          _ads.clear();
          _lastDocument = null;
          _hasMore = true;
          _isLoading = false;
        });
        // Recharger les annonces avec les nouveaux critères
        _loadMoreAds();
      },
    );
  }

  Widget _buildQuickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildActionButton(
            'Créer une annonce',
            Icons.add_circle_outline,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AdCreationScreen()),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Mes annonces',
            Icons.list_alt,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyAdsPage()),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            'Sauvegardées',
            Icons.bookmark_border,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedAdsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String title, IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue[700]!.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    if (_activeFiltersList.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Wrap(
            spacing: 8,
            children: _activeFiltersList.map((filter) {
              return Chip(
                label: Text(filter.displayText),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    _activeFiltersList.remove(filter);
                    switch (filter.type) {
                      case 'type':
                        selectedType = null;
                        break;
                      case 'condition':
                        selectedCondition = null;
                        break;
                      case 'price':
                        priceRange = const RangeValues(0, 1000);
                        break;
                      case 'category':
                        selectedCategory = null;
                        selectedSubCategory = null;
                        break;
                      case 'brand':
                        selectedBrand = null;
                        break;
                      case 'location':
                        final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                        locationProvider.clearLocation();
                        break;
                    }
                    _applyFilters();
                  });
                },
                backgroundColor: Colors.blue[50],
                deleteIconColor: Colors.blue[700],
                labelStyle: TextStyle(color: Colors.blue[700]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // En-tête
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setBottomSheetState(() {
                              selectedType = null;
                              selectedSubCategory = null;
                              selectedCondition = null;
                              selectedBrand = null;
                              priceRange = const RangeValues(0, 1000);
                            });
                            // Réinitialiser la localisation via LocationProvider
                            final locationProvider = Provider.of<LocationProvider>(context, listen: false);
                            locationProvider.clearLocation();
                          },
                          child: const Text('Réinitialiser'),
                        ),
                        const Text(
                          'Filtres',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _applyFilters();
                          },
                          child: const Text('Appliquer'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Contenu scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Localisation
                          _buildSectionTitle('Localisation'),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Consumer<LocationProvider>(
                                  builder: (context, locationProvider, child) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (locationProvider.hasLocation) ...[
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.blue[200]!),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.location_on, color: Colors.blue[700]),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    locationProvider.address,
                                                    style: TextStyle(
                                                      color: Colors.blue[700],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${locationProvider.radius.round()} km',
                                                  style: TextStyle(
                                                    color: Colors.blue[700],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            Navigator.pop(context);
                                            await UnifiedLocationFilter.show(
                                              context: context,
                                              onLocationChanged: () {
                                                setState(() {
                                                  // La localisation a été mise à jour
                                                });
                                              },
                                            );
                                          },
                                          icon: Icon(locationProvider.hasLocation ? Icons.edit_location : Icons.location_on),
                                          label: Text(locationProvider.hasLocation ? 'Modifier la localisation' : 'Définir la localisation'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue[700],
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          // Type d'échange
                          _buildSectionTitle('Type d\'échange'),
                          _buildFilterChipsRow(
                            items: _exchangeTypes,
                            selectedValue: selectedType,
                            onSelected: (value) {
                              setBottomSheetState(() {
                                selectedType = value;
                                selectedSubCategory = null;
                              });
                            },
                          ),
                        ],
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _convertExchangeType(String type) {
    switch (type) {
      case 'Article':
        return 'article';
      case 'Temps et Compétences':
        return 'temps et compétences';
      default:
        return type.toLowerCase();
    }
  }

  void _applyFilters() {
    setState(() {
      _ads.clear();
      _lastDocument = null;
      _hasMore = true;
      _activeFiltersList.clear();

      if (selectedType != null) {
        _activeFiltersList.add(ActiveFilter(
          type: 'type',
          value: selectedType!,
          displayText: selectedType!,
        ));
      }

      if (selectedCondition != null) {
        _activeFiltersList.add(ActiveFilter(
          type: 'condition',
          value: selectedCondition!,
          displayText: selectedCondition!,
        ));
      }

      if (selectedSubCategory != null) {
        _activeFiltersList.add(ActiveFilter(
          type: 'category',
          value: selectedSubCategory!,
          displayText: selectedSubCategory!,
        ));
      }

      if (priceRange.start > 0 || priceRange.end < 1000) {
        _activeFiltersList.add(ActiveFilter(
          type: 'price',
          value: '${priceRange.start}-${priceRange.end}',
          displayText:
              '${priceRange.start.round()}€ - ${priceRange.end.round()}€',
        ));
      }

      // Utiliser LocationProvider pour la localisation
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locationProvider.hasLocation) {
        _activeFiltersList.add(ActiveFilter(
          type: 'location',
          value: '${locationProvider.radius.round()}',
          displayText:
              '${locationProvider.address} (${locationProvider.radius.round()} km)',
        ));
      }

      _activeFilters = {
        if (selectedType != null) 'type': _convertExchangeType(selectedType!),
        if (selectedSubCategory != null) 'category': selectedSubCategory,
        if (priceRange.start > 0) 'minPrice': priceRange.start,
        if (priceRange.end < 1000) 'maxPrice': priceRange.end,
        if (selectedCondition != null) 'condition': selectedCondition,
        if (selectedBrand != null) 'brand': selectedBrand,
      };
    });
    _loadMoreAds();
  }

  void _loadMoreAds() async {
    if (_isLoading || !_hasMore || !mounted) return;
    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('ads')
          .where('adType', isEqualTo: 'exchange')
          .where('status', isNotEqualTo: 'sold')
          .orderBy('status')
          .orderBy('createdAt', descending: true);

      if (_activeFilters.isNotEmpty) {
        if (_activeFilters['type'] != null) {
          query =
              query.where('exchangeType', isEqualTo: _activeFilters['type']);
        }
        if (_activeFilters['category'] != null) {
          query = query.where('category', isEqualTo: selectedSubCategory);
        }
        if (_activeFilters['condition'] != null) {
          query = query.where('condition', isEqualTo: selectedCondition);
        }
        if (_activeFilters['brand'] != null) {
          query = query.where('brand', isEqualTo: selectedBrand);
        }
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot querySnapshot = await query.limit(20).get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = querySnapshot.docs.last;
      final List<Ad> newAds = [];

      // Utiliser LocationProvider pour le filtrage par localisation
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      
      if (locationProvider.hasLocation) {
        debugPrint('Filtrage par localisation: rayon ${locationProvider.radius} km');
        for (var doc in querySnapshot.docs) {
          final ad = await Ad.fromFirestore(doc);
          final adData = ad.additionalData;

          if (adData['coordinates'] != null) {
            final coordinates = adData['coordinates'] as List<dynamic>;
            // Conversion sécurisée des coordonnées
            double? adLat;
            double? adLng;
            
            if (coordinates[1] != null) {
              if (coordinates[1] is num) {
                adLat = (coordinates[1] as num).toDouble();
              } else if (coordinates[1] is String) {
                adLat = double.tryParse(coordinates[1]);
              }
            }
            
            if (coordinates[0] != null) {
              if (coordinates[0] is num) {
                adLng = (coordinates[0] as num).toDouble();
              } else if (coordinates[0] is String) {
                adLng = double.tryParse(coordinates[0]);
              }
            }
            
            if (adLat != null && adLng != null) {
              // Calculer la distance pour le débogage
              final distance = Geolocator.distanceBetween(
                locationProvider.latitude!,
                locationProvider.longitude!,
                adLat,
                adLng,
              ) / 1000; // Convertir en km
              
              final isWithinRadius = LocationUtils.isWithinRadius(
                locationProvider.latitude!,
                locationProvider.longitude!,
                adLat,
                adLng,
                locationProvider.radius,
              );
              
              debugPrint('Annonce ${ad.title}: distance ${distance.toStringAsFixed(1)} km, dans le rayon: $isWithinRadius');
              
              if (isWithinRadius) {
                newAds.add(ad);
                debugPrint('✓ Ajoutée: ${ad.title}');
              } else {
                debugPrint('✗ Rejetée: ${ad.title} (trop loin)');
              }
            } else {
              debugPrint('✗ Rejetée: ${ad.title} (coordonnées invalides)');
            }
          } else {
            debugPrint('✗ Rejetée: ${ad.title} (pas de coordonnées)');
          }
        }
      } else {
        for (var doc in querySnapshot.docs) {
          final ad = await Ad.fromFirestore(doc);
          newAds.add(ad);
        }
      }

      if (mounted) {
        setState(() {
          // Toujours vider la liste avant d'ajouter de nouvelles annonces
          // pour éviter d'avoir des annonces qui ne respectent plus les critères
          _ads.clear();
          _ads.addAll(newAds);
          _isLoading = false;
          _hasMore = querySnapshot.docs.length == 20 && newAds.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
      }
    }
  }

  Widget _buildFilterChipsRow({
    required List<String> items,
    required String? selectedValue,
    required Function(String?) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: items.map((item) {
          return FilterChip(
            selected: selectedValue == item,
            label: Text(item),
            onSelected: (bool selected) {
              onSelected(selected ? item : null);
            },
            selectedColor: Colors.blue[100],
            checkmarkColor: Colors.blue[700],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _toggleSaveAd(Ad ad) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Vous devez être connecté pour sauvegarder une annonce'),
        ),
      );
      return;
    }

    try {
      final savedAdsProvider =
          Provider.of<SavedAdsProvider>(context, listen: false);
      await savedAdsProvider.toggleSaveAd(user.uid, ad.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    }
  }

  void _navigateToAdDetail(Ad ad) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AdDetailPage(ad: ad)),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    // Supprimer le listener du LocationProvider
    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.removeListener(_onLocationChanged);
    } catch (e) {
      // Ignorer les erreurs si le provider n'est pas disponible
    }
    super.dispose();
  }
}
