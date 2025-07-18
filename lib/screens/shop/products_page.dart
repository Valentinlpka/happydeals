import 'dart:async';
import 'dart:math' show cos, sin, sqrt, atan2, pi;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/category_product.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/shop/category_products_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/screens/shop/products_list_page.dart';
import 'package:happy/services/algolia_service.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/location_filter.dart';
import 'package:provider/provider.dart';

String formatCategoryName(String categoryId) {
  if (categoryId.isEmpty) return '';

  // Remplacer les underscores par des espaces
  String name = categoryId.replaceAll('_', ' ');

  // Capitaliser chaque mot
  List<String> words = name.split(' ');
  words = words.map((word) {
    if (word.isEmpty) return '';
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).toList();

  return words.join(' ');
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Category> _mainCategories = [];
  bool _isLoading = true;
  Category? _selectedCategory;
  String _searchQuery = '';
  Timer? _debounce;

  // Ajoutez ces variables pour Algolia
  final AlgoliaService _algoliaService = AlgoliaService();
  List<Map<String, dynamic>> _algoliaResults = [];
  bool _isSearching = false;

  // Variables pour la localisation
  double? _selectedLat;
  double? _selectedLng;
  double _selectedRadius = 20.0;
  String _selectedAddress = '';

  @override
  void initState() {
    super.initState();
    _loadMainCategories();
    _initializeLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });

      // Effectuer la recherche Algolia si le terme a au moins 2 caractères
      if (_searchQuery.length >= 2) {
        _searchProductsWithAlgolia(_searchQuery);
      } else {
        setState(() {
          _algoliaResults = [];
          _isSearching = false;
        });
      }
    });
  }

  // Nouvelle méthode pour rechercher avec Algolia
  Future<void> _searchProductsWithAlgolia(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _algoliaService.search(
        query,
        indexName: 'products',
        hitsPerPage: 50,
      );

      setState(() {
        _algoliaResults = results;
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Erreur lors de la recherche Algolia: $e');
      setState(() {
        _algoliaResults = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _loadMainCategories() async {
    try {
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .where('level', isEqualTo: 1)
          .get();

      setState(() {
        _mainCategories = categoriesSnapshot.docs
            .map((doc) => Category.fromFirestore(doc))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors du chargement des catégories: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeLocation() async {
    final userProvider = Provider.of<UserModel>(context, listen: false);
    if (userProvider.latitude != 0.0 && userProvider.longitude != 0.0) {
      setState(() {
        _selectedLat = userProvider.latitude;
        _selectedLng = userProvider.longitude;
        _selectedAddress = userProvider.city;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(
        title: 'Produits',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: Icon(
              Icons.location_on,
              color: _selectedLat != null ? const Color(0xFF4B88DA) : null,
            ),
            onPressed: _showLocationFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4B88DA)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // Contenu principal
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults()
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        // Liste horizontale des catégories
                        if (!_isLoading && _mainCategories.isNotEmpty)
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _mainCategories.length,
                              itemBuilder: (context, index) {
                                final category = _mainCategories[index];
                                final isSelected =
                                    _selectedCategory?.id == category.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CategoryProductsPage(
                                            categoryName: category.name,
                                            categoryId: category.id,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF4B88DA)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF4B88DA)
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            category.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Sections de produits
                        if (_selectedLat != null && _selectedLng != null)
                          FutureBuilder<List<String>>(
                            future: _getNearbyCompanies(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              if (snapshot.hasError ||
                                  snapshot.data?.isEmpty == true) {
                                return const SizedBox();
                              }

                              return _buildProductSection(
                                title: 'Produits près de chez vous',
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .where('isActive', isEqualTo: true)
                                    .where('sellerId', whereIn: snapshot.data)
                                    .limit(10)
                                    .snapshots(),
                                onSeeMorePressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductsListPage(
                                        title: 'Produits près de chez vous',
                                        query: FirebaseFirestore.instance
                                            .collection('posts')
                                            .where('isActive', isEqualTo: true)
                                            .where('sellerId',
                                                whereIn: snapshot.data),
                                        showDistance: true,
                                        userLat: _selectedLat,
                                        userLng: _selectedLng,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        const SizedBox(height: 32),

                        // Autres sections existantes...
                        _buildProductSection(
                          title: 'Nouveautés',
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('type', isEqualTo: 'product')
                              .where('isActive', isEqualTo: true)
                              .orderBy('timestamp', descending: true)
                              .limit(10)
                              .snapshots(),
                          onSeeMorePressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductsListPage(
                                  title: 'Nouveautés',
                                  query: FirebaseFirestore.instance
                                      .collection('posts')
                                      .where('type', isEqualTo: 'product')
                                      .where('isActive', isEqualTo: true)
                                      .orderBy('timestamp', descending: true),
                                  showDistance: true,
                                  userLat: _selectedLat,
                                  userLng: _selectedLng,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Section Produits les plus vendus
                        _buildProductSection(
                          title: 'Les plus populaires',
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('type', isEqualTo: 'product')
                              .where('isActive', isEqualTo: true)
                              .orderBy('views', descending: true)
                              .limit(10)
                              .snapshots(),
                              
                              
                          onSeeMorePressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductsListPage(
                                  title: 'Les plus populaires',
                                  query: FirebaseFirestore.instance
                                      .collection('posts')
                                      .where('type', isEqualTo: 'product')
                                      .where('isActive', isEqualTo: true)
                                      .orderBy('views', descending: true),
                                  showDistance: true,
                                  userLat: _selectedLat,
                                  userLng: _selectedLng,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

                        // Sections par catégorie
                        ..._mainCategories.map(
                          (category) => StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('posts')
                                .where('type', isEqualTo: 'product')
                                .where('isActive', isEqualTo: true)
                                .where('categoryPath',
                                    arrayContains: category.id)
                                .limit(10)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox();
                              }

                              if (snapshot.hasError || !snapshot.hasData) {
                                return const SizedBox();
                              }

                              final posts = snapshot.data!.docs;

                              if (posts.isEmpty) {
                                return const SizedBox();
                              }

                              return _buildProductSection(
                                title: category.name,
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .where('type', isEqualTo: 'product')
                                    .where('isActive', isEqualTo: true)
                                    .where('categoryPath',
                                        arrayContains: category.id)
                                    .limit(10)
                                    .snapshots(),
                                onSeeMorePressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CategoryProductsPage(
                                        categoryName: category.name,
                                        categoryId: category.id,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
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
      },
      currentLat: _selectedLat,
      currentLng: _selectedLng,
      currentRadius: _selectedRadius,
      currentAddress: _selectedAddress,
    );
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()}m';
    }
    return '${distance.toStringAsFixed(1)}km';
  }

  // Modifiez la méthode _buildProductSection pour utiliser la collection 'posts'
  Widget _buildProductSection({
    required String title,
    required Stream<QuerySnapshot> stream,
    required VoidCallback onSeeMorePressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onSeeMorePressed,
                child: const Text(
                  'Voir plus',
                  style: TextStyle(
                    color: Color(0xFF4B88DA),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320,
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint('❌ Erreur dans StreamBuilder: ${snapshot.error}');
                debugPrint('❌ Stack trace: ${snapshot.stackTrace}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Une erreur est survenue',
                        style: TextStyle(color: Colors.grey[800], fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data?.docs.isEmpty == true) {
                debugPrint('ℹ️ Pas de données pour la section "$title"');
                return const Center(
                  child: Text('Aucun produit disponible'),
                );
              }

              final products = snapshot.data?.docs
                      .map((doc) {
                        try {
                          return Product.fromFirestore(doc);
                        } catch (e, stackTrace) {
                          debugPrint('❌ Erreur lors de la conversion du produit ${doc.id}: $e');
                          debugPrint('❌ Stack trace: $stackTrace');
                          return null;
                        }
                      })
                      .whereType<Product>() // Filtre les null et cast en Product
                      .where((product) =>
                          _searchQuery.isEmpty ||
                          product.name.toLowerCase().contains(_searchQuery) ||
                          product.description.toLowerCase().contains(_searchQuery))
                      .toList() ??
                  [];

              if (products.isEmpty) {
                debugPrint('ℹ️ Aucun produit trouvé pour la section "$title"');
                return const Center(
                  child: Text('Aucun produit disponible'),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 16),
                    child: Card(
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
                              builder: (context) => ModernProductDetailPage(
                                product: product,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12),
                                      ),
                                      child: product.images.isNotEmpty
                                          ? Image.network(
                                              product.images[0],
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorBuilder: (context, error,
                                                  stackTrace) {
                                                return Container(
                                                  color: Colors.grey[100],
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .image_not_supported_outlined,
                                                          size: 32,
                                                          color:
                                                              Colors.grey[400],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          'Image non disponible',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey[600],
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                  color: Colors.grey[100],
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                          : null,
                                                      color: const Color(
                                                          0xFF4B88DA),
                                                    ),
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              color: Colors.grey[100],
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .image_not_supported_outlined,
                                                      size: 32,
                                                      color: Colors.grey[400],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Pas d\'image',
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  if (product.discount?.isValid() ?? false)
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
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '-${product.discount!.value}${product.discount!.type == 'percentage' ? '%' : '€'}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    if (product.discount?.isValid() ?? false) ...[
                                      Row(
                                        children: [
                                          Text(
                                            '${product.finalPrice.toStringAsFixed(2)}€',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${product.basePrice.toStringAsFixed(2)}€',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else
                                      Text(
                                        '${product.basePrice.toStringAsFixed(2)}€',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        if (product.companyLogo.isNotEmpty)
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundImage:
                                                NetworkImage(product.companyLogo),
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.companyName,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                              if (_selectedLat != null &&
                                                  _selectedLng != null)
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      _formatDistance(
                                                          calculateDistance(
                                                        _selectedLat!,
                                                        _selectedLng!,
                                                        product.pickupLatitude,
                                                        product.pickupLongitude,
                                                      )),
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
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<String>> _getNearbyCompanies() async {
    try {
      final companysSnapshot =
          await FirebaseFirestore.instance.collection('companys').get();

      final nearbyCompanies = companysSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final address = data['adress'] as Map<String, dynamic>?;

            if (address == null ||
                !address.containsKey('latitude') ||
                !address.containsKey('longitude')) {
              return false;
            }

            final distance = calculateDistance(
              _selectedLat,
              _selectedLng,
              address['latitude'],
              address['longitude'],
            );

            return distance <= _selectedRadius;
          })
          .map((doc) => doc.id)
          .toList();

      return nearbyCompanies;
    } catch (e, stackTrace) {
      debugPrint(
          'Erreur lors de la récupération des entreprises à proximité: $e\n$stackTrace');
      return [];
    }
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  double calculateDistance(dynamic lat1, dynamic lon1, dynamic lat2, dynamic lon2) {
    // Fonction utilitaire pour convertir en double
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Conversion directe en utilisant parseDouble
    final latitude1 = parseDouble(lat1);
    final longitude1 = parseDouble(lon1);
    final latitude2 = parseDouble(lat2);
    final longitude2 = parseDouble(lon2);

    // Vérification des valeurs nulles ou invalides
    if (latitude1 == 0.0 || longitude1 == 0.0 || latitude2 == 0.0 || longitude2 == 0.0) {
      debugPrint('Coordonnées invalides : lat1=$lat1, lon1=$lon1, lat2=$lat2, lon2=$lon2');
      return 0.0;
    }

    const double earthRadius = 6371; // Rayon de la Terre en kilomètres
    final double dLat = _degreesToRadians(latitude2 - latitude1);
    final double dLon = _degreesToRadians(longitude2 - longitude1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(latitude1)) * cos(_degreesToRadians(latitude2)) *
        sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Modifiez la méthode _buildSearchResults pour utiliser les résultats d'Algolia
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_algoliaResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun produit trouvé pour "${_searchController.text}"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _algoliaResults.length,
      itemBuilder: (context, index) {
        final productData = _algoliaResults[index];

        // Récupérer les données du produit depuis Algolia
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('posts')
              .doc(productData['objectID'])
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Card(
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final product = Product.fromFirestore(snapshot.data!);

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ModernProductDetailPage(
                      product: product,
                    ),
                  ),
                );
              },
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: product.images.isNotEmpty
                                  ? Image.network(
                                      product.images.first,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[100],
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  size: 32,
                                                  color: Colors.grey[400],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Image non disponible',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: Colors.grey[100],
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                              color: const Color(0xFF4B88DA),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      color: Colors.grey[100],
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              size: 32,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Pas d\'image',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          if (product.discount?.isValid() ?? false)
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
                                  '-${product.discount?.value}${product.discount?.type == 'percentage' ? '%' : '€'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (product.discount?.isValid() ?? false) ...[
                              Row(
                                children: [
                                  Text(
                                    '${product.finalPrice.toStringAsFixed(2)}€',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${product.basePrice.toStringAsFixed(2)}€',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      decoration:
                                          TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                            ] else
                              Text(
                                '${product.basePrice.toStringAsFixed(2)}€',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            const Spacer(),
                           
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
